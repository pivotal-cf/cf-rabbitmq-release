#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
. spec/bash/test_helpers

# shellcheck disable=SC1091
. jobs/rabbitmq-server/templates/prepare-for-upgrade.bash

T_when_mnesia_dir_not_provided_it_fails() {
  expect_to_contain "$(run_prepare_for_upgrade_when_first_deploy 2>&1)" "mnesia_dir must be provided as first argument" ||
  $T_fail
}

T_when_mnesia_dir_exists_it_runs_prepare_for_upgrade() {
  (
    prepare_for_upgrade() {
      echo "running prepare for upgrade..."
    }
    mnesia_dir="$PWD"

    [ "$(run_prepare_for_upgrade_when_first_deploy "$mnesia_dir")" = "running prepare for upgrade..." ]
  ) || $T_fail "prepare_for_upgrade did not run"
}

T_when_mnesia_dir_does_not_exist_it_does_not_run_prepare_for_upgrade() {
  (
    prepare_for_upgrade() {
      echo "running prepare for upgrade..."
    }
    mnesia_dir="/i_do_not_exist"

    [ "$(run_prepare_for_upgrade_when_first_deploy "$mnesia_dir")" != "running prepare for upgrade..." ]
  ) || $T_fail "prepare_for_upgrade ran"
}

T_when_skipping_prepare_for_upgrade_not_defined_it_runs_prepare_for_upgrade() {
  (
    run_rabbitmq_upgrade_preparation_on_every_node () {
     echo "running prepare for upgrade..."
   }

   [ "$(prepare_for_upgrade)" = "running prepare for upgrade..." ]
  ) || $T_fail "run_rabbitmq_upgrade_preparation_on_every_node did not run"

}

T_when_skipping_prepare_for_upgrade_is_defined_it_skips_prepare_for_upgrade() {
  (
    run_rabbitmq_upgrade_preparation_on_every_node () {
      echo "running prepare for upgrade..."
    }

    export SKIP_PREPARE_FOR_UPGRADE=1

    [ "$(prepare_for_upgrade)" != "running prepare for upgrade..." ]
  ) || $T_fail "run_rabbitmq_upgrade_preparation_on_every_node ran"
}
