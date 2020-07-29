#!/usr/bin/env bats

@test "when deployment is going to be deleted, it skips the rabbitmq-upgrade await_online_* commands" {
 BOSH_DEPLOYMENT_NEXT_STATE=delete run jobs/rabbitmq-server/templates/pre-stop.bash.erb

 [ "$status" -eq 0 ]
 [[ "${lines[0]}" == *"Running pre-stop script" ]]
 [[ "${lines[1]}" == *"Not waiting for queues to sync since this deployment is going to be deleted" ]]
}

@test "when CHECK_QUEUE_SYNC is false, it skips the rabbitmq-upgrade await_online_* commands" {
 CHECK_QUEUE_SYNC=false run jobs/rabbitmq-server/templates/pre-stop.bash.erb

 [ "$status" -eq 0 ]
 [[ "${lines[0]}" == *"Running pre-stop script" ]]
 [[ "${lines[1]}" == *"Not waiting for queues to sync since CHECK_QUEUE_SYNC is false" ]]
}
