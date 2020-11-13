#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin:$PATH
export LANGUAGE="en_US.UTF-8"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

RMQ_SERVER_PACKAGE=/var/vcap/packages/rabbitmq-server
RMQ_CTL=${RMQ_SERVER_PACKAGE}/bin/rabbitmqctl
PID_FILE=/var/vcap/sys/run/rabbitmq-server/pid
HOME_DIR=/var/vcap/store/rabbitmq
OPERATOR_USERNAME_FILE="${HOME_DIR}/operator_administrator.username"
BROKER_USERNAME_FILE="${HOME_DIR}/broker_administrator.username"

test -x "${RMQ_CTL}"

# shellcheck disable=SC1091
. /var/vcap/jobs/rabbitmq-server/etc/users

write_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"): $*"
}

remove_pid() {
    rm -f "${PID_FILE}"
}

delete_guest() {
    "${RMQ_CTL}" delete_user guest 2>&1 || true
}

grant_permissions_for_all_vhosts() {
    set +e
    username=$1

    VHOSTS=$(${RMQ_CTL} list_vhosts --no-table-headers | tail -n +2)
    for vhost in $VHOSTS
    do
    "${RMQ_CTL}" set_permissions -p "$vhost" "$username" ".*" ".*" ".*" 2>&1
    done
    true
    set -e
}

create_admin() {
  username_file=$1
  username=$2
  password=$3

  if [ -z "$username" ]
  then
    return
  fi

  echo "$username" > "$username_file"
  "${RMQ_CTL}" add_user "$username" "$password" 2>&1 || true
  # change_password is needed for the following edge case:
  # 1. cf-rabbitmq-release is upgraded from a version prior to v324.0.0 where there was no broker_administrator.username file, and
  # 2. RMQ_BROKER_USERNAME stays the same, and
  # 3. RMQ_BROKER_PASSWORD changes
  "${RMQ_CTL}" change_password "$username" "$password" 2>&1
  "${RMQ_CTL}" set_user_tags "$username" administrator 2>&1
  grant_permissions_for_all_vhosts "$username"
}

configure_admin() {
  username_file=$1
  username=$2
  password=$3

  if [ -s "$username_file" ]
  then
    if [[ $(cat "$username_file") == "$username" ]]
    then
      if ! "${RMQ_CTL}" authenticate_user "$username" "$password" 2>&1
      then
        # username from previous deployment is still valid, but password isn't
        "${RMQ_CTL}" change_password "$username" "$password" 2>&1
      fi
      # vhosts could have been added by updating property rabbitmq-server.load_definitions
      grant_permissions_for_all_vhosts "$username"
      return
    fi
    # username from previous deployment isn't valid anymore
    old_username=$(cat "$username_file")
    "${RMQ_CTL}" delete_user "$old_username" 2>&1
    rm "$username_file"
  fi
  create_admin "$username_file" "$username" "$password"
}

configure_users() {
  write_log "Configuring RabbitMQ users ..."
  delete_guest
  configure_admin "$OPERATOR_USERNAME_FILE" "$RMQ_OPERATOR_USERNAME" "$RMQ_OPERATOR_PASSWORD"
  configure_admin "$BROKER_USERNAME_FILE" "$RMQ_BROKER_USERNAME" "$RMQ_BROKER_PASSWORD"
}

wait_for_rabbitmq_application_to_start() {
  local retval

  write_log "Wait for RabbitMQ node startup..."

  set +e
  "${RMQ_CTL}" wait "${PID_FILE}"
  retval="$?"
  set -e
  return $retval
}

wait_for_rabbitmq_application_to_start
ret_val_wait="$?"

case "$ret_val_wait" in
  0)
    if ! /var/vcap/jobs/rabbitmq-server/bin/node-check "post-start"
    then
      write_log "RabbitMQ node is not healthy"
      echo 0 > "$PID_FILE"
      exit 1
    fi

    <% if spec.bootstrap %>
    configure_users
    <% end %>

    if ! /var/vcap/jobs/rabbitmq-server/bin/cluster-check "post-start"
    then
      write_log "RabbitMQ cluster is not healthy"
      remove_pid
      exit 1
    fi

    write_log "RabbitMQ cluster is healthy"
    ;;
  *)
    write_log "RabbitMQ application failed to start while waiting for cluster to form"
    remove_pid
    exit 1
    ;;
esac

write_log "RabbitMQ node started successfully."
