
## InnerLoop Development with NodeJS

## Overview

This lab demonstrates features and capabilities designed to streamline the development workflow for software engineers tasked with developing NodeJS applications in a containerized environment. Typical container development requires the user to understand details of containers and the container build process. Additionally, developers typically have to break their flow, moving out of their IDE to test and debug their applications in remote environments. With the tools and technologies mentioned in this tutorial, developers can work effectively with containerized applications without leaving their IDE. 


### What you will learn

In this lab you will learn methods for developing with containers in GCP including: 



*   Creating a starter Nodejs application
*   Configuring Nodejs application for container development
*   Coding a simple CRUD Rest Service
*   Deploying to GKE
*   Debugging an error state
*   Utilizing breakpoint / logs
*   Hot deploying changes back to GKE
*   Optional: Integrating CloudSQL for backend persistence


## Setup and Requirements

### Start Cloudshell Editor

This lab was designed and tested for use with Google Cloud Shell Editor. To access the editor, 



1. Access your google project at https://console.cloud.google.com. 
2. In the top right corner click on the cloud shell editor icon 
3. A new pane will open in the bottom of your window
4. Click on the Open Editor button
5. The editor will open with an explorer on the right and editor in the central area
6. A terminal pane should also be available in the bottom of the screen
7. If the terminal is NOT open use the key combination of `ctrl+`` to open a new terminal window


### Set up gcloud

In Cloud Shell, set your project ID and the region you want to deploy your application to. Save them as `PROJECT_ID` and `REGION` variables. 


```
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
```



### Get the source code

The source code for this lab is located in the container-developer-workshop in GoogleCloudPlatform on GitHub. Clone it with the command below then change into the directory. 



1. Download setup script and make it executable.

```
wget https://raw.githubusercontent.com/VeerMuchandi/InnerLoopDev/main/setup.sh
chmod +x setup.sh
```

### Provision the infrastructure used in this lab

In this lab you will deploy code to GKE and access data stored in a Spanner database. The setup script below prepares this infrastructure for you. 



1. Open `setup.sh` file and edit the values of passwords that are currently set to CHANGEME
2. Run the setup script to stand up a GKE cluster and a CloudSQL database that you will use in this lab

```
./setup.sh
```


3. In Cloud Shell, create a new directory with name `mynodejsapp`

```
mkdir mynodejsapp
```


4. Change to this directory and open it as a workspace. This will reload the editor by creating a workspace configuration in the newly created folder.

```
cd mynodejsapp && cloudshell workspace .
```


5. Install Node and NPM using NVM.

	


```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
	
	# This loads nvm bash_completion
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  

nvm install stable

nvm alias default stable


```



## Create a new starter application



1. Initialize the application by creating a `package.json` file

```
npm init
```

Choose the `entry point: (index.js) src/index.js` and default values for the rest of the parameters. This will create the file with following contents


```
{
  "name": "mynodejsapp",
  "version": "1.0.0",
  "description": "",
  "main": "src/index.js",,
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "author": "",
  "license": "ISC"
}
```




2. Edit this file to include the start command in the script `"start": "node src/index.js",`. After the change the scripts should look like the code snippet below:

```
"scripts": {
    "start": "node src/index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
```


3. The code that we are going to add also uses `express` so let us add that dependency to this `package.json` file. So after all the changes the `package.json` file should be as shown below.

```
​​{
  "name": "mynodejsapp",
  "version": "1.0.0",
  "description": "",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "author": "Your Name",
  "license": "ISC",
  "dependencies": {
    "express": "^4.16.4"
  }
}

```


4. Create` src/index.js` with the following code

```
const express = require('express');
const app = express();
const PORT = 8080;

app.get('/', (req, res) => {
    var message="Greetings from Node";
    res.send({ message: message });
  });

app.listen(PORT, () => {
  console.log(`Server running at: http://localhost:${PORT}/`);

});
	
```



Note the PORT is set to value` 8080`


### Generate Manifests

Skaffold provides integrated tools to simplify container development.  In this step you will initialize skaffold which will automatically create base kubernetes YAML files. Execute the command below to begin the process. 



1. Execute the following command in the terminal

```
skaffold init --generate-manifests
```

When prompted:
* Enter **8080** for the port
* Enter **y** to save the configuration

Two files are added to the workspace viz, `skaffold.yaml `and `deployment.yaml`


### Update app name

The default values included in the configuration don’t currently match the name of your application. Update the files to reference your application name rather than the default values.



1. Change entries in Skaffold config
    *   Open `skaffold.yaml`
    *   Select the image name currently set as` package-json-image`
    *   Right click and choose Change All Occurrences
    *   Type in the new name as `mynodejsapp`
2. Change entries in Kubernetes config
    *   Open `deployment.yaml` file 
    *   Select the image name currently set as` package-json-image`
    *   Right click and choose Change All Occurrences
    *   Type in the new name as `mynodejsapp`

Notice that in the `skaffold.yaml` file, the `build` section uses `buildpacks` to containerize the application. This code doesn't have Dockerfile and the developer doesn't need any knowledge of docker to containerize this application.

Also, hot sync is automatically enabled between the editor and the running container by this skaffold configuration. No additional configuration is required to enable hot sync.


## Walking through the development process

In this section you’ll walk through a few steps using the Cloud Code plugin to learn the basic processes and to validate the configuration and setup of your starter application. 

Cloud Code integrates with skaffold to streamline your development process. When you deploy to GKE in the following steps, Cloud Code and Skaffold will automatically build your container image, push it to a Container Registry, and then deploy your application to GKE. This happens behind the scenes abstracting the details away from the developer flow. Cloud Code also enhances your development process by providing traditional debug and hotsync capabilities to container based development. 


### Deploy to Kubernetes



1. In the pane at the bottom of Cloud Shell Editor, select Cloud Code  ￼   

2. In the panel that appears at the top, select **Run on Kubernetes**. If prompted, select Yes to use the current Kubernetes context.

3. The first time you run the command a  prompt will appear at the top of the screen asking if you want the current kubernetes context, select “Yes” to accept and use the current context. 


4. Next a prompt will be displayed asking which container registry to use. Press enter to accept the default value provided


5. Select the Output tab in the lower pane  to view progress and notifications


6. Select "Kubernetes: Run/Debug - Detailed" in the channel drop down to the right to view additional details and logs streaming live from the containers

7. Return to the simplified view by selecting “Kubernetes: Run/Debug” from the dropdown
8. When the build and tests are done, the Output tab says: `Resource deployment/mynodejsapp status completed successfully`, and a url is listed: “Forwarded URL from service demo-app: http://localhost:8080”
9. In the Cloud Code terminal, hover over the URL in the output (http://localhost:8080), and then in the tool tip that appears select Open Web Preview. 

    The response will be:
```
{"message":"Greetings from Node"}
```

### Hot Reload

1. Navigate to `src/index.js`. Edit the code the greeting message to `'Hello from Node'`

    Notice immediately that in the `Output` window,` Kubernetes: Run/Debug` view, the watcher syncs the updated files with the container in Kubernetes


```
Update initiated
File sync started for 1 files for gcr.io/myproject/mynodejsapp:latest@sha256:f554756b3b4d6c301c4b26ef96102227cfa2833270db56241248ae42baa1971a
File sync succeeded for 1 files for gcr.io/myproject/mynodejsapp:latest@sha256:f554756b3b4d6c301c4b26ef96102227cfa2833270db56241248ae42baa1971a
Update succeeded

```


2. If you switch to `Kubernetes: Run/Debug - Detailed` view, you will notice it recognizes file changes and restarts node

```
files modified: [src/index.js]
Copying files:map[src/index.js:[/workspace/src/index.js]]togcr.io/myproject/mynodejsapp:latest@sha256:f554756b3b4d6c301c4b26ef96102227cfa2833270db56241248ae42baa1971a
Syncing 1 files for gcr.io/myproject/mynodejsapp:latest@sha256:f554756b3b4d6c301c4b26ef96102227cfa2833270db56241248ae42baa1971a
Watching for changes...
[mynodejsapp]
[mynodejsapp]> mynodejsapp@1.0.0 start /workspace
[mynodejsapp]> node src/index.js
[mynodejsapp]
[mynodejsapp]Server running at: http://localhost:8080/
```

3. Refresh your browser to see the updated results. 


### Debugging



1. Go to the Debug view and stop the current thread.
2. Click on `Cloud Code` in the bottom menu and select `Debug on Kubernetes` to run the application in `debug` mode.
*   In the` Kubernetes Run/Debug - Detailed` view of `Output` window, notice that skaffold will deploy this application in debug mode.
*   It will take a couple of mins for the application to build and deploy. You'll notice a debugger attached this time.

```
Port forwarding pod/mynodejsapp-6bbcf847cd-vqr6v in namespace default, remote port 9229 -> http://127.0.0.1:9229
[mynodejsapp]Debugger attached.
```


3. The bottom status bar changes its color from blue to orange indicating that it is in Debug mode.
4. In the` Kubernetes Run/Debug` view, notice that a Debuggable container is started
```
**************URLs*****************
Forwarded URL from service mynodejsapp-service: http://localhost:8080
Debuggable container started pod/mynodejsapp-deployment-6bc7598798-xl9kj:mynodejsapp (default)
Update succeeded
***********************************
```

### Utilize Breakpoints

1. Open the `src/index.js` 
2. Locate the statement which reads `var message="Greetings from Node";`
3. Add a breakpoint to that line by clicking the blank space to the left of the line number. A red indicator will show to note the breakpoint is set
4. Reload your browser and note the debugger stops the process at the breakpoint and allows you to investigate the variables and state of the application which is running remotely in GKE
5. Click down into the variables section until you find the` "message"` variable. 
6. Execute the line by pressing on Step over 
7. Observe the current value of `"message"` variable change to` "Greetings from Node"`
8. Double click on the variable name “target” and in the popup, change the value to something different like` "Hello from Node"`
9. Click the Continue button in the debug control panel
10. Review the response in your browser which now shows the updated value you just entered.
11. Stop the “Debug” mode by pressing the stop button and remove the breakpoint by clicking on the breakpoint again.


## Developing a simple CRUD Rest Service

At this point your application is fully configured for containerized development and you’ve walked through the basic development workflow with Cloud Code. In the following sections you practice what you’ve learned by adding rest service endpoints connecting to a managed database in Google Cloud.


### Configure Dependencies

The application code uses a database to persist the rest service data. Ensure the dependencies are available by adding the following in the `package.json` file



1. Add two more dependencies `pg` and `sequelize` to `package.json` file to build a CRUD application Postgres. Post changes the dependencies section would look like this.

```
    "dependencies": {
    "express": "^4.16.4",
    "pg": "^8.7.3",
    "sequelize": "^6.17.0"
  }

```

### Code the REST service



1. Add the CRUD application code to this application

```
wget -O app.zip https://github.com/VeerMuchandi/InnerLoopDev/blob/main/nodejs-crudcode/app/app.zip?raw=true

unzip app.zip
```

This code has

*   [models](https://github.com/VeerMuchandi/InnerLoopDev/blob/main/nodejs-crudcode/app/models) folder with the entity model for `item`
*   [controllers](https://github.com/VeerMuchandi/InnerLoopDev/blob/main/nodejs-crudcode/app/controllers) folder with the code that does CRUD operations
*   [routes](https://github.com/VeerMuchandi/InnerLoopDev/blob/main/nodejs-crudcode/app/routes) folder that routes specific URL patterns to different calls
*   [config](https://github.com/VeerMuchandi/InnerLoopDev/blob/main/nodejs-crudcode/app/config) folder with database connectivity details
2. Note the database configuration in `db.config.js` file refers to the environment variables that need to be supplied to connect to the database. Also you need to parse the incoming request for url encoding. Add the following code snippet in `src/index.js` to be able to connect to the CRUD code from your main javascript file right before the last section that starts with  `app.listen(PORT, () => {`


```
const bodyParser = require('body-parser')
app.use(bodyParser.json())
app.use(
 bodyParser.urlencoded({
   extended: true,
 })
)
const db = require("../app/models");
db.sequelize.sync();
require("../app/routes/item.routes")(app);

```


3. Edit the deployment in the `deployment.yaml` file to add the environment variables to supply the Database connectivity information.

```
    spec:
      containers:
      - name: mynodejsapp
        image: mynodejsapp
        env:
        - name: DB_HOST
          value: ${DB_INSTANCE_IP}        
        - name: DB_PORT
          value: "5432"  
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: gke-cloud-sql-secrets
              key: username
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: gke-cloud-sql-secrets
              key: password
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: gke-cloud-sql-secrets
              key: database

```
Replace the DB\_HOST value with the address of your Database

```
export DB_INSTANCE_IP=$(gcloud sql instances describe mytest-instance \
    --format=json | jq \
    --raw-output ".ipAddresses[].ipAddress")

envsubst < deployment.yaml > deployment.new && mv deployment.new deployment.yaml

```

### Deploy and Validate Application

1. In the pane at the bottom of Cloud Shell Editor, select `Cloud Code`  then select` Debug on Kubernetes` at the top of the screen. 
2. When the build and tests are done, the Output tab says: `Resource deployment/mynodejsapp status completed successfully`, and a url is listed: “Forwarded URL from service mynodejsapp: http://localhost:8080”
3. Add a couple of items.

    From cloudshell Terminal, run the commands below
```
URL=localhost:8080
curl -X POST $URL/items -d '{"itemName":"Body Spray", "itemPrice":3.2}' -H "Content-Type: application/json"
curl -X POST $URL/items -d '{"itemName":"Nail Cutter", "itemPrice":2.5}' -H "Content-Type: application/json"

```


4. Test the GET by running the $URL/items in the browser. You can also run the curl from the command line
```
curl -X GET $URL/items
```


5. Test Delete: Now try to delete an item by running. Change the value of item-id if required.
```
curl -X DELETE $URL/items/1
```

This throws an error message


```
{"message":"Could not delete Item with id=[object Object]"}
```



### Identify and fix the issue



1. Restart the application in Debug mode and find the issue. Here are some tips:
*   We know something is wrong with the DELETE as it is not returning the desired result. So you would set the breakpoint in `itemcontroller.js`->`exports.delete` method.
*   Run step by step execution and watch the variables at each step to observe the values of local variables in the left window.
*   To observe specific values such as `request.params` add this variable to the Watch window.
2. Notice that the value assigned to `id` is `undefined`. Change the code to fix the issue.

The fixed code snippet would look like this.


```
// Delete a Item with the specified id in the request
exports.delete = (req, res) => {
    const id = req.params.id;
```


3. Once the application is restarted, test again by trying to delete.
4. Stop the debugging session by clicking on the red square in the debug toolbar

## Cleanup

Congratulations! In this lab you’ve created a new Nodejs application from scratch and configured it to work in hot deployment mode with containers. You then deployed and debugged your application to a remote GKE cluster following the same developer flow found in traditional application stacks. 

To clean up after completing the lab: 

1. Delete the files used in the lab

```
cd ~ && rm -rf mynodejsapp
```


2. Delete the project to remove all related infrastructure and resources