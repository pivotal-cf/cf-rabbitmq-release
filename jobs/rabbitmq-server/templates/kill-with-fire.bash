#!/bin/bash -e

SHUTDOWN_LOG="${LOG_DIR:-/var/vcap/sys/log/rabbitmq-server}/shutdown_stdout.log"

PID_FILE="${1}"
if [ -z "$PID_FILE" ]; then
  echo "First argument must be a valid PID file" >> "${SHUTDOWN_LOG}"
  exit 1
fi

if ! RUNNING_PID=$(cat "$PID_FILE") ; then
  echo "PID file did not exist, continuing." >> "${SHUTDOWN_LOG}"
  exit 0
fi

if kill -0 "$RUNNING_PID"; then
  echo "We found a rabbitmq-server process during monit stop and we had to kill it" >> "$SHUTDOWN_LOG"
  kill -9 "$RUNNING_PID"
  rm "$PID_FILE"
else
  (>&2 echo "PID was not running anyway, continuing.")
  exit 0
fi
