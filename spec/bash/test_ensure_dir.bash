#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
source spec/bash/test_helpers

local testuser="testuser-$(date +%s)"
sudo adduser --disabled-password --no-create-home --gecos "" $testuser

T_creates_missing_directory_and_sets_permissions() {
  local topdir=$(mktemp -d)
  #trap "sudo rm -f -r $topdir" EXIT
  echo $topdir

  local destination_dir="${topdir}/one/two"
  sudo ./spec/bash/ensure_dir_wrapper.bash "$destination_dir" "$testuser:$testuser"

  expect_to_equal "$(stat $destination_dir -c '%A %U:%G')" "drwxr-x--- $testuser:$testuser"
}
