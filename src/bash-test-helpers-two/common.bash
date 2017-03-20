#!/bin/bash

set -eu

fail() {
  echo "[FAIL] in $0" >> "/var/vcap/sys/log/cf-rabbitmq-release-test-failures.log"
  echo "$*" >> "/var/vcap/sys/log/cf-rabbitmq-release-test-failures.log"
  exit 1
}

