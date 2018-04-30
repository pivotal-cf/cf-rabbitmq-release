#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/jobs/rabbitmq-server/bin:/var/vcap/packages/erlang/bin:/var/vcap/packages/rabbitmq-server/bin:$PATH

ERLANG_PID_FILE=/var/vcap/sys/run/rabbitmq-server/pid

LOG_DIR=/var/vcap/sys/log/rabbitmq-server
SHUTDOWN_LOG="${LOG_DIR}"/shutdown_stdout.log
SHUTDOWN_ERR_LOG="${LOG_DIR}"/shutdown_stderr.log
DRAIN_LOG="${LOG_DIR}/drain.log"

main() {
  log "Begin RabbitMQ node shutdown ..."

  if rabbitmq_node_is_stopped
  then
    log "RabbitMQ node is not running, nothing to shutdown."
  else
    log "Stop RabbitMQ node..."
    stop_erlang_vm_and_rabbitmq_app
    log "Checking RabbitMQ node is stopped ..."
    rabbitmq_node_is_stopped
    rm -f "$ERLANG_PID_FILE"
    log "RabbitMQ node stopped successfully."
  fi

  echo "0"
}

log() {
  echo "$*" 1>> "$SHUTDOWN_LOG"
}

rabbitmq_node_is_stopped() {
  if erlang_pid_file_exists
  then
    ! erlang_pid_points_to_a_running_process
  fi

  ! rabbitmqctl_returns_an_erlang_pid
}

rabbitmqctl_returns_an_erlang_pid() {
  rabbitmqctl eval 'list_to_integer(os:getpid()).' 1>> "$DRAIN_LOG" 2>&1
}

erlang_pid_file_exists() {
  [ -f "$ERLANG_PID_FILE" ]
}

erlang_pid_points_to_a_running_process() {
  ps "$(cat $ERLANG_PID_FILE)" 1>> "$DRAIN_LOG" 2>&1
}

stop_erlang_vm_and_rabbitmq_app() {
  set +e
  rabbitmqctl stop "$ERLANG_PID_FILE" 1>> "$SHUTDOWN_LOG" 2>> "$SHUTDOWN_ERR_LOG"
  exit_status=$?
  if [[ $exit_status == 70 ]]
  then
    log "RabbitMQ application is not running, but the Erlang VM was. Erlang VM has been shutdown."
  fi
  set -e
}

main
