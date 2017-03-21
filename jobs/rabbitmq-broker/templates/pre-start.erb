#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

JOB_DIR=/var/vcap/jobs/rabbitmq-broker
ROOT_LOG_DIR=/var/vcap/sys/log
INIT_LOG_DIR=/var/vcap/sys/log/rabbitmq-broker

source /var/vcap/packages/rabbitmq-common/ensure_dir_with_permissions

main() {
  ensure_dir_with_permissions "${JOB_DIR}"
  ensure_dir_with_permissions "${ROOT_LOG_DIR}"
  ensure_dir_with_permissions "${INIT_LOG_DIR}"
}

main

# syslog forwarding
/var/vcap/packages/rabbitmq-syslog-aggregator/enable_syslog_config broker_syslog.conf $JOB_DIR/config
/var/vcap/packages/rabbitmq-syslog-aggregator/setup_syslog_forwarder $JOB_DIR/config

# restart rsyslog to use the latest configuration
/usr/sbin/service rsyslog restart
