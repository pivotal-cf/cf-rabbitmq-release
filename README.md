# Cloud Foundry RabbitMQ Service

This repository contains the release for RabbitMQ for Cloud Foundry.
It is deployable by BOSH in the usual way.

## Updating

Clone the repository and run `./scripts/update-release`.

## Testing

### Unit Tests

To run the unit tests locally, just run: `bundle exec rake spec:unit`.

You can run it from docker by using `./scripts/from-docker bundle exec rake spec:unit`.

## Documentation

 * [BOSH Installation](docs/bosh_install.md)
 * [Anatomy of RabbitMQ BOSH release](docs/bosh_rabbitmq.md)
 * [Service Broker](docs/service_broker.md)
