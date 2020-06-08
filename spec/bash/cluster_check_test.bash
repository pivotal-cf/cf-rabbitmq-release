#!/usr/bin/env bash

set -e
set -o pipefail

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
. spec/bash/test_helpers

# shellcheck disable=SC1091
. jobs/rabbitmq-server/templates/cluster-check.bash

# stub the fail() function
fail() {
  echo "$@"
  return 1
}

# shellcheck disable=SC2054,SC2102
readonly RMQ_USERS_WITHOUT_GUEST=(
'broker	[administrator]'
'mu-guest-ccbc-4b3d-9ac7-7f0ac4d05455-qlej24gg86r10jeo7fg9evrjdr	[policymaker, management]'
'mu-1405278f-a1af-4439-823e-d7b9c0371b6b-b3v5g7o0bthddk0aliu2u2a4op	[policymaker, management]'
'mu-1405278f-a1af-4439-823e-d7b9c0371b6b-b3v5g7o0bthddk0aliu2u2a4op	[policymaker, management, guest]'
)

# shellcheck disable=SC2054,SC2102
readonly RMQ_USERS_WITH_GUEST=(
'broker	[administrator]'
'guest   [something, something_elese]'
'mu-guest-ccbc-4b3d-9ac7-7f0ac4d05455-qlej24gg86r10jeo7fg9evrjdr	[policymaker, management]'
'mu-1405278f-a1af-4439-823e-d7b9c0371b6b-b3v5g7o0bthddk0aliu2u2a4op	[policymaker, management]'
'mu-1405278f-a1af-4439-823e-d7b9c0371b6b-b3v5g7o0bthddk0aliu2u2a4op	[policymaker, management, guest]'
'administrator   [no_admin]'
)

T_ensure_rmq_user_is_admin_when_user_is_unknown() {
  (
    RMQ_USERS=( "${RMQ_USERS_WITH_GUEST[@]}" )
    ensure_rmq_user_is_admin 'no_user' && return 1 || return 0
    ) || ( $T_fail 'Expected user guest to not be an admin' && return 1 )
}

T_ensure_rmq_user_is_admin_when_guest_is_not_admin() {
  (
    RMQ_USERS=( "${RMQ_USERS_WITH_GUEST[@]}" )
    ensure_rmq_user_is_admin 'guest' && return 1 || return 0
    ) || ( $T_fail 'Expected user guest to not be an admin' && return 1 )
}

T_ensure_rmq_user_is_admin_when_broker_is_admin() {
  (
    RMQ_USERS=( "${RMQ_USERS_WITH_GUEST[@]}" )
    ensure_rmq_user_is_admin 'broker'
    ) || ( $T_fail 'Expected user broker to be an admin' && return 1 )
}

T_ensure_rmq_user_does_not_exist_when_guest_user_was_removed() {
  (
    # shellcheck disable=SC2034
    RMQ_USERS=( "${RMQ_USERS_WITHOUT_GUEST[@]}" )
    ensure_rmq_user_does_not_exist 'guest'
    ) || ( $T_fail "Expected user guest to be absent in the list uof users" && return 1 )
}

T_ensure_rmq_user_does_not_exist_when_guest_user_was_not_removed() {
  (
    # shellcheck disable=SC2034
    RMQ_USERS=( "${RMQ_USERS_WITH_GUEST[@]}" )
    ensure_rmq_user_does_not_exist 'guest' && return 1 || return 0
    ) || ( $T_fail "Expected user guest in the list of users" && return 1 )
}

T_ensure_rmq_user_exists_when_user_was_not_removed() {
  (
    # shellcheck disable=SC2034
    RMQ_USERS=( "${RMQ_USERS_WITH_GUEST[@]}" )
    ensure_rmq_user_exists 'guest'
    ) || ( $T_fail 'Expected user guest to exist' && return 1 )
}

T_ensure_rmq_user_exists_when_user_was_removed() {
  (
    # shellcheck disable=SC2034
    RMQ_USERS=( "${RMQ_USERS_WITHOUT_GUEST[@]}" )
    ensure_rmq_user_exists 'guest' && return 1 || return 0
    ) || ( $T_fail 'Expected user guest to not exist' && return 1 )
}
