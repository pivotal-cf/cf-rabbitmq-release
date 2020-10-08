#!/usr/bin/env bash

set -e # bail out early if any command fails
set -o pipefail # fail if any component of any pipe fails

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
. spec/bash/test_helpers

# shellcheck disable=SC1091
. jobs/rabbitmq-server/templates/setup.bash

T_setup_environment() {
  (
    local env

    DIR="$(mktemp -d)"
    VCAP_HOME="$(mktemp -d)"
    trap "rm -rf ${DIR}" EXIT
    trap "rm -rf ${VCAP_HOME}" EXIT

    CLUSTER_PARTITION_HANDLING="autoheal"
    DISK_ALARM_THRESHOLD="{mem_relative,0.4}"
    SELF_NODE="my-node-name"
    RABBITMQ_NODES_STRING="node-1,node-2"
    CLUSTER_NAME="RMQ4TAS-CLUSTER"
    ENABLED_PLUGINS_FILE="/var/vcap/store/rabbitmq/enabled_plugins"
    USE_LONGNAME=true

    SSL_ENABLED=true
    SSL_VERIFY=false
    SSL_VERIFICATION_DEPTH="5"
    SSL_FAIL_IF_NO_PEER_CERT=true
    SSL_SUPPORTED_TLS_VERSIONS="['tlsv1.2','tlsv1.1']"
    SSL_SUPPORTED_TLS_CIPHERS=",{ciphers, ['cipher1','cipher2']}"
    SSL_ENABLED_ON_MANAGEMENT=true
    SSL_DISABLE_NON_SSL_LISTENERS=false

    ERLANG_COOKIE="my-awesome-cookie"
    VCAP_USER="$(id -u)"
    VCAP_GROUP="$(id -g)"
    advanced_config_file="/var/vcap/jobs/rabbitmq-server/etc/advanced.config"
    UPGRADE_PREPARATION_NODES_FILE="$(mktemp)"
    trap "rm -rf ${UPGRADE_PREPARATION_NODES_FILE}" EXIT

    main

    env="$(<$DIR/env)"
    expect_file_to_exist "${DIR}/env"
    expect_to_equal "$(<$DIR/env.backup)" ""

    expect_to_contain "$env" "'-rabbit cluster_nodes {[node-1,node-2],disc}"
    expect_to_contain "$env" " -rabbit cluster_partition_handling autoheal"
    expect_to_contain "$env" " -rabbit log_levels [{connection,info}]"
    expect_to_contain "$env" " -rabbit disk_free_limit {mem_relative,0.4}"
    expect_to_contain "$env" " -rabbit halt_on_upgrade_failure false"
    expect_to_contain "$env" " -rabbitmq_mqtt subscription_ttl 1800000"
    expect_to_contain "$env" " -rabbitmq_management http_log_dir \"${HTTP_ACCESS_LOG_DIR}\""
    expect_to_contain "$env" "RABBITMQ_MNESIA_DIR=/var/vcap/store/rabbitmq/mnesia/db"
    expect_to_contain "$env" "RABBITMQ_PLUGINS_EXPAND_DIR=/var/vcap/store/rabbitmq/mnesia/db-plugins-expand"
    expect_to_contain "$env" "USE_LONGNAME=true"
    expect_to_contain "$env" "ENABLED_PLUGINS_FILE=/var/vcap/store/rabbitmq/enabled_plugins"
    expect_to_contain "$env" "NODENAME='my-node-name'"
    expect_to_contain "$env" "RABBITMQ_NODENAME='my-node-name'"
    expect_to_contain "$env" "RABBITMQ_BOOT_MODULE=rabbit"
    expect_to_contain "$env" "CONFIG_FILE="
    expect_to_contain "$env" "ADVANCED_CONFIG_FILE=/var/vcap/jobs/rabbitmq-server/etc/advanced.config"
    expect_to_contain "$env" " -rabbit ssl_listeners [5671]"
    expect_to_contain "$env" " -rabbit cluster_name \"${CLUSTER_NAME}\""
    expect_to_contain "$env" "{verify,verify_none},"

    # SSL
    expect_to_contain "$env" " -rabbitmq_management listener [{port,15671},{ssl,true}"
    expect_to_contain "$env" " -rabbitmq_mqtt ssl_listeners [8883]"
    expect_to_contain "$env" " -rabbitmq_stomp ssl_listeners [61614]"
    expect_to_contain "$env" " -rabbit ssl_options [{cacertfile,"
    expect_to_contain "$env" "{certfile,"
    expect_to_contain "$env" "{keyfile,"
    expect_to_contain "$env" "{verify,verify_none},"
    expect_to_contain "$env" "{depth,5},"
    expect_to_contain "$env" "{fail_if_no_peer_cert,true},"
    expect_to_contain "$env" "{versions,['\"'\"'tlsv1.2'\"'\"','\"'\"'tlsv1.1'\"'\"']}"
    expect_to_contain "$env" "{ciphers, ['\"'\"'cipher1'\"'\"','\"'\"'cipher2'\"'\"']}"


    # ERLANG COOKIE
    erlang_cookie_path="${DIR}/.erlang.cookie"
    expect_file_to_exist $erlang_cookie_path
    erlang_cookie="$(<$erlang_cookie_path)"
    expect_to_contain "$erlang_cookie" "my-awesome-cookie"

    ) || ( $T_fail "Failed to configure environment" && return 1 )
}


T_create_cluster_args() {
  (
    local rabbitmq_nodes disk_alarm_threshold cluster_partition_handling http_access_log_dir cluster_args

    rabbitmq_nodes="node-1,node-2"
    disk_alarm_threshold="{mem_relative,0.4}"
    cluster_partition_handling="autoheal"
    http_access_log_dir="/path/to/http-access.log"
    cluster_name=""

    cluster_args="$(create_cluster_args $rabbitmq_nodes $disk_alarm_threshold $cluster_partition_handling $http_access_log_dir $cluster_name)"

    expect_to_contain "$cluster_args" "-rabbit cluster_nodes {[node-1,node-2],disc}"
    expect_to_contain "$cluster_args" " -rabbit log_levels [{connection,info}]"
    expect_to_contain "$cluster_args" " -rabbit disk_free_limit {mem_relative,0.4}"
    expect_to_contain "$cluster_args" " -rabbit cluster_partition_handling autoheal"
    expect_to_contain "$cluster_args" " -rabbit halt_on_upgrade_failure false"
    expect_to_contain "$cluster_args" " -rabbitmq_mqtt subscription_ttl 1800000"
    expect_to_contain "$cluster_args" " -rabbitmq_management http_log_dir \"/path/to/http-access.log\""
    expect_to_not_contain "$cluster_args" "-rabbit cluster_name"

    ) || ( $T_fail "Failed to create cluster args to pass to SERVER_START_ARGS" && return 1 )
}

T_do_not_configure_tls_listeners() {
  (
    local env
    DIR="$(mktemp -d)"
    trap "rm -rf ${DIR}" EXIT
    trap "rm -rf ${VCAP_HOME}" EXIT
    SSL_ENABLED=false
    SSL_ENABLED_ON_MANAGEMENT=false
    UPGRADE_PREPARATION_NODES_FILE="$(mktemp)"
    trap "rm -rf ${UPGRADE_PREPARATION_NODES_FILE}" EXIT

    main

    env="$(<$DIR/env)"
    expect_file_to_exist "${DIR}/env"
    expect_to_contain "$env" " -rabbitmq_management listener [{port,15672},{ssl,false}]"
    expect_to_not_contain "$env" " -rabbit ssl_listeners [5671]"
    expect_to_not_contain "$env" "{verify,verify_none},"
    expect_to_not_contain "$env" " -rabbitmq_mqtt ssl_listeners [8883]"
    expect_to_not_contain "$env" " -rabbitmq_stomp ssl_listeners [61614]"
    expect_to_not_contain "$env" " -rabbit ssl_options [{cacertfile,"
    expect_to_not_contain "$env" "{certfile,"
    expect_to_not_contain "$env" "{keyfile,"
    expect_to_not_contain "$env" "{verify,verify_none},"
    expect_to_not_contain "$env" "{depth,5},"
    expect_to_not_contain "$env" "{fail_if_no_peer_cert,true},"
    expect_to_not_contain "$env" "{versions,['\"'\"'tlsv1.2'\"'\"','\"'\"'tlsv1.1'\"'\"']}"
    expect_to_not_contain "$env" "{ciphers, ['\"'\"'cipher1'\"'\"','\"'\"'cipher2'\"'\"']}"
    ) || ( $T_fail "Failed to configure without TLS listeners" && return 1 )
}

T_configure_tls_listeners() {
  (
    DISABLE_NON_SSL_LISTENERS=false
    listeners="$(configure_tls_listeners "$DISABLE_NON_SSL_LISTENERS")"
    expect_to_equal "$listeners" "-rabbit ssl_listeners [5671] -rabbitmq_mqtt ssl_listeners [8883] -rabbitmq_stomp ssl_listeners [61614]"

    DISABLE_NON_SSL_LISTENERS=true
    listeners_non_tls_disabled="$(configure_tls_listeners "$DISABLE_NON_SSL_LISTENERS")"
    expect_to_equal "$listeners_non_tls_disabled" "-rabbit ssl_listeners [5671] -rabbitmq_mqtt ssl_listeners [8883] -rabbitmq_stomp ssl_listeners [61614] -rabbit tcp_listeners [] -rabbitmq_mqtt tcp_listeners [] -rabbitmq_stomp tcp_listeners []"
    ) || ( $T_fail "Failed to configure TLS listeners" && return 1 )
}

T_configure_tls_options() {
  (
    local ssl_verify ssl_verification_mode ssl_verification_depth script_dir ssl_fail_if_no_peer_cert ssl_supported_tls_versions ssl_options options

    ssl_verify="true"
    ssl_verification_depth="5"
    ssl_fail_if_no_peer_cert=true
    ssl_supported_tls_versions="['tlsv1.2','tlsv1.1']"
    script_dir="/path/to/script/dir"
    ssl_supported_tls_ciphers=",{ciphers, ['DHE_AES128_GCM_SHA256','DHE_AES256_GCM_SHA256']}"

    options="$(configure_tls_options "${ssl_verify}" "${ssl_verification_depth}" "${ssl_fail_if_no_peer_cert}" "${ssl_supported_tls_versions}" "${ssl_supported_tls_ciphers}" "${script_dir}")"
    expect_to_equal "$options" " -rabbit ssl_options [{cacertfile,\"${script_dir}/../etc/cacert.pem\"},{certfile,\"${script_dir}/../etc/cert.pem\"},{keyfile,\"${script_dir}/../etc/key.pem\"},{verify,verify_peer},{depth,$ssl_verification_depth},{fail_if_no_peer_cert,$ssl_fail_if_no_peer_cert},{versions,$ssl_supported_tls_versions}$ssl_supported_tls_ciphers]"

    ) || ( $T_fail "Failed to configure TLS options" && return 1 )
}

T_create_config_file() {
  (
    local conf_env_file self_node dir nodename config script_dir prefix suffix server_start_args plugins_file

    conf_env_file=""
    self_node="node-1"
    dir="$(mktemp -d)"
    script_dir="/path/to/script/dir"
    server_start_args="SERVER_START_ARGS='this-is-my-config'"
    plugins_file="/var/vcap/store/rabbitmq/enabled_plugins"
    config_file="/path/to/rabbitmq.conf(ig)"
    long_name=false

    trap "rm -rf ${dir}" EXIT

    create_config_file "$conf_env_file" "$self_node" "$dir" "$script_dir" "$server_start_args" "$plugins_file" "$long_name"

    expect_file_to_exist "${dir}/env"
    expect_file_to_exist "${dir}/env.backup"

    expect_to_contain "$(<$dir/env)" "CONFIG_FILE=/path/to/rabbitmq.conf(ig)"
    expect_to_contain "$(<$dir/env)" "NODENAME='node-1'"
    expect_to_contain "$(<$dir/env)" "RABBITMQ_NODENAME='node-1'"
    expect_to_contain "$(<$dir/env)" "SERVER_START_ARGS='this-is-my-config'"
    expect_to_contain "$(<$dir/env)" "RABBITMQ_MNESIA_DIR=/var/vcap/store/rabbitmq/mnesia/db"
    expect_to_contain "$(<$dir/env)" "RABBITMQ_PLUGINS_EXPAND_DIR=/var/vcap/store/rabbitmq/mnesia/db-plugins-expand"
    expect_to_contain "$(<$dir/env)" "ENABLED_PLUGINS_FILE=/var/vcap/store/rabbitmq/enabled_plugins"
    expect_to_contain "$(<$dir/env)" "USE_LONGNAME=false"

    ) || ( $T_fail "Failed to create conf_env file" && return 1 )
}

T_creates_a_file_with_all_the_nodes_to_be_used_during_upgrades() {
  (
    local nodes_file
    nodes_file="$(mktemp)"
    trap 'rm -rf ${nodes_file}' EXIT

    prepare_for_upgrade "node1,node2" "$nodes_file"

    expect_to_equal "$(<$nodes_file)" "$(echo -e node1\\nnode2)"

    ) || ( $T_fail "Failed to create file with nodes" && return 1 )
}

 T_if_a_file_with_all_the_nodes_exist_should_ignore_its_content() {
  (
    local nodes_file
    nodes_file="$(mktemp)"
    trap 'rm -rf ${nodes_file}' EXIT
    echo "some existing nodes from previous deployments" > $nodes_file

    prepare_for_upgrade "node1,node2" "$nodes_file"

    expect_to_equal "$(<$nodes_file)" "$(echo -e node1\\nnode2)"

    ) || ( $T_fail "Failed to check nodes file" && return 1 )
}

T_create_erlang_cookie() {
  (
    if [ "$(uname -s)" != "Linux" ]; then
      echo "WARNING: This test can only be run on Linux plaftorms... skipping!"
      exit 0
    fi

    #before we need to create vcap user
    sudo adduser --disabled-password --gecos "" vcap

    local erlang_cookie dir

    erlang_cookie="this-is-my-cookie"
    dir="$(mktemp -d)"
    trap "rm -rf ${dir}" EXIT

    create_erlang_cookie "$dir" "$erlang_cookie" "vcap"
    expect_file_to_exist "${dir}/.erlang.cookie"
    expect_to_equal "$(<$dir/.erlang.cookie)" "$erlang_cookie"

    ) || ( $T_fail "Failed to create erlang cookie" && return 1 )
}

T_configure_management_listener_tls() {
  (
    listeners="$(configure_management_listener "true" "fake_path")"

    expect_to_equal "$listeners" "-rabbitmq_management listener [{port,15671},{ssl,true},{ssl_opts,[{cacertfile,\"fake_path/../etc/management-cacert.pem\"},{certfile,\"fake_path/../etc/management-cert.pem\"},{keyfile,\"fake_path/../etc/management-key.pem\"}]}]"
    ) || ( $T_fail "Failed to configure management listener for TLS" && return 1 )
}

T_configure_management_listener_no_tls() {
  (
    listeners="$(configure_management_listener "false" "fake_path")"

    expect_to_equal "$listeners" "-rabbitmq_management listener [{port,15672},{ssl,false}]"
    ) || ( $T_fail "Failed to configure management listener for no TLS" && return 1 )
}
