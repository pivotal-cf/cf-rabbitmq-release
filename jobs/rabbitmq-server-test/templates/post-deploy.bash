#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

PATH=/var/vcap/jobs/rabbitmq-server-test/bin:$PATH

rabbitmq-server-test.init start
