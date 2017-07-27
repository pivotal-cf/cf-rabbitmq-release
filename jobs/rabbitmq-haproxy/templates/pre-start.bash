#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

JOB_DIR=/var/vcap/jobs/rabbitmq-haproxy
ROOT_LOG_DIR=/var/vcap/sys/log
INIT_LOG_DIR=/var/vcap/sys/log/rabbitmq-haproxy
SERVICE_METRICS_DIR=/var/vcap/sys/log/service-metrics

source /var/vcap/packages/rabbitmq-common/ensure_dir_with_permissions

KNOWN_PACKAGES="$("$(dirname "$0")/known-packages.bash")"

main() {
    ensure_dir_with_permissions "${ROOT_LOG_DIR}"
    ensure_dir_with_permissions "${INIT_LOG_DIR}"
    ensure_dir_with_permissions "${SERVICE_METRICS_DIR}"
    ensure_dir_with_permissions "${JOB_DIR}"
    ensure_dir_with_permissions "${JOB_DIR}/packages"

    for package in ${KNOWN_PACKAGES}; do
      ensure_dir_with_permissions "${JOB_DIR}/packages/$package"
    done
}

main

# stop syslog
/usr/sbin/service rsyslog stop

# We think that the issue (#149389903) is caused by flooding syslog
# with events related to chown-ing and chmod-ing files. Because syslog restarts
# during this time, syslog falls into a bad state.
# Adding a sleep seems to allow rsyslog to settle down and does not
# trigger symptoms that the customers have seen (vm does not accept
# new connection). We are adding the sleep only in the 1.8 line (226 release)
# and only in the haproxy job because it happened only here and we don't want to
# hide issue in other jobs/lines.
#
# This fix should be temporary
sleep 3

# syslog forwarding
/var/vcap/packages/rabbitmq-syslog-aggregator/enable_syslog_config haproxy_syslog.conf $JOB_DIR/config
/var/vcap/packages/rabbitmq-syslog-aggregator/setup_syslog_forwarder $JOB_DIR/config

# start rsyslog to use the latest configuration
/usr/sbin/service rsyslog start
