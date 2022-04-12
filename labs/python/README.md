
# Overview

This lab demonstrates features and capabilities designed to streamline the development workflow for software engineers tasked with developing Python applications in a containerized environment. Typical container development requires the user to understand details of containers and the container build process. Additionally, developers typically have to break their flow, moving out of their IDE to test and debug their applications in remote environments. With the tools and technologies mentioned in this tutorial, developers can work effectively with containerized applications without leaving their IDE.


## What you will learn

In this lab you will learn methods for developing with containers in GCP including: 



* Creating a new Python starter application
* Walk through the development process
* Develop a simple CRUD rest service


# Setup and Requirements

Duration: 2:00


## Redeem Credits

Environment: none

[[**import** [credit redemption steps](https://docs.google.com/document/d/1s0nM4l38l1i2-pzugvVaCFj49B1EmLyCXGcONjW3pwo/edit#)]]


## Qwiklabs setup

Environment: Qwiklabs

[[**import** [startqwiklab](https://docs.google.com/document/d/1CjzSIBwME4CYthCtV_M1nYyZF06DMiGSVd1vypiW8Zo/edit)]]

[[**import** [gcpconsole](https://docs.google.com/document/d/1zlegdosIe7rcAboIjGH4GwaDtXxzdHy60DT3e1SR9U8/edit)]]

[[**import** [cloudshell](https://docs.google.com/a/google.com/document/d/1Wgu1CIsyMA6c_qIsYS7OYxjfhcq_fNtLMaSlu6NY2Qs/edit?usp=sharing)]]


## Self-paced environment setup

Environment: web

[[**import** [self-paced environment setup](https://docs.google.com/document/d/1SGrvGUCw8F_L8YDRhNUzV0pi11LbC4MZ5tIVB_USFu4/edit)]]


## Codelab-at-a-conference setup

Environment: none

[[**import** [codelab at conference setup](https://docs.google.com/document/d/1eMMdvvmexUfuuOfJvP5-AJK6pPusDFiPFTIDg-bzC1E/edit)]] 


## Start Cloudshell Editor

This lab was designed and tested for use with Google Cloud Shell Editor. To access the editor, 



1. access your google project at [https://console.cloud.google.com](https://console.cloud.google.com). 
2. In the top right corner click on the cloud shell editor icon 

    

<p id="gdcalert1" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image1.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert2">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image1.png "image_tooltip")


3. A new pane will open in the bottom of your window
4. Click on the Open Editor button

    

<p id="gdcalert2" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image2.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert3">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image2.png "image_tooltip")


5. The editor will open with an explorer on the right and editor in the central area
6. A terminal pane should also be available in the bottom of the screen
7. If the terminal is NOT open use the key combination of `ctrl+`` to open a new terminal window


## Set up gcloud

In Cloud Shell, set your project ID and the region you want to deploy your application to. Save them as `PROJECT_ID` and `REGION` variables. 


```
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID \
    --format='value(projectNumber)')


```



## Get the source code



1. The source code for this lab is located in the container-developer-workshop in GoogleCloudPlatform on GitHub. Clone it with the command below then change into the directory. 

    ```
git clone https://github.com/cgrant/container-developer-workshop.git -b innerloop-python &&
cd container-developer-workshop/labs/python
mkdir music-service && cd music-service && cloudshell workspace .

```



    If the terminal is NOT open use the key combination of `ctrl+`` to open a new terminal window



## Provision the infrastructure used in this lab

In this lab you will deploy code to GKE and access data stored in a Spanner database. The setup script below prepares this infrastructure for you. The provisioning process will take over 10 minutes. You can continue with the next few steps while the setup is processing. 


```
../setup.sh
```



# Create a new Python starter application



1. Create a file called `requirements.txt` and copy the following contents into it

    ```
echo "Flask
gunicorn
google-cloud-spanner
ptvsd==4.3.2" >> requirements.txt
```


2. Create a file named `app.py `and paste the following code into it

    ```
cat << EOF > app.py
import os
from flask import Flask, request, jsonify
from google.cloud import spanner

app = Flask(__name__)

@app.route("/")
def hello_world():
    message="Hello, World!"
    return message

if __name__ == '__main__':
    server_port = os.environ.get('PORT', '8080')
    app.run(debug=False, port=server_port, host='0.0.0.0')
EOF


```


3. Create a file named Dockerfile and paste the following into it

    ```
cat << EOF > Dockerfile
FROM python:3.8
WORKDIR /app
COPY requirements.txt .
RUN pip install --trusted-host pypi.python.org -r requirements.txt
COPY . .
ENTRYPOINT ["python", "app.py"]
EOF
```




## Generate Manifests

In your terminal execute the following command to generate a default skaffold.yaml and deployment.yaml



1. Initialize Skaffold with the following command

    ```
skaffold init --generate-manifests
```



    When prompted use the arrows to move your cursor and the spacebar to select the options. 


     \
Choose:

* `8080` for the port
* `y `to save the configuration


## Update Skaffold Configurations



1. Change default application name
* sed -i 's/dockerfile-image/python-app/' skaffold.yamlOpen `skaffold.yaml`
* Select the image name currently set as `dockerfile-image`
* Right click and choose Change All Occurrences
* Type in the new name as `python-app`


## Modify Kubernetes Configuration File



1. Change the default Name
* sed -i 's/dockerfile-image/python-app/' deployment.yamlOpen `deployment.yaml` file 
* Select the image name currently set as `dockerfile-image`
* Right click and choose Change All Occurrences
* Type in the new name as `python-app`


# Walking through the development process

With the business logic added you can now deploy and test your application. The following section will highlight the use of the Cloud Code plugin. Among other things, this plugin integrates with skaffold to streamline your development process. When you deploy to GKE in the following steps, Cloud Code and Skaffold will automatically build your container image, push it to a Container Registry, and then deploy your application to GKE. This happens behind the scenes abstracting the details away from the developer flow. 


## Deploy to Kubernetes



1. In the pane at the bottom of Cloud Shell Editor, select Cloud Code  ￼   

    

<p id="gdcalert3" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image3.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert4">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image3.png "image_tooltip")


2. In the panel that appears at the top, select **Run on Kubernetes**.. If prompted, select Yes to use the current Kubernetes context.

    

<p id="gdcalert4" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image4.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert5">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image4.png "image_tooltip")



    This command starts a build of the source code and then runs the tests. The build and tests will take a few minutes to run. These tests include unit tests and a validation step that checks the rules that are set for the deployment environment. This validation step is already configured, and it ensures that you get warning of deployment issues even while you're still working in your development environment.

3. The first time you run the command a  prompt will appear at the top of the screen asking if you want the current kubernetes context, select “Yes” to accept and use the current context. 
4. Next a prompt will be displayed asking which container registry to use. Press enter to accept the default value provided
5. Select the Output tab in the lower pane  to view progress and notifications

    

<p id="gdcalert5" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image5.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert6">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image5.png "image_tooltip")


6. Select "Kubernetes: Run/Debug - Detailed" in the channel drop down to the right to view additional details and logs streaming live from the containers

    

<p id="gdcalert6" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image6.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert7">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image6.png "image_tooltip")



    When the build and tests are done, the Output tab says: `Attached debugger to container "python-app-8476f4bbc-h6dsl" successfully.`, and the URL http://localhost:8080 is listed.

7. In the Cloud Code terminal, hover over the first URL in the output (http://localhost:8080), and then in the tool tip that appears select Open Web Preview. 


## Hot Reload



1. Open the `app.py` file 
2. Change the greeting message to `Hello from Python`

    Notice immediately that in the `Output` window,` Kubernetes: Run/Debug` view, the watcher syncs the updated files with the container in Kubernetes


    ```
Update initiated
Build started for artifact python-app
Build completed for artifact python-app

Deploy started
Deploy completed

Status check started
Resource pod/python-app-6f646ffcbb-tn7qd status updated to In Progress
Resource deployment/python-app status updated to In Progress
Resource deployment/python-app status completed successfully
Status check succeeded
…

```


3. If you switch to `Kubernetes: Run/Debug - Detailed` view, you will notice it recognizes file changes then builds and redeploys the app

    ```
files modified: [app.py]
Generating tags...
 - python-app -> gcr.io/crg-2022-04-11-python/python-app:a164811-dirty
Checking cache...
 - python-app: Not found. Building
Starting build…
```


4. Refresh your browser to see the updated results. 


## Debugging



1. Go to the Debug view and stop the current thread 

<p id="gdcalert7" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image7.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert8">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image7.png "image_tooltip")
.
2. Click on `Cloud Code` in the bottom menu and select `Debug on Kubernetes` to run the application in `debug` mode.
* In the` Kubernetes Run/Debug - Detailed` view of `Output` window, notice that skaffold will deploy this application in debug mode.
* It will take a couple of mins for the application to build and deploy. 
3. Near the end of the process a prompt will ask where the source is inside the container. This value is related to the directories in the Dockerfile.  \
 \
Press Enter to accept the default

    

<p id="gdcalert8" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image8.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert9">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image8.png "image_tooltip")


4. When the process completes. You'll notice a debugger attached.

    ```
Port forwarding pod/python-app-8bd64cf8b-cskfl in namespace default, remote port 5678 -> http://127.0.0.1:5678
```


5. The bottom status bar changes its color from blue to orange indicating that it is in Debug mode.
6. In the` Kubernetes Run/Debug` view, notice that a Debuggable container is started

    ```
**************URLs*****************
Forwarded URL from service python-app: http://localhost:8080
Debuggable container started pod/python-app-8bd64cf8b-cskfl:python-app (default)
Update succeeded
***********************************
```




## Utilize Breakpoints



1. Open the `app.py `file  
2. Locate the statement which reads `return message`
3. Add a breakpoint to that line by clicking the blank space to the left of the line number. A red indicator will show to note the breakpoint is set
4. Reload your browser and note the debugger stops the process at the breakpoint and allows you to investigate the variables and state of the application which is running remotely in GKE
5. Click down into the VARIABLES section
6. Click Locals there you’ll find the` "message"` variable. 
7. Double click on the variable name “message” and in the popup, change the value to something different like` "Greetings from Python"`
8. Click the Continue button in the debug control panel 

<p id="gdcalert9" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image9.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert10">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image9.png "image_tooltip")

9. Review the response in your browser which now shows the updated value you just entered.
10. Stop the “Debug” mode by pressing the stop button 

<p id="gdcalert10" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image10.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert11">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image10.png "image_tooltip")
 and remove the breakpoint by clicking on the breakpoint again.


# Developing a Simple CRUD Rest Service

At this point your application is fully configured for containerized development and you’ve walked through the basic development workflow with Cloud Code. In the following sections you practice what you’ve learned by adding rest service endpoints connecting to a managed database in Google Cloud.


## Code the rest service

The code below creates a simple rest service that uses Spanner as the database backing the application. Create the application by copying the following code into your application. 



1. Create the main application by replacing `app.py` with the following contents

    ```
import os
from flask import Flask, request, jsonify
from google.cloud import spanner


app = Flask(__name__)


instance_id = "music-catalog"

database_id = "musicians"

spanner_client = spanner.Client()
instance = spanner_client.instance(instance_id)
database = instance.database(database_id)


@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

@app.route('/singer', methods=['POST'])
def create():
    try:
        request_json = request.get_json()
        singer_id = request_json['singer_id']
        first_name = request_json['first_name']
        last_name = request_json['last_name']
        def insert_singers(transaction):
            row_ct = transaction.execute_update(
                f"INSERT Singers (SingerId, FirstName, LastName) VALUES" \
                f"({singer_id}, '{first_name}', '{last_name}')"
            )
            print("{} record(s) inserted.".format(row_ct))

        database.run_in_transaction(insert_singers)

        return {"Success": True}, 200
    except Exception as e:
        return e



@app.route('/singer', methods=['GET'])
def get_singer():

    try:
        singer_id = request.args.get('singer_id')
        def get_singer():
            first_name = ''
            last_name = ''
            with database.snapshot() as snapshot:
                results = snapshot.execute_sql(
                    f"SELECT SingerId, FirstName, LastName FROM Singers " \
                    f"where SingerId = {singer_id}",
                    )
                for row in results:
                    first_name = row[1]
                    last_name = row[2]
                return (first_name,last_name )
        first_name, last_name = get_singer()  
        return {"first_name": first_name, "last_name": last_name }, 200
    except Exception as e:
        return e


@app.route('/singer', methods=['PUT'])
def update_singer_first_name():
    try:
        singer_id = request.args.get('singer_id')
        request_json = request.get_json()
        first_name = request_json['first_name']
        
        def update_singer(transaction):
            row_ct = transaction.execute_update(
                f"UPDATE Singers SET FirstName = '{first_name}' WHERE SingerId = {singer_id}"
            )

            print("{} record(s) updated.".format(row_ct))

        database.run_in_transaction(update_singer)
        return {"Success": True}, 200
    except Exception as e:
        return e


@app.route('/singer', methods=['DELETE'])
def delete_singer():
    try:
        singer_id = request.args.get('singer')
    
        def delete_singer(transaction):
            row_ct = transaction.execute_update(
                f"DELETE FROM Singers WHERE SingerId = {singer_id}"
            )
            print("{} record(s) deleted.".format(row_ct))

        database.run_in_transaction(delete_singer)
        return {"Success": True}, 200
    except Exception as e:
        return e

port = int(os.environ.get('PORT', 8080))
if __name__ == '__main__':
    app.run(threaded=True, host='0.0.0.0', port=port)

```




## Add Database Configurations

To connect to Spanner securely, set the application up to use Workload Identities. This enables your application to act as its own service account and have individual permissions when accessing the database.  



1. Update `deployment.yaml`. Add the following code at the end of the file (ensure you keep the tab indents in the example below)

    ```
      serviceAccountName: python-ksa
      nodeSelector:
        iam.gke.io/gke-metadata-server-enabled: "true" 
```




## Deploy and Validate Application



1. In the pane at the bottom of Cloud Shell Editor, select `Cloud Code`  then select` Debug on Kubernetes` at the top of the screen. 
2. When the build and tests are done, the Output tab says: `Resource deployment/python-app status completed successfully`, and a url is listed: “Forwarded URL from service python-app: http://localhost:8080”
3. Add a couple of entries.

    From cloudshell Terminal, run the command below


    ```
curl -X POST http://localhost:8080/singer -H 'Content-Type: application/json' -d '{"first_name":"Cat","last_name":"Meow", "singer_id": 6}'
```


4. Test the GET by running the command below in the terminal

    ```
curl -X GET http://localhost:8080/singer?singer_id=6
```


5. Test Delete: Now try to delete an entry by running the following command. Change the value of item-id if required.

    ```
curl -X DELETE http://localhost:8080/singer?singer_id=6
```



	This throws an error message


```
500 Internal Server Error
```



## Identify and fix the issue



1. Debug mode and find the issue. Here are some tips:
* We know something is wrong with the DELETE as it is not returning the desired result. So you would set the breakpoint in `app.js` in the `delete_singer` method.
* Run step by step execution and watch the variables at each step to observe the values of local variables in the left window. 
* To observe specific values such as `singer_id` and `request.args` in the add these variables to the Watch window.
2. Notice that the value assigned to `singer_id` is `None`. Change the code to fix the issue.

    The fixed code snippet would look like this.


    ```
@app.route('/delete-singer', methods=['DELETE', 'GET'])
def delete_singer():
    try:
        singer_id = request.args.get('singer_id')

```


3. Once the application is restarted, test again by trying to delete.
4. Stop the debugging session by clicking on the red square in the debug toolbar 

<p id="gdcalert11" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image11.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert12">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image11.png "image_tooltip")



# Cleanup

Congratulations! In this lab you’ve created a new Java application from scratch and configured it to work effectively with containers. You then deployed and debugged your application to a remote GKE cluster following the same developer flow found in traditional application stacks. 

To clean up after completing the lab: 



1. Delete the files used in the lab

    ```
cd ~ && rm -rf container-developer-workshop
```


2. Delete the project to remove all related infrastructure and resources