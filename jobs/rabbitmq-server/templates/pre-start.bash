#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

JOB_DIR=/var/vcap/jobs/rabbitmq-server
PID_FILE=/var/vcap/sys/run/rabbitmq-server/pid
HOME_DIR=/var/vcap/store/rabbitmq
ROOT_LOG_DIR=/var/vcap/sys/log
INIT_LOG_DIR=/var/vcap/sys/log/rabbitmq-server
HTTP_ACCESS_LOG_DIR="${INIT_LOG_DIR}"/management-ui
STARTUP_LOG="${INIT_LOG_DIR}"/startup_stdout.log
STARTUP_ERR_LOG="${INIT_LOG_DIR}"/startup_stderr.log
SHUTDOWN_LOG="${INIT_LOG_DIR}"/shutdown_stdout.log
SHUTDOWN_ERR_LOG="${INIT_LOG_DIR}"/shutdown_stderr.log
USER=vcap

main() {
  ensure_dir "${ROOT_LOG_DIR}"
  ensure_dir "${INIT_LOG_DIR}"
  ensure_dir "${HTTP_ACCESS_LOG_DIR}"
  ensure_dir "$(dirname "${PID_FILE}")"
  ensure_dir "${HOME_DIR}"
  ensure_dir "${JOB_DIR}"
  ensure_log_files
  ensure_http_log_cleanup_cron_job

  # shellcheck disable=SC1090
  . "${JOB_DIR}"/bin/prepare-for-upgrade
}

ensure_dir() {
    _dir=$1
    mkdir -p "${_dir}"
    chown -LR "${USER}":"${USER}" "${_dir}"
    chmod 750 "${_dir}"
}

ensure_log_files() {
  touch "${STARTUP_LOG}"
  touch "${STARTUP_ERR_LOG}"
  touch "${SHUTDOWN_LOG}"
  touch "${SHUTDOWN_ERR_LOG}"
  chown "${USER}":"${USER}" "${INIT_LOG_DIR}"/startup*
  chown "${USER}":"${USER}" "${INIT_LOG_DIR}"/shutdown*
}

ensure_http_log_cleanup_cron_job() {
  cp "${JOB_DIR}/bin/cleanup-http-logs" /etc/cron.daily
}

main

# syslog forwarding
/var/vcap/packages/rabbitmq-syslog-aggregator/enable_syslog_config rabbitmq_syslog.conf $JOB_DIR/config
/var/vcap/packages/rabbitmq-syslog-aggregator/setup_syslog_forwarder $JOB_DIR/config

# restart rsyslog to use the latest configuration
/usr/sbin/service rsyslog restart
