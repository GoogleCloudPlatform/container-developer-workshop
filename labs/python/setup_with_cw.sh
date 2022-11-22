export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REGION=us-central1

export USE_GKE_GCLOUD_AUTH_PLUGIN=True

#export IMAGE=gcr.io/$PROJECT_ID/codeoss-java:latest
export IMAGE=us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest
export CONFIG=codeoss-config.json
export NAME=codeoss
export WS_CLUSTER=my-cluster

gcloud services enable \
    cloudresourcemanager.googleapis.com \
    container.googleapis.com \
    sourcerepo.googleapis.com \
    containerregistry.googleapis.com \
    spanner.googleapis.com \
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

## GKE CLUSTER

gcloud container clusters create python-cluster \
--zone us-central1-a \
--workload-pool ${PROJECT_ID}.svc.id.goog --async


## SPANNER
export SPANNER_INSTANCE=music-catalog 
export SPANNER_DB=musicians REGION=us-east1
gcloud spanner instances create $SPANNER_INSTANCE \
    --config=regional-${REGION} \
    --description="Music Catalog" \
    --nodes=1

gcloud alpha spanner instances update $SPANNER_INSTANCE --processing-units=100

export SPANNER_CONNECTION_STRING=projects/$PROJECT_ID/instances/$SPANNER_INSTANCE/databases/$SPANNER_DB

gcloud spanner databases create $SPANNER_DB --instance=$SPANNER_INSTANCE --ddl='CREATE TABLE Singers (
            SingerId     INT64 NOT NULL,
            FirstName    STRING(1024),
            LastName     STRING(1024),
            SingerInfo   BYTES(MAX)
        ) PRIMARY KEY (SingerId)'


echo "Checking GKE clustering readiness"
while [ $(gcloud container clusters list --filter="name=python-cluster" --format="value(status)") == "PROVISIONING" ]
do
  echo "Waiting for GKE cluster to be ready"
  sleep 15s
done
gcloud container clusters get-credentials python-cluster --zone us-central1-a 

export KSA_NAME=python-ksa
export NAMESPACE=default
kubectl create serviceaccount ${KSA_NAME} \
    --namespace ${NAMESPACE}


export GSA_NAME=python-gsa
gcloud iam service-accounts create ${GSA_NAME} \
    --project=${PROJECT_ID}

# set IAM Roles
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/spanner.databaseAdmin"    
gcloud iam service-accounts add-iam-policy-binding ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]"


kubectl annotate serviceaccount ${KSA_NAME} \
    --namespace ${NAMESPACE} \
    iam.gke.io/gcp-service-account=${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com


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
