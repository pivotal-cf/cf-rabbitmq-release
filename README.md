# Cloud Foundry RabbitMQ Service

This repository contains the release for RabbitMQ for Cloud Foundry.
It is deployable by BOSH in the usual way.

This release is now using BOSH v2 [job links](https://bosh.io/docs/links.html) and [cloud config](https://bosh.io/docs/cloud-config.html) and requires at least BOSH Director v255.5

## Dependencies

- [bundler](http://bundler.io/)
- [BOSH CLI v2](https://bosh.io/docs/cli-v2.html#install)
- [BOSH Lite](https://bosh.io/docs/bosh-lite)

## Updating

Clone the repository, update submodules and install dependencies.
```bash
$ git submodule update --init --recursive
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

## Testing

To run all the tests do `bundle exec rake spec`.

Run `bundle exec rake --tasks` to list all the test subsets.

### Unit Tests

To run only unit tests locally, run: `bundle exec rake spec:unit`.

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


### Integration Tests
Integration tests require this release to be deployed into a BOSH director (see [Deploying section above](#deploying)).

To run integration tests do `bundle exec rake spec:integration`.
