#!/bin/bash -e

status=$(cat <<'EOF'
Status of node rabbit@21b6557b73f343201277dbf290ae8b79 ...
Error: unable to connect to node rabbit@21b6557b73f343201277dbf290ae8b79: nodedown

DIAGNOSTICS
===========

attempted to contact: [rabbit@21b6557b73f343201277dbf290ae8b79]

rabbit@21b6557b73f343201277dbf290ae8b79:
  * connected to epmd (port 4369) on 21b6557b73f343201277dbf290ae8b79
  * epmd reports: node 'rabbit' not running at all
                  no other nodes on 21b6557b73f343201277dbf290ae8b79
  * suggestion: start the node

current node details:
- node name: 'rabbitmqctl-15906@localhost'
- home dir: /var/vcap/store/rabbitmq
- cookie hash: nonsense==
EOF)

case $1 in

  status)
    echo "$status" >&2
    echo "status $2 $3" >> $TEST_OUTPUT_FILE
    exit 2
    ;;

  shutdown)
    echo "$status" >&2
    echo "status $2 $3" >> $TEST_OUTPUT_FILE
    exit 69
    ;;

  *)
    exit 3
    ;;

esac
