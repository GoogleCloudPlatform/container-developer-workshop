#!/bin/bash

mkdir cw

export REGION=us-central1
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export NAME=codeoss-js
export WS_CLUSTER=my-cluster
export CONFIG=codeoss-js-config.json
export IMAGE=gcr.io/$PROJECT_ID/codeoss-js:latest

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
          "image" : "$IMAGE"
  }
}
EOF

curl -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" \
     -d @cw/${CONFIG} \
https://workstations.googleapis.com/v1beta/projects/${PROJECT_ID}/locations/$REGION/workstationClusters/${WS_CLUSTER}/workstationConfigs?workstation_config_id=${NAME}

rm -rf cw
