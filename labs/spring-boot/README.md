# Containerized Java Development with Spring Boot & Jib on GKE

In previous labs you were introduced to different build types. Now, let's dive into the Inner Loop Application Development process of a Spring Boot application in Google Cloud.

## Key Points 
In this lab you will learn how to:
* Generate and configure build and deployment manifests for K8s using Skaffold and Jib 
* Build a simple CRUD REST service with a local Postgres backend
* Add unit tests for the app, leveraging Testcontaines
* Run/Debug the app in a GKE cluster
* Observe an error in the app, set breakpoints, debug and fix the app in a GKE cluster
* Observe the hot redeploy in action for the app fixes
* Check that unit tests didn't cover the problem in the app; add the missing unit test - lesson learned

Advanced Section - optional:
* Connect the app to a Google CloudSQL instance (CloudSQL for Postgres)
* Run and test the app 

## Prequisites
IDE
* A cloud editor with Cloud Code such as Cloud Shell Editor or 
* VS Code or IntelliJ with Cloud Code installed

Cluster
* GKE cluster configured to be used by Cloud Code - [setup instructions](./docs/GKEClusterSetup.md)
* Local K8s cluster such as minikube

Artifact Registry repo
* [Repository setup instructions](./ArtifactRegistrySetup.md)

## Start from a starter Spring Boot application

Clone the starter app code from Github
```
# Note: subject to change!
git clone https://github.com/ddobrin/container-developer-workshop.git

# Note: subject to change!
cd sample-apps/java/spring-boot
```

## Explore the starter app codebase

* On your local machine, open a `VS Cod`e workspace, for example, by executing `code .`
* In Cloudshell, open the Cloudshell Editor; then, in the `Explorer` view, navigate to the `sample-apps/java/spring-boot` folder, right-click and select `Open as Workspace`

Notes on the source code:
* Source code is provisioned in the `src` folder and the application starts in the DemoApplication Java class
* A starter Rest controller has been created for the `/` endpoint in the `src/main/java/com/example/HelloController` Java class. The controllwer displays a simple greeting, indicating the <environment> where it is running
* This start Spring Boot app has no container specific code 
* The code can be built using using `mvn` or `gradle`. In this specific example, Maven will be used. Locate `pom.xml` file in the project root and observe that it is configured to use Java 11, Boot 2.6.x and Spring Cloud 2021.x

## Generate and configure build and deployment manifests for K8s using Skaffold and Jib

Open the `pom.xml` and enable the Spring Boot DevTools, a development setting which supports the Hot Deploy in future stages. A `dev profile` is being used, as this setting will not be used in a Production environment.
```xml
  <!--  Spring profiles-->
  <profiles>
      <profile>
      <id>dev</id>
      <dependencies>
          <dependency>
          <groupId>org.springframework.boot</groupId>
          <artifactId>spring-boot-devtools</artifactId>
          </dependency>
      </dependencies>
      </profile>
  </profiles>
```

Add the Jib plugin in the `<build/plugins>` section, to enable building with Jib
```xml
  <build>
    <plugins>
      <plugin>
        <groupId>com.google.cloud.tools</groupId>
        <artifactId>jib-maven-plugin</artifactId>
        <version>3.2.0</version>
      </plugin>  
    </plugins>
  </build>
```

In your IDE of choice, open a Terminal window. The next steps involve:
* initializing Skafold
* generating K8s deployment manifests
* setting Jib up to build images when invoked from Skaffold

```shell
skaffold init --generate-manifests --XXenableJibInit
```
* using the arrow keys, select the `Jib Maven Plugin (com.example:demo-app, pom.xm*l)` option
* type in port 8080 to port-forward to
* type `y` when prompted `Do you want to write this configuration, along with the generated k8s manifests, to skaffold.yaml?`

Observe the output
```
Generated manifest deployment.yaml was written
Configuration skaffold.yaml was written
You can now run [skaffold build] to build the artifacts
or [skaffold run] to build and deploy
or [skaffold dev] to enter development mode, with auto-redeploy
```

Open the newly generated `skaffold.yaml` 
* Select the image name currently sent as `pom-xml-image`. 
* Right click and choose `Change All Occurences`  
* Type in the new name as `demo-app`

Open now the `deployment.yaml` file and change all occurences of `pom-xml-image` to `demo-app`. The file contains 2 manifests
* a K8s deployment that deploys a pod with the container image 
* a K8s service that exposes the deployment

To support the hot redeploy in Skaffold, when building with Jib, update the `skaffold.yaml` file in the `build` section, by adding configuration to skip unit tests when deploying to k8s, enabling sync and adding the `dev profile` to the build. The file should look as
```yaml
build:
  artifacts:
  - image: demo-app
    jib:
      project: com.example:demo-app
      args:
      - -Dmaven.test.skip=true
      - -Pdev
    sync:
      auto: true
```

## Validate the configuration by quickly running a build and deploy sequence against the GKE cluster
This will be the base of the app going forward.

In your IDE, click F1 and execute `Cloud Code: Run on Kubernetes` or click the Cloud Code extension link and select the same option
* Choose context - point to the GKE cluster called `lab-cluster`
* Choose Container Registry - select Brows Artifact Registry - select the `demo-app` folder
* Within the Artifact Registry demo-app folder, use the default `.` as the image location

Skafoold will start to build the app and deploy it to K8s. In the `Cloud Code - Kubernetes` view, observe the `Status`, Build Containers`, `Deploy to Cluster` and `Portforward URLs` steps.

Click on `Portforwarded URLS` as the deployment is successul and observe the output:
```
Port forwarding service/demo-app in namespace default, remote port 8080 -> http://127.0.0.1:8080
```

Click on the link and observe the output:
```
Hello from your local environment!
```

You can also send a cUrl or HTTPie request for testing:
```shell
curl 127.0.0.1:8080
   or 
http :8080
```

You have now a running web application deployed and running in your GKE cluster and are good to go for building out the CRUD application for the lab !!!

Stop the session using `SHIFT + F5` or select `Stop Debugging` from the menu or click the `Stop` button the Cloud Code - Kubernetes view.

## Build a simple CRUD REST service with a local Postgres backend

To build a CRUD service within the starter app, the following areas need to be addressed:
* develop the CRUD service code
* add configuration for the backend database accessed by the service
* update the dependencies in the Maven POM file
* add containerized unit and integration tests for the backend leveraging Testcontainers
#### Let's start writing some code ...

## Add the CRUD Service code 
We'll develop a `Quote` service, which would allow us to work with quotes collected from famous people throughout history.

The code for the Quote service will be developed in the `com.example` package.

Start by creating an Entity class:  Quote
```java
package com.example;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;
import java.util.Objects;

@Entity
@Table(name = "quotes")
public class Quote
{
    @Id
    @Column(name = "id")
    private Integer id;

    @Column(name="quote")
    private String quote;

    @Column(name="author")
    private String author;

    public Integer getId() {
        return id;
    }

    public void setId(Integer id) {
        this.id = id;
    }

    public String getQuote() {
        return quote;
    }

    public void setQuote(String quote) {
        this.quote = quote;
    }

    public String getAuthor() {
        return author;
    }

    public void setAuthor(String author) {
        this.author = author;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) {
        return true;
      }
      if (o == null || getClass() != o.getClass()) {
        return false;
      }
        Quote quote1 = (Quote) o;
        return Objects.equals(id, quote1.id) &&
                Objects.equals(quote, quote1.quote) &&
                Objects.equals(author, quote1.author);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id, quote, author);
    }
}
```

The intent is to use JPA for persisting the data, therefore the need to create a repository class `QUoteRepository`, which extends the Spring `JPARepository` interface and allows the creation of custom code. This class will create a `findRandomQuote` custom method.
```java
package com.example;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface QuoteRepository extends JpaRepository<Quote,Integer> {

    @Query( nativeQuery = true, value =
            "SELECT id,quote,author FROM quotes ORDER BY RANDOM() LIMIT 1")
    Quote findRandomQuote();
}
```

To expose the endpoint for the service, a `QuoteController` class will provide this functionality
```java
package com.example;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class QuoteController {

    private final QuoteRepository quoteRepository;

    public QuoteController(QuoteRepository quoteRepository) {
        this.quoteRepository = quoteRepository;
    }

    @GetMapping("/random-quote") 
    public Quote randomQuote()
    {
        return quoteRepository.findRandomQuote();  
    }

    @GetMapping("/quotes") 
    public ResponseEntity<List<Quote>> allQuotes()
    {
        try {
            List<Quote> quotes = new ArrayList<Quote>();
            
            quoteRepository.findAll().forEach(quotes::add);

            if (quotes.size()==0 || quotes.isEmpty()) 
                return new ResponseEntity<List<Quote>>(HttpStatus.NO_CONTENT);
                
            return new ResponseEntity<List<Quote>>(quotes, HttpStatus.OK);
        } catch (Exception e) {
            System.out.println(e.getMessage());
            return new ResponseEntity<List<Quote>>(HttpStatus.INTERNAL_SERVER_ERROR);
        }        
    }

    @PostMapping("/quotes")
    public ResponseEntity<Quote> createQuote(@RequestBody Quote quote) {
        try {
            Quote saved = quoteRepository.save(quote);
            return new ResponseEntity<Quote>(saved, HttpStatus.CREATED);
        } catch (Exception e) {
            System.out.println(e.getMessage());
            return new ResponseEntity<Quote>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }     

    @PutMapping("/quotes/{id}")
    public ResponseEntity<Quote> updateQuote(@PathVariable("id") Integer id, @RequestBody Quote quote) {
        try {
            Optional<Quote> existingQuote = quoteRepository.findById(id);
            
            if(existingQuote.isPresent()){
                Quote updatedQuote = existingQuote.get();
                updatedQuote.setAuthor(quote.getAuthor());
                updatedQuote.setQuote(quote.getQuote());

                return new ResponseEntity<Quote>(updatedQuote, HttpStatus.OK);
            } else {
                return new ResponseEntity<Quote>(HttpStatus.NOT_FOUND);
            }
        } catch (Exception e) {
            System.out.println(e.getMessage());
            return new ResponseEntity<Quote>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }     

    @DeleteMapping("/quotes/{id}")
    public ResponseEntity<HttpStatus> deleteQuote(@PathVariable("id") Integer id) {
        try {
            quoteRepository.deleteById(id);
            return new ResponseEntity<>(HttpStatus.NO_CONTENT);
        } catch (RuntimeException e) {
            System.out.println(e.getMessage());
            return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }    
}
```

It exposes the following endpoints:
```java
    // retrieve a random quote
    @GetMapping("/random-quote") 

    // retrieve all quotes from the backend
    @GetMapping("/quotes") 

    // create a new quote
    @PostMapping("/quotes")

    // update and existing quote
    @PutMapping("/quotes/{id}")

    // delete a quote
    @DeleteMapping("/quotes/{id}")
```

## Add configuration for the backend database accessed by the service

Open the `application.yaml file under `src/main/resources` and add a parameterized Spring configuration for the backend.
```yaml
spring:
  config:
    activate:
      on-profile: cloud-dev
  datasource:
    url: 'jdbc:postgresql://${DB_HOST:127.0.0.1}/${DB_DATABASE:quote_db}'
    username: '${DB_USER:user}'
    password: '${DB_PASS:password}'
  jpa:
    properties:
      hibernate:
        jdbc:
          lob:
            non_contextual_creation: true
        dialect: org.hibernate.dialect.PostgreSQLDialect
    hibernate:
      ddl-auto: update
```

The DB_HOST, DB_DATABASE, DB_USER and DB_PASS parameters will be set via externalized K8s configuration.

## Update the dependencies in the Maven POM file
Before the app can be compiled, the Maven POM file must be updated with the Spring JPA, Postgres, Flyway and H2 dependencies.

```xml
    <!--  Database sependencies-->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
      <groupId>com.h2database</groupId>
      <artifactId>h2</artifactId>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>org.postgresql</groupId>
      <artifactId>postgresql</artifactId>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>org.flywaydb</groupId>
      <artifactId>flyway-core</artifactId>
    </dependency>
```

## Add containerized unit tests leveraging Testcontainers


Let's start leveraging Testcontainers in order to test the Quote service in a containerized manner, similar to service execution in production.

To this end, we have to start by creating a good starting point for the test strategy, in two steps:
* set up data
* write up tests

Using the Java API, developers can easily provision databases at application start-up, portable across backends (local, cloud)m using Flyway.
Flyway is an open-source database migration tool, which strongly favors simplicity and convention over configuration.

Let's provision a simple set of 5 quotes in the database, executed at app start-up.

* create a folder `db/migration` under `src/main/resources`: `src/main/resources/db/migration/`. 
* create a SQL file: `V1__create_quotes_table.sql`
* paste the following SQL lines
```sql
CREATE TABLE quotes(
   id INTEGER PRIMARY KEY,
   quote VARCHAR(1024),
   author VARCHAR(256)
);

INSERT INTO quotes (id,quote,author) VALUES (1,'Never, never, never give up','Winston Churchill');
INSERT INTO quotes (id,quote,author) VALUES (2,'While there''s life, there''s hope','Marcus Tullius Cicero');
INSERT INTO quotes (id,quote,author) VALUES (3,'Failure is success in progress','Anonymous');
INSERT INTO quotes (id,quote,author) VALUES (4,'Success demands singleness of purpose','Vincent Lombardi');
INSERT INTO quotes (id,quote,author) VALUES (5,'The shortest answer is doing','Lord Herbert');
```

In the pom.xml, let's add the required dependencies.

Add the testcontainers version under the `<properties>` section:
```xml
<testcontainers.version>1.16.3</testcontainers.version>

# Section will look like
  <properties>
    <java.version>1</java.version>
	<spring-cloud.version>2021.0.1</spring-cloud.version>
    <testcontainers.version>1.16.3</testcontainers.version>
  </properties>
```

Add the Junit and Testcontainers dependencies in the `<dependencies>` section:
```xml
    <!-- Test dependencies -->
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-test</artifactId>
      <scope>test</scope>
      <exclusions>
        <exclusion>
          <groupId>org.junit.vintage</groupId>
          <artifactId>junit-vintage-engine</artifactId>
        </exclusion>
      </exclusions>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>junit-jupiter</artifactId>
      <scope>test</scope>
    </dependency>
    <dependency>
      <groupId>org.testcontainers</groupId>
      <artifactId>postgresql</artifactId>
      <scope>test</scope>
    </dependency>
```

Add the Testcontainers BOM in the `<dependencyManagement/dependencies>` section:
```xml
          <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>testcontainers-bom</artifactId>
            <version>${testcontainers.version}</version>
            <type>pom</type>
            <scope>import</scope>
          </dependency>
```

In the source code, there are two areas to be addressed: test code and test configuration.

Add the following configuration to the `application-test.yaml` file under `src/test/resources`:
```yaml
spring:
  datasource:
    url: "jdbc:tc:postgresql:13:///quotes?TC_TMPFS=/testtmpfs:rw"
```

Add the test code in the `src/test/com/example` folder as `QuotesRepositoryTest.java`:
```java
package com.example;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.testcontainers.DockerClientFactory.TESTCONTAINERS_LABEL;

import com.github.dockerjava.api.model.Container;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.DockerClientFactory;

@SpringBootTest
@ActiveProfiles("test")
class QuotesRepositoryTest {

  @BeforeEach
  void debug() {
    // print a list of all the containers test containers are currently running
    var client = DockerClientFactory.instance().client();
    var containers = client.listContainersCmd()
        .withLabelFilter(Map.of(TESTCONTAINERS_LABEL, "true")).exec();
    for (Container container : containers) {
      System.out.println(container.getImage());
    }
  }

  @Test
  @DisplayName("A random quote is returned")
  void testRandomQuotes(@Autowired QuoteRepository quoteRepository) {
    var quote = quoteRepository.findRandomQuote();
    assertThat(quote).isNotNull();
  }

  @Test
  @DisplayName("All quotes are returned")
  void testAllQuotes(@Autowired QuoteRepository quoteRepository) {
    var quotes = quoteRepository.findAll();
    assertThat(quotes).isNotNull();
  }

  @Test
  @DisplayName("Create a quote")
  void testCreateQuote(@Autowired QuoteRepository quoteRepository){
    var quote = new Quote();
    quote.setId(6);
    quote.setAuthor("Confucius");
    quote.setQuote("Our greatest glory is not in never falling, but in rising every time we fall");

    var result = quoteRepository.save(quote);
    assertThat(result.getAuthor()).isEqualTo("Confucius");
  }

  @Test
  @DisplayName("Delete a quote - good")
  void testDeleteQuoteGood(@Autowired QuoteRepository quoteRepository){
    var quote = new Quote();
    quote.setId(6);
    quote.setAuthor("Confucius");
    quote.setQuote("Our greatest glory is not in never falling, but in rising every time we fall");

    var result = quoteRepository.save(quote);
    assertThat(result.getAuthor()).isEqualTo("Confucius");

    assertDoesNotThrow(() -> {
      quoteRepository.deleteById(6);
    });
  }

}
```

In order to validate a correct build of the application, let's proceed to deploy the app to the GKE cluster.
As part of the build process, the app will be built, unit tests executed and any failure will be reported.

Repeat the process to deploy to GKE using Cloud Code, for example F1 + select `Cloud Code: Run on Kubernetes` !

## Test the CRUD service in GKE

Let's use either cURL or HTTPie for testing the app, from a Terminal window:
```shell
# run repeatedly a GET against the random-quote endpoint
# observe repeated call returning different quotes
curl -v 127.0.0.1:8080/random-quote
  or
http :8080/random-quote

# create a new quote, with id=6
# observe the request being echo'ed back
curl -v -H 'Content-Type: application/json' -d '{"id":"6","author":"Henry David Thoreau","quote":"Go confidently in the direction of your dreams! Live the life you’ve imagined"}' -X POST 127.0.0.1:8080/quotes
  or 
http PUT :8080/quotes/6 author="Henry David Thoreau" quote="Go confidently in the direction of your dreams! Live the life you’ve imagined" id="6"

# delete a quote
curl -v -X DELETE 127.0.0.1:8080/quotes/6
  or 
http DELETE :8080/quotes/6
```

Run the last request again, after the quote has previously been deleted and observe an `HTTP:500 Internal Server Error`. Let's find out why this is happening !!!

1. Stop the Cloud Code session and restart as a Debug session:
* F1 + Cloud Code: Debug on Kubernetes
* Click Cloud Code link in the IDE and select the Cloud Code: Debug on Kubernetes option

2. The error occurred in the DELETE operation, therefore let's open the `QuoteController` class, go to the `deleteQuote()` method and set a breakpoint on the line where er delete an item from the database: `quoteRepository.deleteById(id);`

3. Run the `delete` command again and observe the debug line stopped in the QuoteController class.
In the debugger, `step over` the `deleteById()` invocation and observe that an exception is thrown, due to the fact that the `quote` with `id=6` does not exist in the database.

4. Note that in the code we caught a very generic `RuntimException`, which sends back an Internal Server Error HTTP 500.

5. The code is incorrect and the exception block should be refactored to catch the `EmptyResultDataAccessException` exception and send back an HTTP 404 not found status code.

Let's correct the error. With the Debug session still running `!!!`, add the following block to the code:
```java 
        } catch(EmptyResultDataAccessException e){
            return new ResponseEntity<HttpStatus>(HttpStatus.NOT_FOUND);
        }

// method should look like
    public ResponseEntity<HttpStatus> deleteQuote(@PathVariable("id") Integer id) {
        try {
            quoteRepository.deleteById(id);
            return new ResponseEntity<>(HttpStatus.NO_CONTENT);
        } catch(EmptyResultDataAccessException e){
            return new ResponseEntity<HttpStatus>(HttpStatus.NOT_FOUND);
        } catch (RuntimeException e) {
            System.out.println(e.getMessage());
            return new ResponseEntity<>(HttpStatus.INTERNAL_SERVER_ERROR);
        }
    } 
```
 
Step through the debugger and observe the `EmptyResultDataAccessException` being caught and an HTTP 404 Not Found returned to the caller.
The `Local Variables` can be observed in the `Cloud Code - Kubernetes` view!

Stop the debugging session.

In this section you have learned how to debug directly in a Kubernetes cluster in GKE, set breakpoints, fuind and fix errors.

## Last step - add the missing unit test
A lesson was to be learned that we should pay attention to write good tests before deploying.

Let's correct this by adding a test method to the `QuotesRepositoryTest` test class:
```java
  @Test
  @DisplayName("Delete a quote - failed")
  void testDeleteQuote(@Autowired QuoteRepository quoteRepository){
    assertThatThrownBy(() -> {
      quoteRepository.deleteById(100);
    }).isInstanceOf(org.springframework.dao.EmptyResultDataAccessException.class);
  }
  ```

To validate that the test method is correct, we can simply run a `mvn verify` command from a terminal window and observe all our tests passing.

Alternatively, you can open `Test` view (test glass icon), right click on QuotesRepositoryTest and `Run Tests`. You should observe 5 tests executing correctly.

### This concludes the mandatory part of the lab - please run the Optional part of the lab, where the app will be connected to a CloudSQL for Postgres managed instance

------

## [Optional] Connect the app to a Google CloudSQL instance (CloudSQL for Postgres)

The starter app has evolved throughout the course of the lab, with the addition of a the `Quote` CRUD service, connected to a Postgres backend.

`Quick reminders` 
* up to this point, the backend has been implemented by the H2 Java Database, running in-memory. Testing has been performed using a containerized Postgres database, abstracted through the usagge of Testcontainers.
* at application start, you could observe, when selecting the `Kubernetes: Run/Debug Detailed` option in the dropdown located in the `Output` tab of the `Cloud Code - Kubernetes` view, the database being used, an in-memory database:
  ```yaml
  [demo-app]... --- [  restartedMain] o.f.c.i.database.base.BaseDatabaseType   : Database: jdbc:h2:mem:faa65c63-110b-4723-95d8-bbd3fb2642cb (H2 1.4)
  ```
* the datasource configuration has already been configured using externalized variables in the `src/main/resources/application.yaml` file. This configuration is being activated by the `cloud-dev` profile set in the deployment manifest `deployment.yaml`:
  ```yaml
  spring:
    config:
      activate:
        on-profile: cloud-dev
    datasource:
      url: 'jdbc:postgresql://${DB_HOST:127.0.0.1}/${DB_DATABASE:quote_db}'
      username: '${DB_USER:user}'
      password: '${DB_PASS:password}'
  ...    
  ```    

At this time, the app can be enhanced and connected directly to a `CloudSQL for Postgres managed instance in the Google Cloud`.

To set up a CloudSQL for Postgres database instance, please follow the instructions in [CloudSQL Setup Instructions](./docs/CloudSQLSetup.md).

The following additions to the `deployment.yaml` file allow the application to connect to the CloudSQL instances.
Notes:
* TARGET - configures the variable to indicate the environment where the app is executed
* SPRING_PROFILES_ACTIVE - shows the active Spring profile, which will be configured to `cloud-dev`
* DB_HOST - the private IP for the database, which has been noted when the database instance has been created or by clicking `SQL` in the Navigation Menu of the Google Cloud Console - please change the value !
* DB_USER and DB_PASS - as set in the CloudSQL instance configuration, stored as a Secret in GCP

```yaml
        env:
          - name: PORT
            value: "8080"
          - name: TARGET
            value: "Local Dev - CloudSQL Database - K8s Cluster"
          # set the profile to use
          - name: SPRING_PROFILES_ACTIVE
            value: cloud-dev
          - name: DB_HOST
            value: PRIVATE-IP-OF-DATABASE  # example "172.24.0.3" 
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

Save the file and start the app in the GKE cluster from `Cloud Code: Run on Kubernetees

Observe, in the `Kubernetes: Run/Debug - Detailed` dropdown that the app connects to the previously configured CloudSQL instance at <private IP of database>
```
...
[demo-app]... --- [  restartedMain] o.s.b.a.h2.H2ConsoleAutoConfiguration    : H2 console available at '/h2-console'. Database available at 'jdbc:postgresql://172.24.0.3/quote_db'
...
```

Test the app and observe that the root endpoint indicates in its output the environment change: `Local Dev - CloudSQL Database - K8s Cluster environment!`
```
Let's use either cURL or HTTPie for testing the app, from a Terminal window:
```shell
curl -v 127.0.0.1:8080
  or
http :8080

# Output: Hello from your Local Dev - CloudSQL Database - K8s Cluster environment!

curl -v 127.0.0.1:8080/random-quote
  or
http :8080/random-quote

# Output: 
{
    "author": "Marcus Tullius Cicero",
    "id": 2,
    "quote": "While there's life, there's hope"
}
```

Stop the application running in GKE!

## Congratulations - you have successfully completed the lab !