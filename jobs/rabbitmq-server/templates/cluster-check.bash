#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin/:/var/vcap/packages/rabbitmq-server/bin/:$PATH
LOG_DIR=/var/vcap/sys/log/rabbitmq-server

main() {
  ensure_rabbitmq_startup_complete

  # rabbitmqctl hangs if run before application
  mapfile -s1 -t RMQ_USERS  < <( rabbitmqctl list_users )
  mapfile -s1 -t RMQ_VHOSTS < <( rabbitmqctl list_vhosts --no-table-headers)

  ensure_rmq_user_does_not_exist "guest"


  if broker_admin_configured
  then
    ensure_rmq_user_exists "$RMQ_BROKER_USERNAME"
    ensure_rmq_user_is_admin "$RMQ_BROKER_USERNAME"
    ensure_rmq_user_can_authenticate "$RMQ_BROKER_USERNAME" "$RMQ_BROKER_PASSWORD"
    ensure_rmq_user_has_correct_permissions_on_all_vhosts "$RMQ_BROKER_USERNAME"
  fi

  if operator_user_configured
  then
    ensure_rmq_user_exists "$RMQ_OPERATOR_USERNAME"
    ensure_rmq_user_is_admin "$RMQ_OPERATOR_USERNAME"
    ensure_rmq_user_can_authenticate "$RMQ_OPERATOR_USERNAME" "$RMQ_OPERATOR_PASSWORD"
    # Known bug causes the administrator not to has correct credentials
    # For reference read story #121737885
    # ensure_rmq_user_has_correct_permissions_on_all_vhosts "$RMQ_OPERATOR_USERNAME"
  fi
}

write_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"): $*"
}

ensure_rabbitmq_startup_complete() {
  (
    rabbitmq-diagnostics check_port_connectivity &&
    rabbitmq-diagnostics check_virtual_hosts
  ) || fail "RabbitMQ did not complete startup"
}

get_rmq_user() {
  local misper="$1"
  local user

  for user_spec in "${RMQ_USERS[@]}"
  do
    user="$( echo "$user_spec" | awk '{ print $1 }' )"
    if [ "$user" = "$misper" ]
    then
      echo "$user_spec"
      return 0
    fi
  done
  return 1
}

ensure_rmq_user_does_not_exist() {
  local rmq_user="$1"

  if get_rmq_user "$rmq_user" >/dev/null
  then
    fail "User '$rmq_user' exists"
    return 1
  fi
}

ensure_rmq_user_exists() {
  local rmq_user="$1"

  if ! get_rmq_user "$rmq_user" >/dev/null
  then
    fail "User '$rmq_user' does not exist"
    return 1
  fi
}

ensure_rmq_user_is_admin() {
  local rmq_user user_spec
  rmq_user="$1"
  user_spec="$( get_rmq_user "$rmq_user" )"

  if ! [[ "$user_spec" =~ \[.*administrator.*\] ]]
  then
    fail "User '$rmq_user' is not an administrator"
  fi
}

ensure_rmq_user_can_authenticate() {
  local rmq_user rmq_user_pass
  rmq_user="$1"
  rmq_user_pass="$2"

  rabbitmqctl authenticate_user "$rmq_user" "$rmq_user_pass" ||
  fail "User '$rmq_user' cannot authenticate"
}

ensure_rmq_user_has_correct_permissions_on_all_vhosts() {
  local rmq_user rmq_user_permissions
  rmq_user="$1"
  rmq_user_permissions="$(rabbitmqctl list_user_permissions "$rmq_user")"

  for vhost in "${RMQ_VHOSTS[@]}"
  do
    echo "$rmq_user_permissions" | grep -E "${vhost}\s+\.\*\s+\.\*\s+\.\*" ||
    fail "User '$rmq_user' does not have the correct permissions for vhost '$vhost'"
  done
}

operator_user_configured() {
  [[ -n "$RMQ_OPERATOR_USERNAME" ]]
}

broker_admin_configured() {
  [[ -n "$RMQ_BROKER_USERNAME" ]]
}

fail() {
  echo "$*"
  exit 1
}

send_all_output_to_logfile() {
  exec 1> >(tee -a "$LOG_DIR/cluster-check.log")
  exec 2> >(tee -a "$LOG_DIR/cluster-check.log")
}

# shellcheck disable=SC2128
if [[ "$0" = "$BASH_SOURCE" ]]
then
  # only run, when called and not sourced

  # shellcheck disable=SC1091
  . /var/vcap/jobs/rabbitmq-server/etc/users

  send_all_output_to_logfile
  SCRIPT_CALLER="${1:-cluster-check}"
  write_log "Running cluster checks from $SCRIPT_CALLER..."
  main
  write_log "Cluster check running from $SCRIPT_CALLER passed"
fi
