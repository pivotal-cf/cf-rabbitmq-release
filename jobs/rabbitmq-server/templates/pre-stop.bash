#!/bin/bash

set -eo pipefail
[ -z "$DEBUG" ] || set -x

WAIT_TIME_MAX="${WAIT_TIME_MAX:-86}"

export PATH=/var/vcap/packages/erlang/bin:/var/vcap/packages/rabbitmq-server/bin:$PATH

write_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"): $*"
}

write_log "Running pre-stop script"

if [[ "${BOSH_DEPLOYMENT_NEXT_STATE}" == "delete" ]] ; then
  write_log "Not waiting for queues to sync since this deployment is going to be deleted"
  exit 0
fi

wait_for_queues_to_sync() {
  queue_type="$1"
  diagnostics_command="$2"
  write_log "Checking if node is $queue_type queue critical"

  NEXT_WAIT_TIME=1
  until [ $NEXT_WAIT_TIME -eq $WAIT_TIME_MAX ] || bash -c "rabbitmq-diagnostics $diagnostics_command"; do
    write_log "Waiting for $queue_type queue critical node to sync"
    sleep $(( NEXT_WAIT_TIME++ ))
  done
  if [[ $NEXT_WAIT_TIME -ge $WAIT_TIME_MAX ]];then
    write_log "Timed out waiting for $queue_type queue critical node to sync after more than 1 hour"
    exit 1
  fi
}

wait_for_queues_to_sync 'quorum' 'check_if_node_is_quorum_critical'
wait_for_queues_to_sync 'mirror' 'check_if_node_is_mirror_sync_critical'
