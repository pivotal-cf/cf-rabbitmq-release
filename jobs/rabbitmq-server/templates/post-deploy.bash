#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

PATH=/var/vcap/jobs/rabbitmq-server/bin:$PATH

node-check
cluster-check
