# demo-app 

## Create a Spring Boot Application

Get the source code
```shell
git clone git@github.com:ddobrin/modern-java-google-cloud.git
```

Validate that the download is correct
```shell
cd demo-app

./mvnw clean spring-boot:run

# using cUrl
curl localhost:8080/hello

Output: 
Hello from your local environment!

#using HTTPie
http GET :8080/hello
HTTP/1.1 200
Cache-Control: no-cache, no-store, max-age=0, must-revalidate
Connection: keep-alive
Content-Length: 34
Content-Type: text/plain;charset=UTF-8
Date: Fri, 25 Feb 2022 18:43:37 GMT
Expires: 0
Keep-Alive: timeout=60
Pragma: no-cache
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block

Hello from your local environment!

#stop the app with CTRL-C
```

#### The app is ready to go!

## Create Artifact Registry repository
```shell 
# create the demo-app repository
gcloud artifacts repositories create demo-app \
    --repository-format=Docker \
    --location=us-central1 \
    --description="Demo Application Images"

# validate that the repo has been created
gcloud artifacts repositories list

REPOSITORY               FORMAT  DESCRIPTION                               LOCATION     LABELS  ENCRYPTION          CREATE_TIME          UPDATE_TIME
...
demo-app                 DOCKER  Demo Application Images                   us-central1          Google-managed key  
...
```

Before you can push or pull images, configure Docker to use the Google Cloud CLI to authenticate requests to Artifact Registry.

To set up authentication to Docker repositories in the region us-central1, run the following command:
```shell
gcloud auth configure-docker us-central1-docker.pkg.dev
```

## Enable the Google Cloud Project
In the `Cloud Code (Extension)` in the status bar, select the GCP project

## Configure the build mechanism with Skaffold and Jib

Edit the Maven `pom.xml` and add the following session under the `<build>` element.
```xml
    <plugins>
      <plugin>
        <groupId>com.google.cloud.tools</groupId>
        <artifactId>jib-maven-plugin</artifactId>
        <version>3.2.0</version>
      </plugin>
```

Generate the Skaffold manifest and the Kubernetes deployment artifacts in the `kubernetes` folder:
```shell
# to start, you can analyze the artifacts which Skaffold can use for generation
skaffold init --analyze=true

# generate the manifests 
skaffold init --generate-manifests -k k8s/*.yaml --timestamps --default-kustomization=k8s

# Note: select 
# - the `Jib Maven Plugin (com.example:demo-app, demo-app/pom.xml)` option
# - the `k8s` folder 
```

Move the `deployment.yaml` file from the `demo-app` folder to the `k8s` folder, to reflect our desired Skaffold configuration.

Open the `skaffold.yaml` file and update the <build> element as follows:
```yaml
# modified image to include the Artifact Registry repo
# added type, args, fromImage and sync option
build:
  artifacts:
  - image: demo-app
    context: demo-app
    jib:
      args: 
      - -Dmaven.test.skip=true
    sync:
      auto: true      
```

## LATER: Configure the build mechanism with Skaffold and Dockerfiles

```yaml
# modified image to include the Artifact Registry repo
# added type, args, fromImage and sync option
build:
  artifacts:
#   - image: us-central1-docker.pkg.dev/dan-workshop-project-332213/demo-app/demo-app
  - image: demo-app
    context: demo-app
    docker:
      dockerfile: Dockerfile
    sync:
      auto: true      
```

## Run and Debug in Kubernetes with Cloud Code

Cloud Code --> Run On Kubernetes

Observe the corerct deployment and test from the command line:
```shell
curl localhost:8080/hello
# note that localhost:8080 is where we have forwarded the request

or 

http :8080/hello
# note that localhost, where we have forwarded the request at port 8080, is implied in HTTPie
```

Open the HellOController file and add more `!` marks, the save the file. Observe the hot redeploy
```java
    public String hello()
    {
        return String.format("Hello from your %s environment!!!", target);
    }
```    

Cloud Code --> Debug On Kubernetes

Open the HellOController file and add more `!` marks, the save the file. Observe the hot redeploy
```java
    public String hello()
    {
        return String.format("Hello from your %s environment!!!", target);
    }
```  

Set a breakpoint on the line `return ...`
Invoke the /hello endpoint with
```
curl localhost:8080/hello

Hello from your local environment!!!
```

## Deploy to Cloud Run (managed service)
```shell
#$ check that the service has been deployed
gcloud run services list | grep demo-app

curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" https://demo-app-ieuwkt6jkq-uc.a.run.app/random-quote

gcloud alpha run services proxy demo-app --region=us-central1
curl  http://127.0.0.1:8080/hello
```

## Run using Cloud Run emulator


## Debug using Cloud Run emulator


## Externalize Configuration


## Set up Skaffold Profiles and customization with Kustomize

```yaml
deploy:
  kustomize:
    paths:
      - k8s/overlays/dev
portForward:
- resourceType: service
  resourceName: demo-app
  port: 8080
  localPort: 8080
profiles:
  - name: staging
    deploy:
      kustomize:
        paths:
          - k8s/overlays/staging
```



[Optional: Describe your release in Cloud Deploy]
```shell
gcloud deploy releases describe rel-0e2754b --delivery-pipeline=demo-app-pipeline --region=us-central1
annotations:
  commitId: 0e2754b43916456452f5992112dba86288180519
buildArtifacts:
- image: demo-app
  tag: us-central1-docker.pkg.dev/dan-workshop-project-332213/demo-app/demo-app:0e2754b43916456452f5992112dba86288180519
createTime: '2022-03-01T16:08:54.302981887Z'
deliveryPipelineSnapshot:
  createTime: '2022-03-01T15:47:52.331299Z'
  description: HelloFunction application delivery pipeline
  etag: 828eb93d5ed8d4f7
  name: projects/161275344265/locations/us-central1/deliveryPipelines/demo-app-pipeline
  serialPipeline:
    stages:
    - profiles:
      - staging
      targetId: test
    - profiles:
      - staging
      targetId: staging
    - profiles:
      - prod
      targetId: prod
  uid: 65c6fa172c6c468aac54c86e408eaa4c
  updateTime: '2022-03-01T15:47:52.331299Z'
etag: fb73720334ac9c1c
name: projects/dan-workshop-project-332213/locations/us-central1/deliveryPipelines/demo-app-pipeline/releases/rel-0e2754b
renderEndTime: '2022-03-01T16:09:07.009050744Z'
renderStartTime: '2022-03-01T16:08:55.991256563Z'
renderState: FAILED
skaffoldConfigUri: gs://dan-workshop-project-332213_clouddeploy_us-central1/source/1646150933.154334-5269ddffaf20407a9b90fea4e5a355ea.tgz
skaffoldVersion: '1.35'
targetRenders:
  prod:
    failureCause: EXECUTION_FAILED
    renderingBuild: projects/161275344265/locations/us-central1/builds/5f02da28-288f-4d5c-8519-822dc6443996
    renderingState: FAILED
  staging:
    failureCause: EXECUTION_FAILED
    renderingBuild: projects/161275344265/locations/us-central1/builds/084b39c3-1ff8-4bbb-97a6-5505a52e0bc8
    renderingState: FAILED
  test:
    failureCause: EXECUTION_FAILED
    renderingBuild: projects/161275344265/locations/us-central1/builds/47a988ff-ee61-4929-b54f-156b0fdbf6b9
    renderingState: FAILED
targetSnapshots:
- createTime: '2022-01-31T17:03:11.424181Z'
  description: test cluster
  etag: fd71043eca8bfb94
  gke:
    cluster: projects/dan-workshop-project-332213/locations/us-central1/clusters/testcluster
  name: projects/161275344265/locations/us-central1/targets/test
  uid: af548c8bf326436b9dab53565fefa341
  updateTime: '2022-03-01T15:47:54.524513Z'
- createTime: '2022-01-31T17:03:11.775723Z'
  description: staging cluster
  etag: 794a5034042c5d14
  gke:
    cluster: projects/dan-workshop-project-332213/locations/us-central1/clusters/stagingcluster
  name: projects/161275344265/locations/us-central1/targets/staging
  uid: e8203a0241844e7c85fc3aab876dbcfc
  updateTime: '2022-03-01T15:47:55.014568Z'
- createTime: '2022-01-31T17:03:12.197484Z'
  description: prod cluster
  etag: 1e0003d070dc92cc
  gke:
    cluster: projects/dan-workshop-project-332213/locations/us-central1/clusters/prodcluster
  name: projects/161275344265/locations/us-central1/targets/prod
  requireApproval: true
  uid: 08f5df243fbb4767bae77071b24ae9a5
  updateTime: '2022-03-01T15:47:55.513731Z'
uid: 64e72358eec54293a5a5b1849574cda4
```