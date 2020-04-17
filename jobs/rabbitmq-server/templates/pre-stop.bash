#!/bin/bash

set -eo pipefail
[ -z "$DEBUG" ] || set -x

export PATH=/var/vcap/packages/erlang/bin:/var/vcap/packages/rabbitmq-server/bin:$PATH

TOTAL_WAIT_TIME_SECS=${TOTAL_WAIT_TIME_SECS:-3600}

# increase the wait time by 1 second between every request resulting in TOTAL_WAIT_TIME_SECS, i.e.
# 1+2+3+...+number_of_requests=TOTAL_WAIT_TIME_SECS
number_of_requests=$(awk -v S="$TOTAL_WAIT_TIME_SECS" 'BEGIN{
  printf("%.0f", ((-1 + sqrt(1+S*8)) / 2));
  }')

wait_for_queues_to_sync() {
  queue_type="$1"
  diagnostics_command="$2"
  write_log "Checking if node is $queue_type queue critical"

  next_wait_time_secs=1
  until [ $next_wait_time_secs -gt "$number_of_requests" ] || bash -c "rabbitmq-diagnostics $diagnostics_command"; do
    write_log "Waiting for $queue_type queue critical node to sync"
    sleep $(( next_wait_time_secs++ ))
  done
  if [[ $next_wait_time_secs -gt "$number_of_requests" ]]; then
    write_log "Timed out waiting for $queue_type queue critical node to sync after more than 1 hour"
    exit 1
  fi
}

write_log() {
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"): $*"
}

write_log "Running pre-stop script"

if [[ "${BOSH_DEPLOYMENT_NEXT_STATE}" == "delete" ]]; then
  write_log "Not waiting for queues to sync since this deployment is going to be deleted"
  exit 0
fi

wait_for_queues_to_sync 'quorum' 'check_if_node_is_quorum_critical'
wait_for_queues_to_sync 'mirror' 'check_if_node_is_mirror_sync_critical'
