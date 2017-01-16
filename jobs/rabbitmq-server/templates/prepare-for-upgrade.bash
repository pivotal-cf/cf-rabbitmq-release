#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin:$PATH

RMQ_SERVER_PACKAGE=/var/vcap/packages/rabbitmq-server
CONTROL=${RMQ_SERVER_PACKAGE}/bin/rabbitmqctl
JOB_DIR=/var/vcap/jobs/rabbitmq-server

LOG_DIR=/var/vcap/sys/log/rabbitmq-server
STDOUT_LOG="${LOG_DIR}"/pre-start.stdout.log
STDERR_LOG="${LOG_DIR}"/pre-start.stderr.log

main() {
  run_script "${JOB_DIR}/bin/setup.sh"
  run_script "${JOB_DIR}/bin/plugins.sh"
  is_first_deploy || prepare_for_upgrade
}

run_script() {
    local script
    script=$1
    echo "Starting ${script}"
    set +e
    "${script}" \
        1>> "${STDOUT_LOG}" \
        2>> "${STDERR_LOG}"
    RETVAL=$?
    set -e
    case "${RETVAL}" in
        0)
            echo "Finished ${script}"
            return 0
            ;;
        *)
            echo "Errored ${script}"
            RETVAL=1
            exit "${RETVAL}"
            ;;
    esac
}

is_first_deploy() {
  ! [ -e /var/vcap/store/rabbitmq/mnesia ]
}

prepare_for_upgrade () {
  echo "Preparing RabbitMQ for potential upgrade"
  local remote_nodes local_node
  remote_nodes=($(cat /var/vcap/data/upgrade_preparation_nodes))
  # shellcheck disable=SC1091
  local_node=$(. /var/vcap/store/rabbitmq/etc/rabbitmq/rabbitmq-env.conf; echo "$NODENAME")

  for remote_node in "${remote_nodes[@]}"; do
    # since the current node is already down,
    # the rabbitmq-upgrade-preparation will timeout
    # skip over the current node
    [ "$remote_node" != "$local_node" ] || continue
    /var/vcap/packages/rabbitmq-upgrade-preparation/bin/rabbitmq-upgrade-preparation \
      -rabbitmqctl-path "${CONTROL}" \
      -node "$remote_node" \
      -new-rabbitmq-version "$(cat "${RMQ_SERVER_PACKAGE}"/rmq_version)" \
      -new-erlang-version "$(cat "${RMQ_SERVER_PACKAGE}"/erlang_version)" \
      1> >(tee -a "${LOG_DIR}"/upgrade.log) 2>&1
  done
}

main
