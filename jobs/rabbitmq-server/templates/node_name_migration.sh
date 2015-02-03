#!/bin/sh
#
# node name migration variables
export PATH=$PATH:/var/vcap/packages/erlang/bin
export PATH=$PATH:/var/vcap/packages/rabbitmq-server/bin
export PATH=$PATH:/var/vcap/packages/rabbitmq-cluster-migration-tool/bin
MIGRATION_DIR=/tmp/node_name_migration
MIGRATION_TOOL=/var/vcap/packages/rabbitmq-cluster-migration-tool/bin/rabbitmq-cluster-migration-tool
