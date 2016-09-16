#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

PATH=/var/vcap/jobs/rabbitmq-server/bin:$PATH

node-check "post-deploy"
cluster-check "post-deploy"
add-rabbitmqctl-to-path
