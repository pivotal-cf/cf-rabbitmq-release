#!/bin/bash -e
#
# rabbitmq-server RabbitMQ broker

# Note: if in rabbitmq-env.conf you change the location of the PID file,
# (probably by setting PID_FILE) things will continue to work, even from
# this file, as the rabbitmq-env script (sourced by all the rabbitmq
# commands) will equally source the rabbitmq-env.conf file and so
# PID_FILE will be reset every time, correctly). However, this file will
# still have the wrong definition of PID_FILE and so will create the
# "wrong" directory. Meh-ish.

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin:$PATH
export LANGUAGE="en_US.UTF-8"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

RMQ_SERVER_PACKAGE=/var/vcap/packages/rabbitmq-server
DAEMON=${RMQ_SERVER_PACKAGE}/bin/rabbitmq-server
CONTROL=${RMQ_SERVER_PACKAGE}/bin/rabbitmqctl
PID_FILE=/var/vcap/sys/run/rabbitmq-server/pid
HOME_DIR=/var/vcap/store/rabbitmq
OPERATOR_USERNAME_FILE="${HOME_DIR}/operator_administrator.username"
START_PROG=/usr/bin/setsid

JOB_DIR=/var/vcap/jobs/rabbitmq-server

LOG_DIR=/var/vcap/sys/log/rabbitmq-server
STARTUP_LOG="$LOG_DIR/startup_stdout.log"
STARTUP_ERR_LOG="$LOG_DIR/startup_stderr.log"

test -x "$DAEMON"
test -x "$CONTROL"
test -x "$START_PROG"

RETVAL=0

# shellcheck disable=SC1091
[ -f "/var/vcap/store/rabbitmq/etc/default/rabbitmq-server" ] && . "/var/vcap/store/rabbitmq/etc/default/rabbitmq-server"
# shellcheck disable=SC1091
. /var/vcap/jobs/rabbitmq-server/etc/config
# shellcheck disable=SC1091
. /var/vcap/jobs/rabbitmq-server/lib/prepare-for-upgrade.bash

write_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"): $*"
}

delete_operator_admin() {
  set +e
  USERNAME="$(cat $OPERATOR_USERNAME_FILE)"
  "$CONTROL" delete_user "$USERNAME" >> "$STARTUP_LOG" 2>&1
  set -e
  true
}

run_script() {
    local script
    script=$1
    write_log "Starting $script"
    set +e
    "$script" \
        1>> "$STARTUP_LOG" \
        2>> "$STARTUP_ERR_LOG"
    RETVAL=$?
    set -e
    case "${RETVAL}" in
        0)
            write_log "Finished $script"
            return 0
            ;;
        *)
            write_log "Errored $script"
            RETVAL=1
            exit "$RETVAL"
            ;;
    esac
}

set_file_descriptor_limit() {
  local limit
  limit=$1

  if [[ "$(lsb_release -c | awk '{print $2}')" == "trusty" ]]
  then
    ulimit -n "$limit"
  else
    limits_file=/etc/security/limits.d/rabbitmq.conf
    echo "vcap    soft    nofile  $limit" >> "$limits_file"
    echo "vcap    hard    nofile  $limit" >> "$limits_file"
  fi
}

start_rabbitmq () {
    status_rabbitmq

    set_file_descriptor_limit "$RMQ_FD_LIMIT"

    write_log "Start RabbitMQ node..."

    if [ "$RETVAL" = 0 ]; then
        "$CONTROL" eval 'list_to_integer(os:getpid()).' > $PID_FILE
        write_log "RabbitMQ is currently running"
        if [ -f "$PID_FILE" ]
        then
          /var/vcap/jobs/rabbitmq-server/bin/node-check "rabbitmq-server.init" ||
          signal_monit_that_rabbitmq_node_is_not_healthy
        fi
    else
        RETVAL=0
        run_script "$JOB_DIR/bin/setup.sh"
        run_prepare_for_upgrade_when_first_deploy "/var/vcap/store/rabbitmq/mnesia" "/var/vcap/packages/rabbitmq-server" "/var/vcap/packages/erlang"

        write_log "Starting RabbitMQ"
        track_rabbitmq_erlang_vm_pid_in_pid_file

        . "$JOB_DIR/lib/rabbitmq-config-vars.bash"

        RABBITMQ_CONF_ENV_FILE="$HOME_DIR/etc/rabbitmq/rabbitmq-env.conf" \
          RABBITMQ_LOG_BASE="$LOG_DIR" \
          RABBITMQ_MNESIA_BASE="$HOME_DIR/mnesia" \
          RABBITMQ_PID_FILE="$PID_FILE" \
          "$START_PROG" "$DAEMON" \
            >> "$STARTUP_LOG" \
            2>> "$STARTUP_ERR_LOG" \
            0<&- &
    fi
}

signal_monit_that_rabbitmq_node_is_not_healthy() {
  write_log "RabbitMQ node is not healthy"

  echo 0 > "$PID_FILE"
}

track_rabbitmq_erlang_vm_pid_in_pid_file() {
  export RUNNING_UNDER_SYSTEMD=true
}


status_rabbitmq() {
    set +e
    if [ "$1" != "quiet" ]; then
        "$CONTROL" status 2>&1
    else
        "$CONTROL" status > /dev/null 2>&1
    fi
    if [ $? != 0 ]; then
        RETVAL=3
    fi
    set -e
}

send_all_output_to_logfile() {
  exec 1> >(tee -a "$LOG_DIR/init.log") 2>&1
}
send_all_output_to_logfile

start_rabbitmq

exit "$RETVAL"
