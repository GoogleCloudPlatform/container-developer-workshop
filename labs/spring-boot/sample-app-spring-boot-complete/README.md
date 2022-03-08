# Complete App for the Containerized Development with Spring Boot lab

## Create a Spring Boot Application

```
# Note: subject to change!
git clone https://github.com/ddobrin/container-developer-workshop.git

# Note: subject to change!
cd labs/spring-boot/sample-app-spring-boot-complete
```

Validate that you have Java 17 and Maven installed
```shell
java -version

./mvnw --version
```

Validate that the starter app is good to go
```
./mvnw clean package spring-boot:run
```

From a terminal window, test the app
```
curl localhost:8080/hello

# Output
Hello from your local environment!
```

For GKE cluster deployment, please follow the [lab documentation](https://github.com/ddobrin/container-developer-workshop/blob/main/labs/spring-boot/README.md)and it's pre-requisites.

Please don't forget to update the `DB_HOST` in the `deployment.yaml` file.

