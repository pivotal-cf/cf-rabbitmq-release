#!/usr/bin/env bash

set -e # bail out early if any command fails
set -o pipefail # fail if any component of any pipe fails

# basht macro, shellcheck fix
export T_fail

# shellcheck disable=SC1091
. spec/bash/test_helpers

# shellcheck disable=SC1091
. jobs/rabbitmq-server/templates/setup.bash

T_create_env_config_file() {
  (
    local conf_env_file self_node dir plugins_file use_longname inter_node_tls

    conf_env_file="$(mktemp)"
    self_node="node-1"
    dir="$(mktemp -d)"
    plugins_file="/var/vcap/store/rabbitmq/enabled_plugins"
    use_longname=false
    inter_node_tls=true

    trap "rm -rf ${dir}" EXIT

    create_env_config_file "$conf_env_file" "$self_node" "$dir" "$plugins_file" "$use_longname" "$inter_node_tls"

    expect_file_to_exist "${dir}/env"
    expect_file_to_exist "${dir}/env.backup"

    expect_to_contain "$(<$dir/env)" "CONFIG_FILES=/var/vcap/jobs/rabbitmq-server/etc/conf.d/*.conf"
    expect_to_contain "$(<$dir/env)" "ADVANCED_CONFIG_FILE=/var/vcap/jobs/rabbitmq-server/etc/advanced.config"
    expect_to_contain "$(<$dir/env)" "NODENAME='node-1'"
    expect_to_contain "$(<$dir/env)" "RABBITMQ_NODENAME='node-1'"
    expect_to_contain "$(<$dir/env)" "SERVER_START_ARGS='-mnesia core_dir \"/var/vcap/sys/log/rabbitmq-server\" -rabbit halt_on_upgrade_failure false'"
    expect_to_contain "$(<$dir/env)" "RABBITMQ_MNESIA_DIR=/var/vcap/store/rabbitmq/mnesia/db"
    expect_to_contain "$(<$dir/env)" "RABBITMQ_PLUGINS_EXPAND_DIR=/var/vcap/store/rabbitmq/mnesia/db-plugins-expand"
    expect_to_contain "$(<$dir/env)" "ENABLED_PLUGINS_FILE=$plugins_file"
    expect_to_contain "$(<$dir/env)" "USE_LONGNAME=false"
    expect_to_contain "$(<$dir/env)" "SERVER_ADDITIONAL_ERL_ARGS=\"-proto_dist inet_tls -ssl_dist_optfile /var/vcap/jobs/rabbitmq-server/etc/inter_node_tls.config"
    expect_to_contain "$(<$dir/env)" "CTL_ERL_ARGS=\"-proto_dist inet_tls -ssl_dist_optfile /var/vcap/jobs/rabbitmq-server/etc/inter_node_tls.config"

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
