#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

fail() {
  echo $1
  exit 1
}

test_directories_are_not_world_readable() {
  echo "Checking directory permissions"
  directory_breaking_the_rules=$(find -L "/var/vcap/jobs/smoke-tests" -maxdepth 0 -perm /o+rwx -type d)
  [[ -z "${directory_breaking_the_rules}" ]] ||
  fail "the following directory is world readable: /var/vcap/jobs/smoke-tests"

  echo "Checking directory ownership"
  directory_owned_by_vcap=$(find -L "/var/vcap/jobs/smoke-tests" -maxdepth 0 -group vcap -user vcap -type d)
  [[ -n "${directory_owned_by_vcap}" ]] ||
  fail "the following directory is not owned by vcap:vcap: /var/vcap/jobs/smoke-tests"
}

test_directories_are_not_world_readable
