# Cloud Foundry RabbitMQ Service

This repository contains the release for RabbitMQ for Cloud Foundry.
It is deployable by BOSH in the [usual way](https://bosh.io/docs/deploying.html).

This release is now using BOSH v2 [job links](https://bosh.io/docs/links.html) and [cloud config](https://bosh.io/docs/cloud-config.html) and requires at least BOSH Director v255.5

## Status

Job | Status
--- | ---
unit tests | [![hush-house.pivotal.io](https://hush-house.pivotal.io/api/v1/teams/pcf-rabbitmq/pipelines/cf-rabbitmq-release/jobs/unit-tests/badge)](https://hush-house.pivotal.io/teams/pcf-rabbitmq/pipelines/cf-rabbitmq-release/jobs/unit-tests)
integration tests | [![hush-house.pivotal.io](https://hush-house.pivotal.io/api/v1/teams/pcf-rabbitmq/pipelines/cf-rabbitmq-release/jobs/integration-test/badge)](https://hush-house.pivotal.io/teams/pcf-rabbitmq/pipelines/cf-rabbitmq-release/jobs/integration-test)

## Dependencies

- [bundler](http://bundler.io/)
- [BOSH CLI v2](https://bosh.io/docs/cli-v2.html#install)
- [BOSH Lite](https://bosh.io/docs/bosh-lite)


## Install (locally)

Clone the repository and install dependencies.
```bash
$ bundle install
```

## Deploying

Once you have a [BOSH Lite up and running locally](https://bosh.io/docs/bosh-lite), run `scripts/deploy-to-bosh-lite`.

To deploy the release into BOSH you will need a deployment manifest. You can generate a deployment manifest using the following command:
```sh
bosh interpolate \
  --vars-file=manifests/lite-vars-file.yml \
  manifests/cf-rabbitmq-template.yml
```

Alternatively, you can use the `scripts/generate-manifest` in order to generate a vanilla manifest for BOSH lite.

Currently, the release has only been tested to run on manual networks (https://bosh.io/docs/networks/).

## Testing

Run `bundle exec rake --tasks` to list all the test subsets.

### Unit Tests

To run only unit tests locally, run: `scripts/unit-test`.

### Integration Tests
Integration tests require this release to be deployed into a BOSH director (see [Deploying section above](#deploying)).

To run integration tests do `scripts/integration-test`.

### Embedded Release Tests

Sometimes testing BOSH releases can lead to writing many tests at the top of
the test pyramid, which can increase the feedback loop. Also when tests fail
debugging can be hard given there are many components working together.

Embedded release tests are jobs that we deploy in a co-located way so that we
can execute tests within a given deployment, inside a VM. The goal is to pull
tests down the test pyramid trying to shorten the feedback loop and bring the
tests closer to the code.

To execute embedded release tests you need to co-locate the tests within the
release being tested and deploy. The deployment should fail if the tests fail.
The tests we use can be found in the [test release repo](https://github.com/pivotal-cf/cf-rabbitmq-test-release).

### Bonus
Back in time [Multitenant Broker Release](https://github.com/pivotal-cf/cf-rabbitmq-multitenant-broker-release/) used to live in the same Github repository as [cf-rabbitmq-release](https://github.com/pivotal-cf/cf-rabbitmq-release), but not anymore. We have split both releases into two different repositories. They do different things and have different lifecyle, which explains our decision to do that.

A collection of ops-files and vars-files, features from [Bosh 2 CLI](https://bosh.io/docs/cli-int/), can be used to generate manifests. You’ll find a folder called `manifests` in both repositories with a manifest template, some ops-files and example of vars-files. It's not required to have two different deployments for `cf-rabbitmq-release` and `cf-rabbitmq-multitenant-broker-release`. In case you want to colocate both jobs you can leverage [this ops-file](https://github.com/pivotal-cf/cf-rabbitmq-multitenant-broker-release/blob/master/manifests/add-cf-rabbitmq.yml) to colocate them in the same deployment.

[More information about bosh interpolate](https://bosh.io/docs/cli-int/).

