#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
. jobs/rabbitmq-server/templates/prepare_for_upgrade.bash

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
