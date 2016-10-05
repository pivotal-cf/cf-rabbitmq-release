#!/bin/bash

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin:/var/vcap/packages/rabbitmq-server/bin:$PATH

ERLANG_PID_FILE=/var/vcap/sys/run/rabbitmq-server/pid

LOG_DIR=/var/vcap/sys/log/rabbitmq-server
SHUTDOWN_LOG="${LOG_DIR}"/shutdown_stdout.log
SHUTDOWN_ERR_LOG="${LOG_DIR}"/shutdown_stderr.log

main() {
  log "Begin RabbitMQ node shutdown ..."

  if rabbitmq_node_is_stopped
  then
    log "RabbitMQ node is not running, nothing to shutdown."
  else
    rabbitmq_node_is_healthy
    cluster_is_healthy
    log "Stop RabbitMQ node..."
    rabbitmqctl stop "$ERLANG_PID_FILE" 1>> "$SHUTDOWN_LOG" 2>> "$SHUTDOWN_ERR_LOG"
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
  ! something_is_using_the_rabbit_store
}

rabbitmqctl_returns_an_erlang_pid() {
  rabbitmqctl eval 'list_to_integer(os:getpid()).' 1> /dev/null
}

something_is_using_the_rabbit_store() {
  lsof /var/vcap/store/rabbitmq 1> /dev/null
}

erlang_pid_file_exists() {
  [ -f "$ERLANG_PID_FILE" ]
}

erlang_pid_points_to_a_running_process() {
  ps "$(cat $ERLANG_PID_FILE)" 1> /dev/null
}

rabbitmq_node_is_healthy() {
  log "Check RabbitMQ node is healthy ..."
}

cluster_is_healthy() {
  log "Check RabbitMQ cluster is healthy ..."
}

main
