#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

PATH=/var/vcap/jobs/rabbitmq-server/bin:$PATH

node-check "post-start"
cluster-check "post-start"
add-rabbitmqctl-to-path
