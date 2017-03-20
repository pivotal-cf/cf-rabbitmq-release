#!/usr/bin/env bash
# wrap ensure_dir_with_permissions in a script so we can sudo it in the tests

source src/rabbitmq-common/ensure_dir_with_permissions

ensure_dir_with_permissions "$@"
