#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

# shellcheck disable=SC1091
. /var/vcap/jobs/permissions-test/bin/directories-to-inspect.sh

# shellcheck disable=1091
. "/var/vcap/packages/bash-test-helpers/common.bash"

main() {
   ensure_all_inspected_directories_are_not_world_readable
}

ensure_all_inspected_directories_are_not_world_readable() {
  local directory_to_inspect

  for directory_to_inspect in "${DIRECTORIES_TO_INSPECT[@]}"
  do
    directory_breaking_the_rules=$(find -L "$directory_to_inspect" -maxdepth 0 -perm -o=r,o=x,o=w -type d)
    [[ -z "${directory_breaking_the_rules}" ]] ||
    fail "the following directory is world readable: ${directory_to_inspect}"

    directory_owned_by_vcap=$(find -L "$directory_to_inspect" -maxdepth 0 -group vcap -user vcap -type d)
    [[ -n "${directory_owned_by_vcap}" ]] ||
    fail "the following directory is not owned by vcap:vcap: ${directory_to_inspect}"
  done
}

main
