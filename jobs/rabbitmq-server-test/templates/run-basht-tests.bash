#!/usr/bin/env bash

set -e

export PATH=$PATH:/var/vcap/packages/basht/bin:/var/vcap/packages/rabbitmq-server/bin:/var/vcap/packages/erlang/bin

run_basht_tests() {
  basht "$JOB_DIR"/bin/check-cluster-mechanism
}

run_basht_tests
