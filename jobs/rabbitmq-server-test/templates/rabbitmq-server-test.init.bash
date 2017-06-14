#!/usr/bin/env bash

set -e

RUN_DIR=/var/vcap/sys/run/rabbitmq-server-test
LOG_DIR=/var/vcap/sys/log/rabbitmq-server-test
PIDFILE=${RUN_DIR}/pid
export JOB_DIR=/var/vcap/jobs/rabbitmq-server-test

case $1 in

  start)
    mkdir -p $RUN_DIR $LOG_DIR
    chown -R vcap:vcap $RUN_DIR $LOG_DIR

    echo $$ > $PIDFILE

    exec $JOB_DIR/bin/run-basht-tests

    ;;

  stop)
    kill -9 "$(cat $PIDFILE)"
    rm -f $PIDFILE

    ;;

  *)
    echo "Usage: $0 {start|stop}" ;;

  esac
