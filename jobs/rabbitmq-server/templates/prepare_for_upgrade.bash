#!/usr/bin/env bash

prepare_for_upgrade () {
  __log "$STARTUP_LOG" "Preparing RabbitMQ for potential upgrade"

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

run_prepare_for_upgrade_when_first_deploy() {
  local mnesia_dir
  mnesia_dir="$1"

  if [ -d "$mnesia_dir" ]
  then
    prepare_for_upgrade
  fi
}

