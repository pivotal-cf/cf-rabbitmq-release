#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

PATH=/var/vcap/jobs/rabbitmq-server/bin:/var/vcap/packages/rabbitmq-server/bin:/var/vcap/packages/erlang/bin/:$PATH
export PATH

node-check "post-deploy"
cluster-check "post-deploy"
add-rabbitmqctl-to-path
enable-feature-flags
