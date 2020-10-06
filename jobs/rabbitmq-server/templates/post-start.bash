#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin:$PATH
export LANGUAGE="en_US.UTF-8"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

RMQ_SERVER_PACKAGE=/var/vcap/packages/rabbitmq-server
RMQ_CTL=${RMQ_SERVER_PACKAGE}/privbin/rabbitmqctl
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
    set +e
    "${RMQ_CTL}" delete_user guest 2>&1
    set -e
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

create_operator_admin() {
  if [ -n "$RMQ_OPERATOR_USERNAME" ]
  then
    echo "$RMQ_OPERATOR_USERNAME" > $OPERATOR_USERNAME_FILE
    create_admin "$RMQ_OPERATOR_USERNAME" "$RMQ_OPERATOR_PASSWORD"
  fi
}

create_broker_admin() {
  if [ -n "$RMQ_BROKER_USERNAME" ]
  then
    echo "$RMQ_BROKER_USERNAME" > $BROKER_USERNAME_FILE
    create_admin "$RMQ_BROKER_USERNAME" "$RMQ_BROKER_PASSWORD"
  fi
}

delete_operator_admin() {
  set +e
  USERNAME=$(cat $OPERATOR_USERNAME_FILE)
  "${RMQ_CTL}" delete_user "$USERNAME" 2>&1
  set -e
  true
}

delete_broker_admin() {
  set +e
  USERNAME=$(cat $BROKER_USERNAME_FILE)
  "${RMQ_CTL}" delete_user "$USERNAME" 2>&1
  set -e
  true
}

create_admin() {
    username=$1
    password=$2

    set +e
    {
      "${RMQ_CTL}" add_user "$username" "$password"
      "${RMQ_CTL}" change_password "$username" "$password"
      "${RMQ_CTL}" set_user_tags "$username" administrator
    } 2>&1
    grant_permissions_for_all_vhosts "$username"
    set -e
}

configure_users() {
  write_log "Configuring RabbitMQ users ..."

  delete_guest
  [ -f $OPERATOR_USERNAME_FILE ] && delete_operator_admin
  create_operator_admin
  [ -f $BROKER_USERNAME_FILE ] && delete_broker_admin
  create_broker_admin
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
