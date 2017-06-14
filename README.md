# Cloud Foundry RabbitMQ Service

This repository contains the release for RabbitMQ for Cloud Foundry.
It is deployable by BOSH in the usual way.

This release is now using BOSH v2 [job links](https://bosh.io/docs/links.html) and [cloud config](https://bosh.io/docs/cloud-config.html) and requires at least BOSH Director v255.5

## Updating

Clone the repository and run `./scripts/update-release`.

## Deploying

Once you have a [BOSH Lite up and running locally](https://github.com/cloudfoundry/bosh-lite), run `scripts/deploy-bosh-lite`

## Testing

### Dependencies
In order to run the integration tests you need to have `phantomjs` available in the `$PATH`. `phantomjs` is required by `capybara` at runtime.

### Unit Tests

To run the unit tests locally, just run: `bundle exec rake spec:unit`.

### Embedded Release Tests

Sometimes testing BOSH releases can lead to writing many tests at the top of
the test pyramid, which can increase the feedback loop. Also when tests fail the
analysis can become complicated since there are many components working together.
Embedded release tests are jobs that we deploy in a colocated way so that we can
execute tests within a deployment, inside a VM. The goal is to pull tests down
the test pyramid trying to shorten the feedback loop and bring the tests closer
to the code.

To execute embedded release tests you need to colocate the tests within the
release being tested and deploy. The deployment should fail if the tests fail.

```sh
boshgo interpolate \
  --ops-file=manifests/add-rmq-server-tests.yml \
  --vars-file=manifests/lite-vars-file.yml \
  --var=director-uuid=$(bosh status --uuid) \
  manifests/cf-rabbitmq-server-only-template.yml > manifests/cf-rabbitmq.yml
```

```sh
bosh deployment manifests/cf-rabbitmq.yml
```

```sh
bosh deploy
```

### Integration Tests

Ensure you have deployed the release to BOSH Lite. Set `BOSH_MANIFEST` env to `$PWD/manifests/cf-rabbitmq.yml` and run `bundle exec rake spec:system`

If you want to run tests on custom BOSH you need to set following environment variables:

```sh
export CF_DOMAIN='bosh-lite.com'
export CF_USERNAME='admin'
export CF_PASSWORD='admin'
export CF_API='api.bosh-lite.com'
export BOSH_TARGET='bosh-lite.com'
export BOSH_USERNAME='admin'
export BOSH_PASSWORD='admin'
```

## Documentation

 * [BOSH Installation](docs/bosh_install.md)
 * [Anatomy of RabbitMQ BOSH release](docs/bosh_rabbitmq.md)
 * [Service Broker](docs/service_broker.md)
