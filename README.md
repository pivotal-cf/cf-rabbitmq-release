# Cloud Foundry RabbitMQ Service

This repository contains the release for RabbitMQ for Cloud Foundry.
It is deployable by BOSH in the usual way.

## Updating

Clone the repository and run `./scripts/update-release`.

## Deploying

Run the `scripts/deploy-release` script. Examples as follows:

```
# Deploying locally to BOSH lite
export BOSH_MANIFEST=../london-ci-tools/manifests/rabbitmq/develop/development/bosh-lite.yml
./scripts/deploy-release lite

# Deploying to a different BOSH director
export BOSH_MANIFEST=/path/to/manifest.yml
./scripts/deploy-release my-bosh-alias
```

Note that the argument is a BOSH alias, which you must have configured prior to running the script. E.G.

```
bosh target https://192.168.50.4:25555 lite
```

## Testing

### Unit Tests

To run the unit tests locally, just run: `bundle exec rake spec:unit`.

You can run it from docker by using `./scripts/from-docker bundle exec rake spec:unit`.

## Documentation

 * [BOSH Installation](docs/bosh_install.md)
 * [Anatomy of RabbitMQ BOSH release](docs/bosh_rabbitmq.md)
 * [Service Broker](docs/service_broker.md)
