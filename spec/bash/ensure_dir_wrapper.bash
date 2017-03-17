#!/usr/bin/env bash
# wrap ensure_dir in a script so we can sudo it in the tests

source src/rabbitmq-common/ensure_dir

ensure_dir "$@"
