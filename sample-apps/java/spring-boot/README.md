# Starter App for the Containerized Development with Spring Boot lab

## Create a Spring Boot Application

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

Your good to go for the lab !!!