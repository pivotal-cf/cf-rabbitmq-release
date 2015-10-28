# RabbitMQ Service Broker for Cloud Foundry

The repository also includes a service broker for RabbitMQ. If you
don't intend to run Cloud Foundry or don't wish to be able to
provision accounts in RabbitMQ via Cloud Foundry, you don't need to
worry about this component.


## Install Dependencies

With [Leiningen](http://leiningen.org) installed

```
cd src/rabbitmq-broker
lein deps
```

## Copy Example Config File

```
cp config/rabbitmq_broker.example.yml config/rabbitmq_broker.yml
```

and edit the config if necessary.

### Broker Configuration File

Example broker configuration file example can be found at
`src/rabbitmq-broker/config/rabbitmq_broker.example.yml`.


## Running Dependencies Locally

These steps are only needed if you want to run an instance locally for
development.

### NATS

NATS needs to be running on `127.0.0.1:4222`. Start it like so:

    nats-server -V

in a separate shell tab.

### UAA

UAA needs to be running locally, accessible at `http://localhost:8080/uaa`.
From the UAA repository:

    # Optionally to run against PostgreSQL
    # psql -c 'create database uaa;' -U postgres
    # psql -c 'create role root NOSUPERUSER LOGIN INHERIT CREATEDB;' -U postgres
    mvn tomcat:run

To override UAA configuration and add predefined users, create a file named `uaa.yml`
(e.g. under `/tmp/`), and use the `scim.users` property to list users. Note that at
least one user email has to match `:bootstrap_admin_email` in Cloud Controller config
file (see below).

Example:

``` yaml
oauth:
  client:
    autoapprove:
      - vmc
      - cf
      - cloud_controller
scim:
  users:
    - marissa|koala|marissa@test.org|Marissa|LastName|uaa.admin,cloud_controller.admin
    - michael|michaelpwd|michael@test.org|Michael|LastName|uaa.admin,cloud_controller.admin
    - p1-rabbit|p1-rabbitpwd|p1-rabbit@pivotalone.test.org|PivotalOne|RabbitMQ|uaa.admin,cloud_controller.admin

jwt:
  token:
    signing-key: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEpQIBAAKCAQEA6PWcD7C8gqpXyt7fYCH3nmY19G/+ySUHW3QSL5JpCk0OITMD
      Wm8g09MrCcz108l9oVLN9Wf6gQWgYxcbeIIxRIfA2A0VFwXPT3kj1YgijlRwrzuY
      Dhvls6VXB0oxArMRTTYaHg59Ut4FisweYev+w6X5kYGF7OxgypD11CDmOTFVXeCR
      gICUMcrUuMMFuTMscgwELhtOhDht5OzHTeLMTRbIfZWWKmEr4QgLJxYjFPypUoBR
      N6Hh1YJvroDJovvfhGcyLA0Y7V1pqx1eSqrItFylW8GyZifr2qfBQUukJct0lTaR
      5myDfm5So65wX57YPoGy6G8BtFnWeXjnxJ2QvwIDAQABAoIBAQDFew+krWngSo7J
      x00MrT6/5F1wrVALK3ylJiwUb8TjmpaTxi7dhr8JUkV1tW3e7zu0egFmO5K7tQ1V
      cs0yxwsE0R/FBrIOJjqrYEHkTdcdWK99nMM1kqiSNWMlJtuNMkdEcMyLFjVe/h8s
      ngRTdj8tk5GQq3/gbDFRBrmd7ZW8fFuZkOtn5eNQnjnrv1viExOw1GcbeeuvBbtM
      Z41Bd6sqY/ak/nOy8FDRv7bbGQmL9Bkh85OJ9lbHQ576J6fROSAs/ZRWwIRizHAE
      Ek5ICLqqrU4/g2HaTrMagdCy9HFtQROPjQgN5QaHHRwkc6jBBojejRVcKQtBGRsc
      vIuGEhwhAoGBAPW5FIppiqFC4Fcctgz0CRtHG+TrUhfNfO597T6XwG4dcSUuxNof
      CxUgEZavQYbsA0BZflXkqROjeW03u0Oz3IhEfXu8Ji6BvLBG2I+f/d30gkN3yZl8
      NW/5K6Nl7nNZovkiucA7wihGnONY9T4braWdqp+DsdqS1H92KpLdEU/lAoGBAPKz
      3zE9VHPjrxK204V46qKKSRfL6gtzLFOnWVz8hW+rIEKg3nHUy96Zz53CyxigM8wS
      QZCUAl5AXTbk9qdF81ZpFORxBbzcKz65sJFHISw0I8YVEGcTV7SELbYQRtAFvwLr
      Hw7Y0Feo+REPob7XjDgnICiQ4/kYw5oKg7DP5GvTAoGBALX9tTvqfVWArZ13U1J2
      sAP2/67lpzCf7gbJV5yDUm97+N/8KqoOUev8i2paNSMTzDitz8cYCy3TZszAeT7k
      iNKYP4QUTwck6bZ5Uk3VxnXMcWo83yCBgSaEmpBzn07pta3lzUOWPvALlIlByqmM
      YGkIRGXOaTykgSRCRbfuabMNAoGBAIwGcOfkvXvbSd/fMWxZVe4PIJqlIFQYz+M3
      sxwt6QKDVap7S7ubDUBRt3IKt8hubVP42HEEo9UjB2Srdw8NEZayK8ac2rWaxSx8
      T72RrzbkohsffgYqJ7jTZdgbze8o0YpqgtG7D4Dz0TchsKz9iT3AfRJKfezyd6/B
      DzeMyfnXAoGAHGKHI8OQ/OTjfqq8ct4maGKCPk/RDtTGClIn+MOQnuRV4nMkrRRW
      TwYvclz5ozsIIFMt65u9YeLPATPYR8tdt/DG2jzcMLbhsyLCsjool9f4lFLyv505
      uB6Z8IqgP7Qq5nfJpgpo4E9aIZnXww71GhDcyJrl2hMYO7he2Q4+ACU=
      -----END RSA PRIVATE KEY-----
    verification-key: |
      -----BEGIN PUBLIC KEY-----
      MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6PWcD7C8gqpXyt7fYCH3
      nmY19G/+ySUHW3QSL5JpCk0OITMDWm8g09MrCcz108l9oVLN9Wf6gQWgYxcbeIIx
      RIfA2A0VFwXPT3kj1YgijlRwrzuYDhvls6VXB0oxArMRTTYaHg59Ut4FisweYev+
      w6X5kYGF7OxgypD11CDmOTFVXeCRgICUMcrUuMMFuTMscgwELhtOhDht5OzHTeLM
      TRbIfZWWKmEr4QgLJxYjFPypUoBRN6Hh1YJvroDJovvfhGcyLA0Y7V1pqx1eSqrI
      tFylW8GyZifr2qfBQUukJct0lTaR5myDfm5So65wX57YPoGy6G8BtFnWeXjnxJ2Q
      vwIDAQAB
      -----END PUBLIC KEY-----
```

**Note** that `verification-key` has a dash in `uaa.yml` but an underscore (`verification_key`) in
`cloud_controller.yml`!

Running UAA then will require providing path to the custom config file:

    # must be set to a directory containing uaa.yml
    export UAA_CONFIG_PATH=/tmp/ mvn tomcat:run

To generate keys:

    openssl genrsa -out privkey.pem 2048
    openssl rsa -pubout -in privkey.pem -out pubkey.pem



### Cloud Controller

Cloud Controller needs to be running locally, accessible at `http://127.0.0.1:8181`.

Make sure your UAA token verification settings match CCNG. In `config/cloud_controller.yml`,
edit the `uaa` section to use PKI (`verification_key`) or shared secret (`symmetric_secret`).

Here's an example that uses PKI and provides a public key:

``` yaml
uaa:
  url: "http://localhost:8080/uaa"
  resource_id: "cloud_controller"
  # symmetric_secret: "tokensecret"
  verification_key: |
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6PWcD7C8gqpXyt7fYCH3
    nmY19G/+ySUHW3QSL5JpCk0OITMDWm8g09MrCcz108l9oVLN9Wf6gQWgYxcbeIIx
    RIfA2A0VFwXPT3kj1YgijlRwrzuYDhvls6VXB0oxArMRTTYaHg59Ut4FisweYev+
    w6X5kYGF7OxgypD11CDmOTFVXeCRgICUMcrUuMMFuTMscgwELhtOhDht5OzHTeLM
    TRbIfZWWKmEr4QgLJxYjFPypUoBRN6Hh1YJvroDJovvfhGcyLA0Y7V1pqx1eSqrI
    tFylW8GyZifr2qfBQUukJct0lTaR5myDfm5So65wX57YPoGy6G8BtFnWeXjnxJ2Q
    vwIDAQAB
    -----END PUBLIC KEY-----
```

Make sure you run migrations with

    bundle exec rake db:migrate

then run CCNG with

    # -s seeds development data (e.g. quota definitions)
    ./bin/cloud_controller -s

By default, log file is accessible at `/tmp/cloud_controller.log`. Many issues, e.g.
authentication failures, will be logged there.

If you see SQL constraint violation errors in the log, remove the SQLite database
CCNG uses:

    rm /tmp/cloud_controller.db

and re-run migrations:

    bundle exec rake db:migrate

then restart CCNG.

You can also modify default quota in `config/cloud_controller.yml` to provide many more service
instances (for example, to run stress tests):

``` yaml
quota_definitions:
  free:
    non_basic_services_allowed: false
    total_services: 2
    memory_limit: 512 # 0.5 GB
  paid:
    non_basic_services_allowed: true
    total_services: 500
    memory_limit: 204800 # 200 GB
  trial:
    non_basic_services_allowed: false
    total_services: 2
    memory_limit: 512 # 0.5 GB
    trial_db_allowed: true
  runaway:
    non_basic_services_allowed: true
    total_services: 50000
    memory_limit: 204800 # 200 GB

default_quota_definition: runaway
```


## Running the Broker

From [broker source directory](./src/rabbitmq-broker):

With Leiningen:

    lein run -- -c ./config/rabbitmq_broker.yml

as a standalone JAR (requires re-) :

    lein uberjar
    java -jar target/pcf-rabbitmq-[version]-standalone.jar -- -c ./config/rabbitmq_broker.yml

## Interacting with a local CC instance via cf

To inspect, bind, etc services, you need to interact with the local CCNG
instance using `cf` ([v6 or later](http://docs.cloudfoundry.org/devguide/installcf/))

    # point cf at our local CCNG instance
    cf api http://127.0.0.1:8181/
    # log in
    cf auth admin admin
    # create an org
    cf create-org p1-rabbitmq
    cf target -o p1-rabbitmq
    # create a space
    cf create-space dev -o p1-rabbitmq
    # switch to the new space
    cf target -s dev -o p1-rabbitmq
    # add our broker, adjust credentials and URL
    # as needed
    cf create-service-broker p-rabbitmq p1-rabbit p1-rabbit-devpwd http://127.0.0.1:4567

Then make one or more service plan(s) public, [per documentation](http://docs.cloudfoundry.org/services/access-control.html#make-plans-public).

### Listing Service Brokers in CC Catalog

Now

    cf service-brokers

should list our service broker.

### Creating an Instance

    # offering, plan, name
    # the name must be unique
    cf create-service p-rabbitmq standard rabbit-1



## Interacting with a Cloud Foundry installation

Inspecting, binding, etc against a CloudFoundry installation
is very similar to the instructions above except that there is no need to create
an organization and space.

Below code assumes Cloud Foundry is running in a local [bosh-lite](https://github.com/cloudfoundry/bosh-lite) VM using [our development manifest](./manifests/cf-rabbitmq-lite.yml) and Cloud Foundry CLI v6 (the Go version) is used.

    # point cf at a CloudFoundry running in bosh-lite
    cf api http://api.bosh-lite.com
    cf auth admin admin
    cf create-org pcf-rabbitmq
    cf target -o pcf-rabbitmq
    cf create-space dev
    cf target -o pcf-rabbitmq -s dev


### Running Registration Errand (`broker-registrar`)

Before a service broker can be used, it needs to be registered with CC. This can be done
manually using `cf`:

    cf create-service-broker p-rabbitmq p1-rabbit p1-rabbit-devpwd http://10.244.9.10:4567

but Pivotal CF services do it with an errand (a one-off job). The errand needs to be listed
in the deployment manifest:

    - name: broker-registrar
      release: cf-rabbitmq
      template: broker-registrar
      instances: 1
      lifecycle: errand
      networks:
      - name: services1
      properties:
        broker:
          host: 10.244.9.10
          port: 4567
          name: p-rabbitmq
          username: "p1-rabbit"
          password: "p1-rabbit-devpwd"
      resource_pool: services-small

    - name: broker-deregistrar
      release: cf-rabbitmq
      template: broker-deregistrar
      instances: 1
      lifecycle: errand
      networks:
      - name: services1
      properties:
        broker:
          host: 10.244.9.10
          port: 4567
          name: p-rabbitmq
          username: "p1-rabbit"
          password: "p1-rabbit-devpwd"
      resource_pool: services-small

    properties:
      # for broker registrar
      cf:
        admin_password: "admin"
        admin_username: "admin"
        api_url: http://api.bosh-lite.com

If you use [cf-rabbitmq-lite.yml](./manifests/cf-rabbitmq-lite.yml), it includes the errand
for you.

To run the errand, do

    bosh run errand broker-registrar

### Listing Service Brokers in CC Catalog

    # add our broker, adjust credentials and URL
    # as needed
    cf create-service-broker p-rabbitmq p1-rabbit p1-rabbit-devpwd http://[an IP CF apps can access]:4567

    cf service-brokers

### Creating an Instance

    # offering, plan, name
    # the name must be unique
    cf create-service rabbitmq standard rabbit-1


### Binding an App

To bind a service instance to an app, you need to deploy an app first.
[Lab Rat](https://github.com/pivotal-cf/rabbit-labrat) is a good candidate.

To deploy the app to Cloud Foundry, do

    cf push lab-rat

Then do

    cf bind-service lab-rat [service name]

The redeploy or restart Lab Rat and it should display updated `VCAP_SERVICES`
value on the home page.

To verify RabbitMQ node connectivity, visit `[deployed lab rat URL]/services/rabbitmq`.


### Unbinding an App

    cf unbind-service lab-rat [service name]

and choose the app to unbind to. This will remove the credentials created for the
app and after restart, `VCAP_SERVICES` value will change. This will also make
sure to close existing RabbitMQ connections for the user.


### Deleting an Instance

    cf delete-service [instance]


## Running Broker Test Suites

Broker test suite includes integration tests. However, the test suite
only interacts with RabbitMQ and does not require UAA and CC to be
running locally.

To run all tests, use

    lein test

To stress test the broker, you can use the following script:

``` ruby
#!/usr/bin/env ruby

(0..5000).each do |i|
  name = "rabbit-#{i}"
  puts "Creating service #{name}"
  `cf create-service rabbitmq standard rabbit-1`

  puts "Deleting service #{name}"
  `cf delete-service #{name} -f`
end
```
