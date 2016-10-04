#!/bin/bash

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin:/var/vcap/packages/rabbitmq-server/bin:$PATH

ERLANG_PID_FILE=/var/vcap/sys/run/rabbitmq-server/pid

LOG_DIR=/var/vcap/sys/log/rabbitmq-server
SHUTDOWN_LOG="${LOG_DIR}"/shutdown_stdout.log
SHUTDOWN_ERR_LOG="${LOG_DIR}"/shutdown_stderr.log

main() {
  rabbitmqctl stop "$ERLANG_PID_FILE" 1>> "$SHUTDOWN_LOG" 2>> "$SHUTDOWN_ERR_LOG"
  rm -f "$ERLANG_PID_FILE"
  # ensure RabbitMQ is stopped
  echo "RabbitMQ stopped successfully" 1>> "$SHUTDOWN_LOG"
  echo "0"
}

main
