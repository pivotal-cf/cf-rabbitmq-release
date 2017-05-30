# Cloud Foundry RabbitMQ Service

This repository contains the release for RabbitMQ for Cloud Foundry.
It is deployable by BOSH in the usual way.

This release is now using BOSH v2 [job links](https://bosh.io/docs/links.html) and [cloud config](https://bosh.io/docs/cloud-config.html) and requires at least BOSH Director v255.5

## Dependencies

- [bundler](http://bundler.io/)

- [phantomjs](http://phantomjs.org/): In order to run the integration tests you need to have `phantomjs` available in the `$PATH`. `phantomjs` is required by `capybara` at runtime.

## Updating

Clone the repository and run `./scripts/update-release` to update submodules and install dependencies.

## Deploying

Once you have a [BOSH Lite up and running locally](https://github.com/cloudfoundry/bosh-lite), run `scripts/deploy-bosh-lite`.

To deploy the release into BOSH you will need a deployment manifest. You can generate a deployment manifest using the following command:
```sh
bosh interpolate \
  --vars-file=manifests/lite-vars-file.yml \
  --var=director-uuid=$(bosh status --uuid) \
  manifests/cf-rabbitmq-server-only-template.yml > manifests/cf-rabbitmq.yml
```

## Testing

To run all the tests do `bundle exec rake spec`.

### Unit Tests

To run only unit tests locally, run: `bundle exec rake spec:unit`.

### Integration Tests
Integration tests require this release to be deployed into a BOSH director (see [Deploying section above](#deploying)).

To run integration tests do `bundle exec rake spec:integration`.

Use `SKIP_SYSLOG=true bundle exec rake spec:integration` to skip syslog tests if you don't have `PAPERTRAIL_TOKEN` and `PAPERTRAIL_GROUP_ID` environment variables configured.

For testing with syslog, remove the `SYSLOG` environment variable from the command line and generate and deploy a new manifest with syslog:

```sh
alias boshgo=bosh # This is just to make pcf-rabbitmq tile team's life simpler
boshgo interpolate \
  --ops-file=manifests/add-syslog-release.yml \
  --vars-file=manifests/lite-vars-file.yml \
  --var=director-uuid=$(bosh status --uuid) \
  manifests/cf-rabbitmq-server-only-template.yml > manifests/cf-rabbitmq.yml
```

### System Tests
System tests require this release to be deployed colocated within the [multitenant-broker](https://github.com/pivotal-cf/cf-rabbitmq-broker-release) release.

Ensure you have deployed the release to BOSH Lite (see [Deploying section above](#deploying)).

Use the bosh command below to create a manifest with cf-rabbitmq and multitenant-broker.
```sh
alias boshgo=bosh # This is just to make pcf-rabbitmq tile team's life simpler
boshgo interpolate \
  --vars-file=manifests/lite-vars-file.yml \
  --vars-file=manifests/lite-multitenant-broker-vars-file.yml \
  --var=director-uuid=$(bosh status --uuid) \
  manifests/cf-rabbitmq-colocated-with-multitenant-broker-template.yml > manifests/cf-rabbitmq.yml
```

To run the system tests do `bundle exec rake spec:system`

If you want to run tests on custom BOSH you need to set following environment variables:

## Documentation

 * [BOSH Installation](docs/bosh_install.md)
 * [Anatomy of RabbitMQ BOSH release](docs/bosh_rabbitmq.md)
 * [Service Broker](docs/service_broker.md)
