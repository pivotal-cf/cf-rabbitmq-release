#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

export LOG_DIR=$(mktemp -d)
SHUTDOWN_LOG="${LOG_DIR}/shutdown_stdout.log"

# shellcheck disable=SC1091
. spec/bash/test_helpers

# Given a process is running
start_a_process_running() {
  local running_pid
  (spec/assets/unkillable-script.bash) &
  RUNNING_PID="$!"
  PID_FILE=$(mktemp)
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

T_should_exit_non_zero_if_not_provided_a_pid_file() {
  (
    if run_the_kill_script ; then
      return 1
    else
      return 0
    fi
  ) || $T_fail "Exited zero when not provided a PID"
}

T_should_log_if_not_provided_a_pid_file() {
  (
    run_the_kill_script

    grep "must be a valid PID file" "$SHUTDOWN_LOG"
  ) || $T_fail "Did not provide the correct output when no PID is provided"
}

T_should_warn_the_user_if_provided_a_non_existent_pid_file() {
  (
    run_the_kill_script /path/does/not/exist
    grep "PID file did not exist, continuing." "$SHUTDOWN_LOG"
  ) || $T_fail "Did not output that it's continuing after PID file was not found"
}

T_should_exit_zero_if_provided_a_non_existent_pid_file() {
  (
    run_the_kill_script /path/does/not/exist
  ) || $T_fail "Exited non zero when provided a non existent PID file"
}


T_should_do_nothing_when_the_pid_does_not_exist() {
  (
    PID_FILE=$(mktemp)
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

T_should_log_a_message_if_a_process_existed() {
  (
    start_a_process_running

    run_the_kill_script "$PID_FILE"

    grep "We found a rabbitmq-server process during monit stop and we had to kill it" "$SHUTDOWN_LOG"
  ) || $T_fail "Should log message when a process is killed"
}
