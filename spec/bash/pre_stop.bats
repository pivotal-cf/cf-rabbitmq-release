#!/usr/bin/env bats

@test "when deployment is going to be deleted, it skips the check_if_node_is_xxx_critical checks" {
 export BOSH_DEPLOYMENT_NEXT_STATE=delete
 run jobs/rabbitmq-server/templates/pre-stop.bash

 [ "$status" -eq 0 ]
 [[ "${lines[0]}" == *"Running pre-stop script" ]]
 [[ "${lines[1]}" == *"Not waiting for queues to sync since this deployment is going to be deleted" ]]
}

@test "when waiting for queues to be synced times out, it returns exit code 1" {
 bash() {
  return 2
 }
 export -f bash

 TOTAL_WAIT_TIME_SECS=3 run jobs/rabbitmq-server/templates/pre-stop.bash

 [ "$status" -eq 1 ]
 [[ "${lines[0]}" == *"Running pre-stop script" ]]
 [[ "${lines[1]}" == *"Checking if node is quorum queue critical" ]]
 [[ "${lines[2]}" == *"Waiting for quorum queue critical node to sync" ]]
 [[ "${lines[3]}" == *"Waiting for quorum queue critical node to sync" ]]
 [[ "${lines[4]}" == *"Timed out waiting for quorum queue critical node to sync after 3 seconds" ]]
}

@test "it calls the rabbitmq-diagnostics" {
 bash() {
   if [[ "$1" == "-c" ]];then
     if [[ "$2" == "rabbitmq-diagnostics check_if_node_is_quorum_critical" ]];then
       echo "check_if_node_is_quorum_critical called"
     fi
     if [[ "$2" == "rabbitmq-diagnostics check_if_node_is_mirror_sync_critical" ]];then
       echo "check_if_node_is_mirror_sync_critical called"
     fi
   fi
 }
 export -f bash

 run jobs/rabbitmq-server/templates/pre-stop.bash

 [ "$status" -eq 0 ]
 [[ "${lines[0]}" == *"Running pre-stop script" ]]
 [[ "${lines[1]}" == *"Checking if node is quorum queue critical" ]]
 [[ "${lines[2]}" == "check_if_node_is_quorum_critical called" ]]
 [[ "${lines[3]}" == *"Checking if node is mirror queue critical" ]]
 [[ "${lines[4]}" == "check_if_node_is_mirror_sync_critical called" ]]
}
