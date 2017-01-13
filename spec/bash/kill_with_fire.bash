#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
. spec/bash/test_helpers

# Given a process is running
start_a_process_running() {
  local running_pid
  (spec/assets/unkillable-script.bash) &
  RUNNING_PID="$!"
  PID_FILE=$(mktemp -t basht_kill_with_fire)
  echo "$RUNNING_PID" > "$PID_FILE"
}

# When I call my script with the process PID
run_the_kill_script() {
  jobs/rabbitmq-server/templates/kill-with-fire.bash "$@"
}

# I expect the process to be stopped
check_if_process_does_not_exist() {
  local pid
  pid="${1:?first argument must a PID}"
  kill -s 0 "$pid" 2> /dev/null
  if [[ $? != 0 ]]; then
    return 0
  else
    return 1
  fi
}

T_should_kill_a_pid() {
  (
    start_a_process_running

    run_the_kill_script "$PID_FILE"

    check_if_process_does_not_exist "$RUNNING_PID"
  ) || $T_fail "Process still existed after running the kill script"
}

T_should_exit_non_zero_if_not_provided_a_pid() {
  (
    run_the_kill_script || return 0
  ) || $T_fail "Exited zero when not provided a PID"
}

T_should_warn_the_user_if_not_provided_a_pid() {
  (
    output=$(run_the_kill_script 2>&1)
    expect_to_contain "$output" "must be a running PID"
  ) || $T_fail "Did not provide the correct output when no PID is provided"
}

T_should_do_nothing_when_the_pid_does_not_exist() {
  (
    PID_FILE=$(mktemp -t basht_kill_with_fire_invalid_pid)
    echo "non-existing-pid" > "$PID_FILE"
    run_the_kill_script "$PID_FILE"
  ) || $T_fail "Should exit 0 when the given PID does not exist"
}

T_should_remove_pid_file() {
  (
    start_a_process_running

    run_the_kill_script "$PID_FILE"

    [[ ! -e "$PID_FILE" ]]
  ) || $T_fail "PID_FILE should be deleted after the process is killed"

}
