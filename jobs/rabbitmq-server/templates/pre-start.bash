#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

JOB_DIR=/var/vcap/jobs/rabbitmq-server
PID_FILE=/var/vcap/sys/run/rabbitmq-server/pid
HOME_DIR=/var/vcap/store/rabbitmq
SERVICE_METRICS_DIR=/var/vcap/sys/log/service-metrics
ROOT_LOG_DIR=/var/vcap/sys/log
INIT_LOG_DIR=/var/vcap/sys/log/rabbitmq-server
HTTP_ACCESS_LOG_DIR="${INIT_LOG_DIR}"/management-ui
STARTUP_LOG="${INIT_LOG_DIR}"/startup_stdout.log
STARTUP_ERR_LOG="${INIT_LOG_DIR}"/startup_stderr.log
SHUTDOWN_LOG="${INIT_LOG_DIR}"/shutdown_stdout.log
SHUTDOWN_ERR_LOG="${INIT_LOG_DIR}"/shutdown_stderr.log
USER=vcap

source /var/vcap/packages/rabbitmq-common/ensure_dir_with_permissions

main() {
  write_log "pre-start script started"
  remove_old_syslog_config

  ensure_dir_with_permissions "${ROOT_LOG_DIR}"
  ensure_dir_with_permissions "${INIT_LOG_DIR}"
  ensure_dir_with_permissions "${HTTP_ACCESS_LOG_DIR}"
  ensure_dir_with_permissions "$(dirname "${PID_FILE}")"
  ensure_dir_with_permissions "${HOME_DIR}"
  ensure_dir_with_permissions "${JOB_DIR}"
  ensure_dir_with_permissions "${SERVICE_METRICS_DIR}"
  ensure_log_files
  ensure_http_log_cleanup_cron_job

  # shellcheck disable=SC1090
  . "${JOB_DIR}"/lib/prepare-for-upgrade.bash
  . "${JOB_DIR}"/lib/rabbitmq-config-vars.bash

  local rmq_server_package
  rmq_server_package=$(configure_rmq_version)
  run_rabbitmq_upgrade_preparation_shutdown_cluster_if_cookie_changed "$ERLANG_COOKIE" "${HOME_DIR}/.erlang.cookie" "$RABBITMQ_NODES_STRING" "$rmq_server_package"
  setup_erl_inetrc
  add_env_to_global_shell_profile
  ${JOB_DIR}/bin/plugins.sh
  write_log "pre-start script completed"
}

write_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"): $*"
}

remove_old_syslog_config() {
  rm -f /etc/rsyslog.d/00-syslog_forwarder.conf
  rm -f /etc/rsyslog.d/rabbitmq_syslog.conf
}

ensure_log_files() {
  touch "$STARTUP_LOG"
  touch "$STARTUP_ERR_LOG"
  touch "$SHUTDOWN_LOG"
  touch "$SHUTDOWN_ERR_LOG"
  chown "$USER":"$USER" "$INIT_LOG_DIR"/startup*
  chown "$USER":"$USER" "$INIT_LOG_DIR"/shutdown*
}

ensure_http_log_cleanup_cron_job() {
  cp "$JOB_DIR/bin/cleanup-http-logs" /etc/cron.daily
}

configure_rmq_version() {
  rm -rf /var/vcap/packages/rabbitmq-server
  ln -s /var/vcap/packages/rabbitmq-server-"$RMQ_SERVER_VERSION" /var/vcap/packages/rabbitmq-server
  echo "/var/vcap/packages/rabbitmq-server"
}

configure_erlang_version() {
  rm -rf /var/vcap/packages/erlang
  ln -s /var/vcap/packages/erlang-"$ERLANG_MAJOR_VERSION" /var/vcap/packages/erlang
  echo "/var/vcap/packages/erlang"
}

setup_erl_inetrc() {
  . /var/vcap/jobs/rabbitmq-server/lib/rabbitmq-config-vars.bash

  configure_rmq_version
  configure_erlang_version

  # Unfortunate tight coupling. Beware.
  # We need this for CONF_ENV_FILE, HOME, ERL_INETRC, and for MNESIA_BASE
  . /var/vcap/packages/rabbitmq-server/privbin/rabbitmq-defaults

  # 1. Write out our new erl_inetrc file. We do this to avoid modifying
  #    /etc/hosts.
  #    See http://erlang.org/doc/apps/erts/inet_cfg.html for more info.
  DIR=$(mktemp -d)
  trap "rm -rf ${DIR}" EXIT

  printf "%s{lookup, [file, native]}.\n" "$ERL_INETRC_HOSTS" >> "$DIR/erl_inetrc"
  cp "$DIR/erl_inetrc" "$ERL_INETRC"
  mkdir -p "$(dirname "$CONF_ENV_FILE")"
}

add_env_to_global_shell_profile() {
  ln -sf "$JOB_DIR/bin/env" "/etc/profile.d/rabbitmq-server-env.sh"
}

main
