#!/usr/bin/env bash

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
. spec/bash/test_helpers

# shellcheck disable=SC1091
. jobs/rabbitmq-server/templates/delete_old_files.bash

in_tmp_dir() {
  local tmp_dir
  tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t management_ui_logs)" || exit
  cd "$tmp_dir" || exit
}

date_cmd() {
  if [[ $(uname) = "Darwin" ]]; then
    gdate "$@"
  else
    date "$@"
  fi
}

create_log_file() {
  local file_name hours_ago ago
  file_name="$1"
  hours_ago="$2"

  ago=$(date_cmd -d "- ${hours_ago} hours" +'%Y%m%d%H%M')

  touch -t "$ago" "$file_name"
}

T_when_log_files_older_than_7_days_it_removes_them() {
  local actual

  (
    in_tmp_dir

    create_log_file "access.log.7_days_ago" "$(( 24 * 7))"
    create_log_file "access.log.8_days_ago" "$(( 24 * 8 ))"

    delete_old_files .

    actual=$(find . -name "access.log.*")

    expect_to_equal "$actual" ""
  ) || $T_fail
}

T_when_log_files_younger_than_7_days_it_does_not_remove_them() {
  local actual expected

  (
    in_tmp_dir

    create_log_file "access.log.6_days_ago" "$(( 24 * 6 ))"
    create_log_file "access.log.18_hours_ago" "18"
    create_log_file "access.log.2_hours_ago" "2"
    expected=$(find . -name "access.log.*")

    delete_old_files .

    actual=$(find . -name "access.log.*")

    expect_to_equal "$actual" "$expected"
  ) || $T_fail
}

T_when_not_provided_a_path_it_should_error() {
  local actual expected

  actual=$(delete_old_files 2>&1)
  expected="first argument must be logs path"

  expect_to_contain "$actual" "$expected" || $T_fail
}

T_when_provided_a_broken_path_it_should_error() {
  local actual expected

  actual=$(delete_old_files /i_do_not_exist 2>&1)
  expected="logs path is not a directory"

  expect_to_contain "$actual" "$expected" || $T_fail
}
