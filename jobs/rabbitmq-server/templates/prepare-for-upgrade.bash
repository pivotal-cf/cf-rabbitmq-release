#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin:$PATH

RMQ_SERVER_PACKAGE=/var/vcap/packages/rabbitmq-server
CONTROL=${RMQ_SERVER_PACKAGE}/bin/rabbitmqctl

LOG_DIR=/var/vcap/sys/log/rabbitmq-server

run_rabbitmq_upgrade_preparation_on_every_node() {
  echo "$STARTUP_LOG" "Preparing RabbitMQ for potential upgrade"

  local remote_nodes remote_node new_rabbitmq_version new_erlang_version
  remote_nodes=($(cat /var/vcap/data/upgrade_preparation_nodes))
  new_rabbitmq_version="$(cat "${RMQ_SERVER_PACKAGE}/rmq_version")"
  new_erlang_version="$(cat "${RMQ_SERVER_PACKAGE}/erlang_version")"

  for remote_node in "${remote_nodes[@]}" ; do
    /var/vcap/packages/rabbitmq-upgrade-preparation/bin/rabbitmq-upgrade-preparation \
      -rabbitmqctl-path "$CONTROL" \
      -node "$remote_node" \
      -new-rabbitmq-version "$new_rabbitmq_version" \
      -new-erlang-version "$new_erlang_version" \
      1> >(tee -a "${LOG_DIR}/upgrade.log") 2>&1
  done
}

prepare_for_upgrade () {
  if [ -z "$SKIP_PREPARE_FOR_UPGRADE" ]
  then
    run_rabbitmq_upgrade_preparation_on_every_node
  fi
}

run_prepare_for_upgrade_when_first_deploy() {
  local mnesia_dir
  mnesia_dir="${1:?mnesia_dir must be provided as first argument}"

  if [ -d "$mnesia_dir" ]
  then
    prepare_for_upgrade
  fi
}

