# Setup a CloudSQL for Postegres Instance

In this lab you will setup a database to use with the application code built in the inner loop application development lab. 

## Prerequisites

* A GKE cluster configured to use with Cloud Code

## The application code uses the following environment variables
```
DB_ROOT_PASSWORD=CHANGEME
DB_USER=CHANGEME
DB_PASS=CHANGEME
```

## Create a Cloud SQL instance

* Allocate an IP range for private services access connection

```
gcloud compute addresses create default-ip-range \
--global \
--purpose=VPC_PEERING \
--prefix-length=16 \
--description="peering range for Google" \
--network=default
```

* Create private services access connection

```
gcloud services vpc-peerings connect \
--service=servicenetworking.googleapis.com \
--ranges=default-ip-range \
--network=default
```

* Create a CloudSQL instance of type Postgres

```
DB_ROOT_PASSWORD=CHANGEME
DB_INSTANCE=mytest-instance
gcloud beta sql instances create $DB_INSTANCE \
--database-version=POSTGRES_13 \
 --cpu=1 \
 --memory=4GB \
 --region=us-central \
 --root-password=$DB_ROOT_PASSWORD \
 --no-assign-ip \
--network=default
```

This takes several minutes. 

* Patch the instance to require SSL

```
gcloud sql instances patch $DB_INSTANCE --require-ssl
```

## Create a database

* Create a new database in the above instance

```
DB_NAME=quote_db
gcloud sql databases create $DB_NAME --instance=$DB_INSTANCE
```

## Create a user

* Add a user to this instance

```
DB_USER=CHANGEME
DB_PASS=CHANGEME
gcloud sql users create $DB_USER \
--instance=$DB_INSTANCE \
--password=$DB_PASS
```

## Create a Google cloud service account with Cloud SQL Client role

* Create Service Account

```
gcloud iam service-accounts create gke-mytest-service-account \
  --display-name="GKE Mytest Service Account"
```

Add `cloudsql.client` role to the service account

```
PROJECT_ID=CHANGEME

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:gke-mytest-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

Create a kubernetes service account

```
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ksa-cloud-sql
EOF
```

* Enable IAM binding of the Google Cloud Service Account and the Kubernetes Service Account using Workload Identity

```
gcloud iam service-accounts add-iam-policy-binding \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/ksa-cloud-sql]" \
  gke-mytest-service-account@$PROJECT_ID.iam.gserviceaccount.com
```

* Annotate the Kubernetes Service Account with IAM binding

```
kubectl annotate serviceaccount \
  ksa-cloud-sql  \
  iam.gke.io/gcp-service-account=gke-mytest-service-account@$PROJECT_ID.iam.gserviceaccount.com
```

## Configure Kubernetes Secret

Create a secret name `gke-cloud-sql-secrets` to configure database name, user name, and password

```
kubectl create secret generic gke-cloud-sql-secrets \
  --from-literal=database=$DB_NAME \
  --from-literal=username=$DB_USER \
  --from-literal=password=$DB_PASS
```


