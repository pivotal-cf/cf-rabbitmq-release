#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
. spec/bash/test_helpers

# shellcheck disable=SC1091
. jobs/rabbitmq-server/templates/prepare-for-upgrade.bash

T_when_mnesia_dir_not_provided_it_fails() {
  expect_to_contain "$(run_prepare_for_upgrade_when_first_deploy 2>&1)" "mnesia_dir must be provided as first argument" ||
    ( $T_fail && return 1 )
}

T_when_rmq_server_package_dir_not_provided_it_fails() {
  local mnesia_dir="$(mktemp -d)"

  expect_to_contain "$(run_prepare_for_upgrade_when_first_deploy "$mnesia_dir" 2>&1)" "rmq_server_dir must be provided as second argument" ||
    ( $T_fail && return 1 )
}

T_when_erlang_package_dir_not_provided_it_fails() {
  local mnesia_dir="$(mktemp -d)"
  local rmq_server_dir="$(mktemp -d)"

  expect_to_contain "$(run_prepare_for_upgrade_when_first_deploy "$mnesia_dir" "$rmq_server_dir" 2>&1)" "erlang_dir must be provided as third argument" ||
    ( $T_fail && return 1 )
}

T_when_mnesia_dir_exists_it_runs_prepare_for_upgrade() {
  (
    _prepare_for_upgrade() {
      echo "running prepare for upgrade..."
    }
    mnesia_dir="$PWD"
    rmq_server_dir="$(mktemp -d)"
    erlang_dir="$(mktemp -d)"

    [ "$(run_prepare_for_upgrade_when_first_deploy "$mnesia_dir" "$rmq_server_dir" "$erlang_dir")" = "running prepare for upgrade..." ]
    ) || ( $T_fail "prepare_for_upgrade did not run" && return 1 )
}

T_when_mnesia_dir_does_not_exist_it_does_not_run_prepare_for_upgrade() {
  (
    _prepare_for_upgrade() {
      echo "running prepare for upgrade..."
    }
    mnesia_dir="/i_do_not_exist"
    rmq_server_dir="$(mktemp -d)"
    erlang_dir="$(mktemp -d)"

    [ "$(run_prepare_for_upgrade_when_first_deploy "$mnesia_dir" "$rmq_server_dir" "$erlang_dir")" != "running prepare for upgrade..." ]
    ) || ( $T_fail "prepare_for_upgrade ran" && return 1 )
}

T_when_skipping_prepare_for_upgrade_not_defined_it_runs_prepare_for_upgrade() {
  (
    _run_rabbitmq_upgrade_preparation_on_every_node () {
     echo "running prepare for upgrade..."
   }

   [ "$(_prepare_for_upgrade)" = "running prepare for upgrade..." ]
   ) || ( $T_fail "run_rabbitmq_upgrade_preparation_on_every_node did not run" && return 1 )

}

T_when_skipping_prepare_for_upgrade_is_defined_it_skips_prepare_for_upgrade() {
  (
    _run_rabbitmq_upgrade_preparation_on_every_node () {
      echo "running prepare for upgrade..."
    }

    export SKIP_PREPARE_FOR_UPGRADE=1

    [ "$(_prepare_for_upgrade)" != "running prepare for upgrade..." ]
    ) || ( $T_fail "run_rabbitmq_upgrade_preparation_on_every_node ran" && return 1 )
}

T_when_rmq_server_package_path_does_not_exist_should_log_error_message() {
  (
    UPGRADE_PREPARATION_BINARY="echo"
    LOG_DIR="$(mktemp -d)"
    local rmq_server_path="/path/does/not/exist"

    run_rabbitmq_upgrade_preparation_shutdown_cluster_if_cookie_changed "new cookie" "old cookie path" "node list" "$rmq_server_path" 2>&1

    expect_file_to_contain "$LOG_DIR/upgrade.log" "$rmq_server_path is not a valid directory" ||
      ( $T_fail && return 1 )
  )
}

T_when_rmq_server_package_path_exists_should_call_the_upgrade_preparation_binary() {
  (
    UPGRADE_PREPARATION_BINARY="echo"
    LOG_DIR="$(mktemp -d)"
    local rmq_server_path="$(mktemp -d)"

    arguments_passed=$(run_rabbitmq_upgrade_preparation_shutdown_cluster_if_cookie_changed "new-cookie" "old-cookie-path" "node-list" "$rmq_server_path")

    expect_to_contain "$arguments_passed" "-rabbitmqctl-path $rmq_server_path/bin/rabbitmqctl shutdown-cluster-if-cookie-changed -new-cookie new-cookie -old-cookie-path old-cookie-path -nodes node-list" ||
      ( $T_fail && return 1 )
  )
}

