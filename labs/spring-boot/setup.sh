

## Setup Variables
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export USE_GKE_GCLOUD_AUTH_PLUGIN=True


export DB_INSTANCE_NAME=quote-db-instance
export DB_INSTANCE_PASSWORD=CHANGEME
export DB_NAME=quote-db
export DB_USER=quote-user
export DB_PASSWORD=quotepwd321

export VPC_CONNECTOR=quoteconnector



gcloud services enable \
  cloudresourcemanager.googleapis.com \
  container.googleapis.com \
  sourcerepo.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com \
  servicenetworking.googleapis.com \
  sqladmin.googleapis.com

## Create GKE Cluster
#gcloud container clusters create mycluster --zone=us-central1-b
gcloud beta container --project "$PROJECT_ID" clusters create-auto "quote-cluster" \
--region "us-central1" --async


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

echo "Checking database readiness"
while [ $(gcloud sql instances list --filter="name=quote-db-instance" --format="value(STATUS)") != "RUNNABLE" ]
do
  echo "Waiting for database to be ready"
  sleep 15s
done

sleep 15s

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
