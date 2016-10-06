#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

# shellcheck disable=SC1091
. /var/vcap/jobs/rabbitmq-server/etc/users

export PATH=/var/vcap/packages/erlang/bin/:/var/vcap/packages/rabbitmq-server/privbin/:$PATH
LOG_DIR=/var/vcap/sys/log/rabbitmq-server

RMQ_USERS=($(rabbitmqctl list_users | tail -n +2))
RMQ_VHOSTS=($(rabbitmqctl list_vhosts | tail -n +2))

main() {
  rabbitmq_application_is_running
  rmq_user_does_not_exist "guest"

  rmq_user_exists "$RMQ_BROKER_USERNAME"
  rmq_user_is_admin "$RMQ_BROKER_USERNAME"
  rmq_user_can_authenticate "$RMQ_BROKER_USERNAME" "$RMQ_BROKER_PASSWORD"
  rmq_user_has_correct_permissions_on_all_vhosts "$RMQ_BROKER_USERNAME"

  if operator_user_configured
  then
    rmq_user_exists "$RMQ_OPERATOR_USERNAME"
    rmq_user_is_admin "$RMQ_OPERATOR_USERNAME"
    rmq_user_can_authenticate "$RMQ_OPERATOR_USERNAME" "$RMQ_OPERATOR_PASSWORD"
    # Known bug causes the administrator not to has correct credentials
    # For reference read story #121737885
    # rmq_user_has_correct_permissions_on_all_vhosts "$RMQ_OPERATOR_USERNAME"
  fi
}

# rabbitmq_application_is_running checks the health of the node to determine
# whether the application is running. We assume if the application is not
# running that the cluster is not healthy.
rabbitmq_application_is_running() {
  rabbitmqctl node_health_check ||
  fail "RabbitMQ application is not running"
}

rmq_user_does_not_exist() {
  local rmq_user
  rmq_user="$1"

  [[ ! "${RMQ_USERS[*]}" =~ $rmq_user ]] ||
  fail "User '$rmq_user' exists"
}

rmq_user_exists() {
  local rmq_user
  rmq_user="$1"

  [[ "${RMQ_USERS[*]}" =~ $rmq_user ]] ||
  fail "User '$rmq_user' does not exist"
}

rmq_user_is_admin() {
  local rmq_user
  rmq_user="$1"

  [[ "${RMQ_USERS[*]}" =~ ${rmq_user}.*administrator ]] ||
  fail "User '$rmq_user' is not an administrator"
}

rmq_user_can_authenticate() {
  local rmq_user rmq_user_pass
  rmq_user="$1"
  rmq_user_pass="$2"

  rabbitmqctl authenticate_user "$rmq_user" "$rmq_user_pass" ||
  fail "User '$rmq_user' cannot authenticate"
}

rmq_user_has_correct_permissions_on_all_vhosts() {
  local rmq_user rmq_user_permissions
  rmq_user="$1"
  rmq_user_permissions="$(rabbitmqctl list_user_permissions "$rmq_user")"

  for vhost in "${RMQ_VHOSTS[@]}"
  do
    echo "$rmq_user_permissions" | egrep "$vhost\s+\.\*\s+\.\*\s+\.\*" ||
    fail "User '$rmq_user' does not have the correct permissions for vhost '$vhost'"
  done
}

operator_user_configured() {
  [[ -n "$RMQ_OPERATOR_USERNAME" ]]
}

fail() {
  echo "$*"
  exit 1
}

send_all_output_to_logfile() {
  exec 1> >(tee -a "${LOG_DIR}/cluster-check.log")
  exec 2> >(tee -a "${LOG_DIR}/cluster-check.log")
}

send_all_output_to_logfile
SCRIPT_CALLER="${1:-cluster-check}"
echo "Running cluster checks at $(date) from $SCRIPT_CALLER..."
main
echo "Cluster check running from $SCRIPT_CALLER passed"
