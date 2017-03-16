#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
source spec/bash/test_helpers

# Creates a new test user for each run
# We expect the container to be flushed between deployments which
# will drop the test user.
local testuser="testuser-$(date +%s)"
sudo adduser --disabled-password --no-create-home --gecos "" $testuser

check_path() {
    local path=${1:?path to check}
    local mode=${2:?mode to match}

    expect_to_equal "$(sudo stat $path -c '%A %U:%G')" "$mode $testuser:$testuser"
}

T_creates_missing_directory_and_sets_permissions() {
  local topdir=$(mktemp -d)

  local destination_dir="${topdir}/one/two"
  sudo ./spec/bash/ensure_dir_wrapper.bash "$destination_dir" "$testuser:$testuser"

  check_path "$destination_dir" "drwxr-x---"
}

T_recursively_chown_all_the_subtree_under_target_directory() {
  local topdir=$(mktemp -d)

  local destination_dir="${topdir}/one/two"
  local nested_dir="$destination_dir/three/four"
  mkdir -p "$nested_dir"
  touch "$nested_dir/a-file"
  touch "$nested_dir/an-executable-file"
  chmod ug+x "$nested_dir/an-executable-file"

  sudo ./spec/bash/ensure_dir_wrapper.bash "$destination_dir" "$testuser:$testuser"

  check_path "$destination_dir" "drwxr-x---"
  check_path "$nested_dir" "drwxrwx---"
  check_path "$nested_dir/a-file" "-rw-rw----"
  check_path "$nested_dir/an-executable-file" "-rwxrwx---"
}
