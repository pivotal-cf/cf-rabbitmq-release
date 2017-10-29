#!/usr/bin/env bash

set -e # bail out early if any command fails
set -o pipefail # fail if any component of any pipe fails

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
. spec/bash/test_helpers

# shellcheck disable=SC1091
. jobs/rabbitmq-server/templates/setup.bash

before_each() {
    DIR="$(mktemp -d)"
    trap "rm -rf ${DIR}" EXIT
}

T_expects_to_create_an_env_file_in_given_dir_with_config_to_rabbitmq() {
  (
    before_each

    main

    expect_file_to_exist "${DIR}/env"
    expect_to_equal "$(<$DIR/env.backup)" ""
  )
}

T_expects_to_set_cluster_partition_handling() {
  (
    before_each

    CLUSTER_PARTITION_HANDLING="autoheal"

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" " -rabbit cluster_partition_handling autoheal"

  ) || $T_fail "Cluster partition handling not used to configure RabbitMQ"
}

T_expects_to_define_log_levels() {
  (
    before_each

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" " -rabbit log_levels [{connection,info}]"

  ) || $T_fail "Log levels not set properly"
}

T_expects_to_set_disk_free_limit_threshold() {
  (
    before_each


    DISK_ALARM_THRESHOLD="{mem_relative,0.4}"
    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" " -rabbit disk_free_limit {mem_relative,0.4}"

  ) || $T_fail "Disk free limit threshold not set properly"
}

T_expects_not_to_halt_on_uprade_failure() {
  (
    before_each

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" " -rabbit halt_on_upgrade_failure false"

  ) || $T_fail "Halt on upgrade failure not set properly"
}

T_expects_subscription_ttl_to_be_set_for_mqtt() {
  (
    before_each

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" " -rabbitmq_mqtt subscription_ttl 1800000"

  ) || $T_fail "Subscription TTL not set for MQTT properly"
}

T_expects_management_http_log_dir_to_be_set() {
  (
    before_each

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" " -rabbitmq_management http_log_dir \"${HTTP_ACCESS_LOG_DIR}\""

  ) || $T_fail "Management HTTP logs not set properly"
}

T_expects_to_configure_rabbitmq_environment_variables() {
  (
    before_each

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" "RABBITMQ_MNESIA_DIR=/var/vcap/store/rabbitmq/mnesia/db"
    expect_to_contain "$env" "RABBITMQ_PLUGINS_EXPAND_DIR=/var/vcap/store/rabbitmq/mnesia/db-plugins-expand"

  ) || $T_fail "Environment variables not configured properly for RabbitMQ"
}

T_expects_to_create_a_backup_for_env_config_if_it_already_exists() {
  (
    before_each

    CONF_ENV_FILE="$(mktemp)"
    trap "rm -rf ${CONF_ENV_FILE}" EXIT
    echo "a config content" > $CONF_ENV_FILE

    expect_file_not_to_exist $DIR/env.backup
    main
    expect_file_to_exist $DIR/env.backup

    expect_to_contain  "$(<$CONF_ENV_FILE)" "$(<$DIR/env.backup)"
    expect_to_contain  "$(<$CONF_ENV_FILE)" "$(<$DIR/env)"

  ) || $T_fail "Failed to create backup for env config file"
}

T_expects_to_configure_nodename() {
  (
    before_each

    SELF_NODE="my-node-name"
    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" "NODENAME='my-node-name'"

  ) || $T_fail "Environment does not have the correct NODENAME"
}

T_expects_to_configure_boot_module_to_be_rabbit() {
  (
    before_each

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" "RABBITMQ_BOOT_MODULE=rabbit"

  ) || $T_fail "Environment does not have the correct NODENAME"
}

T_expects_to_configure_config_file_path() {
  (
    before_each

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" "CONFIG_FILE='"

  ) || $T_fail "Environment does not have the correct CONFIG_FILE"
}

T_expects_to_configure_load_definitions_if_given() {
  (
    before_each
    LOAD_DEFINITIONS="my-definitions"

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" " -rabbitmq_management load_definitions"

  ) || $T_fail "Failed to load load definitions config"
}

T_expects_to_configure_ssl_listeners() {
  (
    before_each

    SSL_KEY="ssk-key"
    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" " -rabbit tcp_listeners []"
    expect_to_contain "$env" " -rabbit ssl_listeners [5671]"
    expect_to_contain "$env" "{verify,verify_none},"
    expect_to_contain "$env" " -rabbitmq_management listener [{port,15672},{ssl,false}]"
    expect_to_contain "$env" " -rabbitmq_mqtt ssl_listeners [8883]"
    expect_to_contain "$env" " -rabbitmq_stomp ssl_listeners [61614]"

  ) || $T_fail "Failed to configure SSL listeners"
}

T_expects_to_configure_ssl_options() {
  (
    before_each

    SSL_KEY="ssk-key"
    SSL_VERIFY=true
    SSL_VERIFICATION_DEPTH="5"
    SSL_FAIL_IF_NO_PEER_CERT=true
    SSL_SUPPORTED_TLS_VERSIONS="['tlsv1.2','tlsv1.1']"

    main

    env="$(<$DIR/env)"
    expect_to_contain "$env" " -rabbit ssl_options [{cacertfile,"
    expect_to_contain "$env" "{certfile,"
    expect_to_contain "$env" "{keyfile,"
    expect_to_contain "$env" "{verify,verify_peer},"
    expect_to_contain "$env" "{depth,5},"
    expect_to_contain "$env" "{fail_if_no_peer_cert,true},"
    expect_to_contain "$env" "{versions,['tlsv1.2','tlsv1.1']}]"

  ) || $T_fail "Failed to configure SSL options"
}


T_expects_to_create_erlang_cookie_file_with_right_permissions() {
  (
    before_each

    ERLANG_COOKIE="my-awesome-cookie"
    ERLANG_COOKIE_OWNER="${USER}"

    main

    erlang_cookie_path="${DIR}/.erlang.cookie"
    expect_file_to_exist $erlang_cookie_path

    erlang_cookie="$(<$erlang_cookie_path)"
    expect_to_contain "$erlang_cookie" "my-awesome-cookie"
    # check_path "$erlang_cookie_path" "-r--------"
  )
}

pathstat() {
  local path=${1:?path to check}

  stat "$path" -c '%A %U:%G'
}

check_path() {
    local path=${1:?path to check}
    local mode=${2:?mode to match}

    expect_to_equal "$(pathstat $path)" "$mode vcap:vcap"
  }
