#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin/:/var/vcap/packages/rabbitmq-server/privbin/:$PATH
LOG_DIR=/var/vcap/sys/log/rabbitmq-server

main() {
  pid_file_contains_rabbitmq_erlang_vm_pid
  clusterer_app_is_running
}

pid_file_contains_rabbitmq_erlang_vm_pid() {
  local tracked_pid rabbitmq_erlang_vm_pid
  tracked_pid="$(cat /var/vcap/sys/run/rabbitmq-server/pid)"
  rabbitmq_erlang_vm_pid="$(rabbitmqctl eval 'list_to_integer(os:getpid()).')"

  [[ "$tracked_pid" = "$rabbitmq_erlang_vm_pid" ]] ||
  fail "Expected PID file to contain '$rabbitmq_erlang_vm_pid' but it contained '$tracked_pid'"
}

clusterer_app_is_running() {
  local clusterer_app_info
  clusterer_app_info="$(rabbitmqctl environment | grep -A 1 "{rabbitmq_clusterer")"

  [[ "$clusterer_app_info" == *'{config,"/var/vcap/store/rabbitmq/etc/rabbitmq/cluster.config"}'* ]] ||
  fail "RabbitMQ Clusterer app not running with correct configuration"
}

fail() {
  echo "$*"
  exit 1
}

send_all_output_to_logfile() {
  exec 1> >(tee -a "${LOG_DIR}/node-check.log")
  exec 2> >(tee -a "${LOG_DIR}/node-check.log")
}

send_all_output_to_logfile
SCRIPT_CALLER="${1:-node-check}"
echo "Running node checks at $(date) from $SCRIPT_CALLER..."
main
echo "Node checks running from $SCRIPT_CALLER passed"
