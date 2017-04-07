#!/bin/bash

set -e

. /var/vcap/jobs/smoke-tests/bin/change-permissions
. /var/vcap/jobs/smoke-tests/bin/permissions-test

export GOPATH=/var/vcap/packages/cf-rabbitmq-smoke-tests
export GOROOT=/var/vcap/packages/golang-1.8
export PATH=/var/vcap/packages/cf-cli/bin:$GOPATH/bin:$GOROOT/bin:$PATH

export REPO_NAME=github.com/pivotal-cf/cf-rabbitmq-smoke-tests
export REPO_DIR=${GOPATH}/src/${REPO_NAME}

export CONFIG_PATH=/var/vcap/jobs/smoke-tests/config.json

pushd ${REPO_DIR}
 ./bin/test
popd
