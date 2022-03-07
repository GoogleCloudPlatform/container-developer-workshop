# GKE Dev Cluster for lab

```shell
export PROJECT_ID="{PROJECT_ID}"
# ex.: export PROJECT_ID="dan-workshop-project-332213"

# Dev cluster
echo "creating devcluster..."
gcloud beta container --project "$PROJECT_ID" clusters create-auto "devcluster" \
--region "us-central1" --release-channel "regular" --network "projects/$PROJECT_ID/global/networks/default" \
--subnetwork "projects/$PROJECT_ID/regions/us-central1/subnetworks/default" \
--cluster-ipv4-cidr "/17" --services-ipv4-cidr "/22" --async\
```

## Connect to the cluster using the gcloud CLI
```shell
gcloud container clusters get-credentials devcluster --region us-central1 --project {PROJECT_ID}

# ex.:
# gcloud container clusters get-credentials devcluster --region us-central1 --project dan-workshop-project-332213

## Observe that you are connected to the cluster
```
kubectl config current-context
```

## Observe the configured clusters for your machine
```shell
gcloud container clusters list 
```