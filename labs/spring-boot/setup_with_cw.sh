

## Setup Variables
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REGION=us-central1
export USE_GKE_GCLOUD_AUTH_PLUGIN=True


export DB_INSTANCE_NAME=quote-db-instance
export DB_INSTANCE_PASSWORD=CHANGEME
export DB_NAME=quote-db
export DB_USER=quote-user
export DB_PASSWORD=quotepwd321

export VPC_CONNECTOR=quoteconnector


export IMAGE=gcr.io/$PROJECT_ID/codeoss-java:latest
export CONFIG=codeoss-java-config.json
export NAME=codeoss-java

gcloud services enable \
  cloudresourcemanager.googleapis.com \
  container.googleapis.com \
  sourcerepo.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com \
  servicenetworking.googleapis.com \
  sqladmin.googleapis.com \
  workstations.googleapis.com


# create cloud workstation cluster config file
mkdir cw
cat << EOF > cw/cluster.json
{
"network": "projects/$PROJECT_ID/global/networks/default",
"subnetwork": "projects/$PROJECT_ID/regions/$REGION/subnetworks/default",
}
EOF

# create cloud workstation cluster using config
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
 -H "Content-Type: application/json" \
 -d @cw/cluster.json \
"https://workstations.googleapis.com/v1beta/projects/$PROJECT_ID/locations/$REGION/workstationClusters?workstation_cluster_id=my-cluster"

## Create GKE Cluster
gcloud container --project "$PROJECT_ID" clusters create "quote-cluster" \
--region $REGION --num-nodes=1 --workload-pool=$PROJECT_ID.svc.id.goog --async

## Configure Private VPC
gcloud compute addresses create google-managed-services-default \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=20 \
    --network=projects/$PROJECT_ID/global/networks/default

gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=google-managed-services-default \
    --network=default \
    --project=$PROJECT_ID




## Create Private Postgres Cloud SQL Database
gcloud beta sql instances create $DB_INSTANCE_NAME \
    --project=$PROJECT_ID \
    --network=projects/$PROJECT_ID/global/networks/default \
    --no-assign-ip \
    --database-version=POSTGRES_12 \
    --cpu=2 \
    --memory=4GB \
    --region=$REGION \
    --root-password=${DB_INSTANCE_PASSWORD} \
    --async



#Dockerfile for custom cloud workstation image
cat <<EOF > cw/Dockerfile
FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest

RUN sudo apt update
RUN sudo apt install -y gettext-base jq httpie

#Install OpenJDK 17
RUN sudo apt install openjdk-17-jdk -y

#Java extension pack
RUN wget https://open-vsx.org/api/vscjava/vscode-java-pack/0.25.0/file/vscjava.vscode-java-pack-0.25.0.vsix && \
unzip vscjava.vscode-java-pack-0.25.0.vsix "extension/*" &&\
mv extension /opt/code-oss/extensions/java-extension-pack

#Java debug
RUN wget https://open-vsx.org/api/vscjava/vscode-java-debug/0.43.0/file/vscjava.vscode-java-debug-0.43.0.vsix && \
unzip vscjava.vscode-java-debug-0.43.0.vsix "extension/*" &&\
mv extension /opt/code-oss/extensions/java-debug

#Java language support
RUN wget https://open-vsx.org/api/redhat/java/1.9.0/file/redhat.java-1.9.0.vsix && \
unzip redhat.java-1.9.0.vsix "extension/*" &&\
mv extension /opt/code-oss/extensions/java-lsp

#Javascript Debugger extension
RUN wget https://open-vsx.org/api/ms-vscode/js-debug/1.70.0/file/ms-vscode.js-debug-1.70.0.vsix && \
unzip ms-vscode.js-debug-1.70.0.vsix "extension/*" &&\
mv extension /opt/code-oss/extensions/javascript-debugger
EOF

#build custom image
gcloud auth configure-docker
docker build cw -t $IMAGE 

#push image to gcr
docker push $IMAGE 


echo "Checking database readiness"
while [ $(gcloud sql instances list --filter="name=quote-db-instance" --format="value(STATUS)") != "RUNNABLE" ]
do
  echo "Waiting for database to be ready"
  sleep 15s
done

gcloud sql databases create ${DB_NAME} --instance=${DB_INSTANCE_NAME}

gcloud sql users create ${DB_USER} \
    --password=$DB_PASSWORD \
    --instance=${DB_INSTANCE_NAME}


export DB_INSTANCE_IP=$(gcloud sql instances describe $DB_INSTANCE_NAME \
    --format=json | jq \
    --raw-output ".ipAddresses[].ipAddress")



## Connect to Private VPC
gcloud iam service-accounts create gke-quotedb-service-account \
  --display-name="GKE QuoteDB Service Account"


gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:gke-quotedb-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

echo "Checking GKE clustering readiness"
while [ $(gcloud container clusters list --filter="name=quote-cluster" --format="value(status)") == "PROVISIONING" ]
do
  echo "Waiting for GKE cluster to be ready"
  sleep 15s
done
gcloud container clusters get-credentials quote-cluster --region="us-central1" 



kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ksa-cloud-sql
EOF

gcloud iam service-accounts add-iam-policy-binding \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/ksa-cloud-sql]" \
  gke-quotedb-service-account@$PROJECT_ID.iam.gserviceaccount.com


kubectl annotate serviceaccount \
  ksa-cloud-sql  \
  iam.gke.io/gcp-service-account=gke-quotedb-service-account@$PROJECT_ID.iam.gserviceaccount.com


kubectl create secret generic gke-cloud-sql-secrets \
  --from-literal=database=$DB_NAME \
  --from-literal=username=$DB_USER \
  --from-literal=password=$DB_PASSWORD


# check if workstation cluster has finished creating
export RECONCILING="true"
export RECONCILING=$(curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "Content-Type: application/json" \
        "https://workstations.googleapis.com/v1beta/projects/$PROJECT_ID/locations/$REGION/workstationClusters/my-cluster" | jq -r '.reconciling')
while [ $RECONCILING == "true" ]
    do
        sleep 1m
        export RECONCILING=$(curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "Content-Type: application/json" \
        "https://workstations.googleapis.com/v1beta/projects/$PROJECT_ID/locations/$REGION/workstationClusters/my-cluster" | jq -r '.reconciling')
    done

# create code-oss config file
cat <<EOF > cw/$CONFIG
{
  "idleTimeout": "7200s",
  "host": {
    "gce_instance": {
      "machine_type": "e2-standard-8",
      "pool_size": 1,
      "service_account": "$PROJECT_NUMBER-compute@developer.gserviceaccount.com",
    },
  },
  "persistentDirectories": {
    "mountPath": "/home",
    "gcePd": {
      "sizeGb": 200,
      "fsType": "ext4"
    }
  },
  "container": {
          "image" : "gcr.io/$PROJECT_ID/codeoss-java:latest"
  }
}
EOF

# add workstation configuration
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" \
     -d @cw/${CONFIG} \
https://workstations.googleapis.com/v1beta/projects/${PROJECT_ID}/locations/$REGION/workstationClusters/my-cluster/workstationConfigs?workstation_config_id=${NAME}

rm -rf cw
