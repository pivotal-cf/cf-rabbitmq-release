#!/bin/bash -e

PID_FILE="${1:?First argument must be a running PID}"
RUNNING_PID=$(cat "$PID_FILE")

if kill -0 "$RUNNING_PID"; then
  kill -9 "$RUNNING_PID"
  rm "$PID_FILE"
else
  (>&2 echo "PID was not running anyway, continuing.")
  exit 0
fi
