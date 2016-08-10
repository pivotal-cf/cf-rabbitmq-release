#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

LOG_DIR=/var/vcap/sys/log/rabbitmq-server

PATH=/var/vcap/jobs/rabbitmq-server/bin:$PATH

log_node_check() {
  echo "$*" >> "${LOG_DIR}/node-check.log"
}

log_cluster_check() {
  echo "$*" >> "${LOG_DIR}/cluster-check.log"
}

log_node_check "Calling node-check from post-deploy"
node-check
log_node_check "Finished node-check from post-deploy"

log_cluster_check "Calling cluster-check from post-deploy"
cluster-check
log_cluster_check "Finished cluster-check from post-deploy"
