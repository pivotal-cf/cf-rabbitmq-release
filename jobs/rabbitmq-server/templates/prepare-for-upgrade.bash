#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin:$PATH

UPGRADE_PREPARATION_BINARY="/var/vcap/packages/rabbitmq-upgrade-preparation/bin/rabbitmq-upgrade-preparation"
LOG_DIR="/var/vcap/sys/log/rabbitmq-server"

write_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"): $*"
}

_run_rabbitmq_upgrade_preparation_on_every_node() {
  write_log "$STARTUP_LOG" "Preparing RabbitMQ for potential upgrade"

  local remote_nodes remote_node new_rabbitmq_version new_erlang_version rmq_server_package
  rmq_server_package="$1"
  erlang_package="$1"
  remote_nodes=($(cat /var/vcap/data/upgrade_preparation_nodes))
  new_rabbitmq_version="$(cat "$rmq_server_package/rmq_version")"
  new_erlang_version="$(cat "$erlang_package/erlang_version")"

  for remote_node in "${remote_nodes[@]}" ; do
    "$UPGRADE_PREPARATION_BINARY" \
      -rabbitmqctl-path "$rmq_server_package/bin/rabbitmqctl" \
      -node "$remote_node" \
      -new-rabbitmq-version "$new_rabbitmq_version" \
      -new-erlang-version "$new_erlang_version" \
      1> >(tee -a "$LOG_DIR/upgrade.log") 2>&1
  done
}

_prepare_for_upgrade () {
  if [ -z "$SKIP_PREPARE_FOR_UPGRADE" ]
  then
    _run_rabbitmq_upgrade_preparation_on_every_node "$1" "$2"
  fi
}

run_rabbitmq_upgrade_preparation_shutdown_cluster_if_cookie_changed () {
    local rmq_server_package="$4"

    if [[ ! -d $rmq_server_package ]]; then
      write_log "$rmq_server_package is not a valid directory" 1> >(tee -a "$LOG_DIR/upgrade.log") 2>&1
    fi

    "$UPGRADE_PREPARATION_BINARY" \
      -rabbitmqctl-path "$rmq_server_package/bin/rabbitmqctl" \
      shutdown-cluster-if-cookie-changed \
      -new-cookie "$1" \
      -old-cookie-path "$2" \
      -nodes "$3" \
      1> >(tee -a "$LOG_DIR/upgrade.log") 2>&1
}

run_prepare_for_upgrade_when_first_deploy() {
  local mnesia_dir="${1:?mnesia_dir must be provided as first argument}"
  local rmq_server_dir="${2:?rmq_server_dir must be provided as second argument}"
  local erlang_dir="${3:?erlang_dir must be provided as third argument}"

  if [ -d "$mnesia_dir" ] && [ -d "$rmq_server_dir" ] && [ -d "$erlang_dir" ]
  then
    _prepare_for_upgrade "$rmq_server_dir" "$erlang_dir"
  fi
}

