#!/usr/bin/env bash

expected() {
  echo -e "EXPECTED:      \033[93m$*\033[0m"
}

not_expected() {
  echo -e "NOT EXPECTED:  \033[91m$*\033[0m"
}

actual() {
  echo -e "ACTUAL:        \033[93m$*\033[0m"
}

expect_to_equal() {
  local actual expected diff_output diff_exit
  actual="$1"
  expected="$2"

  diff_output="$(diff <(echo "$actual") <(echo "$expected"))"
  diff_exit=$?

  if [[ $diff_exit != 0 ]]
  then
    echo -e "$diff_output"
    return $diff_exit
  fi
}

expect_to_contain() {
  local haystack="$1"
  local needle="$2"

  # shellcheck disable=SC2076
  if ! [[ "$haystack" =~ "$needle" ]]
  then
    actual "$haystack"
    expected "$needle"
    return 1
  fi
}

expect_to_not_contain() {
  local haystack="$1"
  local needle="$2"

  # shellcheck disable=SC2076
  if [[ "$haystack" =~ "$needle" ]]
  then
    actual "$haystack"
    not_expected "$needle"
    return 1
  fi
}

pending() {
  echo -e "\033[33m~~~ PENDING\033[0m"
}

run_after_all_tests() {
  AFTER_ALL_TESTS+=("$1")
}

_after_all_tests() {
  local command
  for command in "${AFTER_ALL_TESTS[@]}"
  do
    "$command"
  done
}

trap _after_all_tests EXIT

