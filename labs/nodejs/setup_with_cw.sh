## Setup Variables
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REGION=us-central1


export DB_INSTANCE_NAME=mytest-instance
export DB_INSTANCE_PASSWORD=CHANGEME
export DB_NAME=item_db
export DB_USER=test-user
export DB_PASSWORD=CHANGEME

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

export IMAGE=gcr.io/$PROJECT_ID/codeoss-js:latest
export CONFIG=codeoss-js-config.json
export NAME=codeoss-js
export WS_CLUSTER=my-cluster


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
"https://workstations.googleapis.com/v1beta/projects/$PROJECT_ID/locations/$REGION/workstationClusters?workstation_cluster_id=${WS_CLUSTER}"

## Create GKE Cluster
#gcloud container clusters create mycluster --zone=us-central1-b
gcloud container --project "$PROJECT_ID" clusters create "mycluster" \
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
while [ $(gcloud sql instances list --filter="name=$DB_INSTANCE_NAME" --format="value(STATUS)") != "RUNNABLE" ]
do
  echo "Waiting for database to be ready"
  sleep 15s
done


gcloud sql databases create ${DB_NAME} --instance=${DB_INSTANCE_NAME}

gcloud sql users create ${DB_USER} \
    --password=${DB_PASSWORD} \
    --instance=${DB_INSTANCE_NAME}


export DB_INSTANCE_IP=$(gcloud sql instances describe $DB_INSTANCE_NAME \
    --format=json | jq \
    --raw-output ".ipAddresses[].ipAddress")



## Connect to Private VPC
gcloud iam service-accounts create gke-mytest-service-account \
  --display-name="GKE Mytest Service Account"


gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:gke-mytest-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

echo "Checking GKE clustering readiness"
while [ $(gcloud container clusters list --filter="name=mycluster" --format="value(status)") == "PROVISIONING" ]
do
  echo "Waiting for GKE cluster to be ready"
  sleep 15s
done

gcloud container clusters get-credentials mycluster --region=$REGION


kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ksa-cloud-sql
EOF

gcloud iam service-accounts add-iam-policy-binding \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/ksa-cloud-sql]" \
  gke-mytest-service-account@$PROJECT_ID.iam.gserviceaccount.com


kubectl annotate serviceaccount \
  ksa-cloud-sql  \
  iam.gke.io/gcp-service-account=gke-mytest-service-account@$PROJECT_ID.iam.gserviceaccount.com


kubectl create secret generic gke-cloud-sql-secrets \
  --from-literal=database=$DB_NAME \
  --from-literal=username=$DB_USER \
  --from-literal=password=$DB_PASSWORD

# check if workstation cluster has finished creating
export RECONCILING="true"
export RECONCILING=$(curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "Content-Type: application/json" \
        "https://workstations.googleapis.com/v1beta/projects/$PROJECT_ID/locations/$REGION/workstationClusters/${WS_CLUSTER}" | jq -r '.reconciling')
while [ $RECONCILING == "true" ]
    do
        sleep 1m
        export RECONCILING=$(curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "Content-Type: application/json" \
        "https://workstations.googleapis.com/v1beta/projects/$PROJECT_ID/locations/$REGION/workstationClusters/${WS_CLUSTER}" | jq -r '.reconciling')
    done

rm -rf cw
