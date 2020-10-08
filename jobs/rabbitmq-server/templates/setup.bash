#!/usr/bin/env bash

set -e # bail out early if any command fails
set -o pipefail # fail if any component of any pipe fails

[[ -z "${DEBUG:-""}" ]] || set -x

# shellcheck disable=SC2128
if [[ "$0" = "$BASH_SOURCE" ]]; then
  # only run, when called and not sourced
  . /var/vcap/jobs/rabbitmq-server/lib/setup-vars.bash

  . /var/vcap/jobs/rabbitmq-server/lib/rabbitmq-config-vars.bash

  # Unfortunate tight coupling. Beware.
  # We need this for CONF_ENV_FILE, HOME, ERL_INETRC, and for MNESIA_BASE
  . /var/vcap/packages/rabbitmq-server/privbin/rabbitmq-defaults
fi

HOME_DIR="/var/vcap/store/rabbitmq"
HTTP_ACCESS_LOG_DIR="/var/vcap/sys/log/rabbitmq-server/management-ui"
RABBITMQ_MNESIA_BASE="$HOME_DIR/mnesia"
RABBITMQ_MNESIA_DIR="$RABBITMQ_MNESIA_BASE/db"
RABBITMQ_PLUGINS_EXPAND_DIR="$RABBITMQ_MNESIA_BASE/db-plugins-expand"
RABBITMQ_BOOT_MODULE="RABBITMQ_BOOT_MODULE=rabbit"
UPGRADE_PREPARATION_NODES_FILE="/var/vcap/data/upgrade_preparation_nodes"
VCAP_HOME=${VCAP_HOME:-${HOME}}
VCAP_USER=${VCAP_USER:-vcap}
VCAP_GROUP=${VCAP_GROUP:-vcap}

main(){
  local script_dir cluster_args server_start_args
  script_dir="$(dirname "$0")"

  cluster_args=$(create_cluster_args "$RABBITMQ_NODES_STRING" "$DISK_ALARM_THRESHOLD" "$CLUSTER_PARTITION_HANDLING" "$HTTP_ACCESS_LOG_DIR" "$CLUSTER_NAME")

  if ${SSL_ENABLED:?must be set}
  then
    tls_listeners=$(configure_tls_listeners "$SSL_DISABLE_NON_SSL_LISTENERS")
    tls_options=$(configure_tls_options \
      "$SSL_VERIFY" \
      "$SSL_VERIFICATION_DEPTH" \
      "$SSL_FAIL_IF_NO_PEER_CERT" \
      "$SSL_SUPPORTED_TLS_VERSIONS" \
      "$SSL_SUPPORTED_TLS_CIPHERS" \
      "$script_dir" \
    )
  fi

  management_options=$(configure_management_listener "$SSL_ENABLED_ON_MANAGEMENT" "$script_dir")

  server_start_args="$(
    echo \
      "$cluster_args" \
      "$tls_listeners" \
      "$tls_options" \
      "$management_options" \
      -mnesia core_dir \"/var/vcap/sys/log/rabbitmq-server\" \
    | escape_for_singlequoted_string
  )"

  create_config_file \
    "$CONF_ENV_FILE" \
    "$SELF_NODE" \
    "$DIR" \
    "$script_dir" \
    "SERVER_START_ARGS='$server_start_args'" \
    "$ENABLED_PLUGINS_FILE" \
    "$USE_LONGNAME"

  prepare_for_upgrade "$RABBITMQ_NODES_STRING" "$UPGRADE_PREPARATION_NODES_FILE"

  create_erlang_cookie "$DIR" "$ERLANG_COOKIE" "$VCAP_HOME" "$VCAP_USER" "$VCAP_GROUP"
}

create_cluster_args() {
  local cluster_args rabbitmq_nodes disk_alarm_threshold cluster_partition_handling http_access_log_dir cluster_name

  rabbitmq_nodes="$1"
  disk_alarm_threshold="$2"
  cluster_partition_handling="$3"
  http_access_log_dir="$4"
  cluster_name="$5"

  # Modify the rabbitmq-env.conf to include the right NODENAME and SERVER_START_ARGS.
  #    SERVER_START_ARGS is appended to the Erlang VM command line, like so
  #    (shortened and formatted for readability):
  #
  # SERVER_START_ARGS is stored in rabbitmq-env.conf (currently
  # /var/vcap/store/rabbitmq/etc/rabbitmq/rabbitmq-env.conf), which is
  # generated in this template.
  #
  # SERVER_START_ARGS include TLS configuration and options.
  # Some of the options include quotes, both single and double. To avoid
  # multiple layers of quoting, which is quite fragile, shell script string
  # concatenation is used:
  # 'a"'"'b" is treated as a single string, `a"'b`, by bash.
  cluster_args="-rabbit cluster_nodes {[$rabbitmq_nodes],disc}"
  cluster_args="$cluster_args -rabbit log_levels [{connection,info}]"
  cluster_args="$cluster_args -rabbit disk_free_limit $disk_alarm_threshold"
  cluster_args="$cluster_args -rabbit cluster_partition_handling $cluster_partition_handling"
  cluster_args="$cluster_args -rabbit halt_on_upgrade_failure false"
  cluster_args="$cluster_args -rabbitmq_mqtt subscription_ttl 1800000"
  cluster_args="$cluster_args -rabbitmq_management http_log_dir \"$http_access_log_dir\""
  if [ -n "$cluster_name" ]; then
    cluster_args="$cluster_args -rabbit cluster_name \"$cluster_name\""
  fi

  echo "$cluster_args"
}

configure_tls_listeners() {
  local disable_non_ssl_listeners="$1"

  local cmd="-rabbit tcp_listeners [] -rabbit ssl_listeners [5671] -rabbitmq_mqtt ssl_listeners [8883] -rabbitmq_stomp ssl_listeners [61614]"
  local disable_non_ssl_listeners_cmd="-rabbitmq_mqtt tcp_listeners [] -rabbitmq_stomp tcp_listeners []"

  if ${disable_non_ssl_listeners:?must be set}
  then
    echo "$cmd $disable_non_ssl_listeners_cmd"
  else
    echo "$cmd"
  fi
}

configure_management_listener() {
  local ssl_enabled_on_management
  local script_dir
  ssl_enabled_on_management="$1"
  script_dir="$2"

  if ${ssl_enabled_on_management:?must be set}
  then
    echo "-rabbitmq_management listener [{port,15671},{ssl,true},{ssl_opts,[{cacertfile,\"$script_dir/../etc/management-cacert.pem\"},{certfile,\"$script_dir/../etc/management-cert.pem\"},{keyfile,\"$script_dir/../etc/management-key.pem\"}]}]"
  else
    echo "-rabbitmq_management listener [{port,15672},{ssl,false}]"
  fi
}

configure_tls_options() {
  local ssl_verify
  local ssl_verification_mode
  local ssl_verification_depth
  local script_dir
  local ssl_fail_if_no_peer_cert
  local ssl_supported_tls_versions
  local ssl_supported_tls_ciphers
  local ssl_options

  ssl_verify="$1"
  ssl_verification_depth="$2"
  ssl_fail_if_no_peer_cert="$3"
  ssl_supported_tls_versions="$4"
  ssl_supported_tls_ciphers="$5"
  script_dir="$6"

  ssl_verification_mode='verify_none'
  if [[ $ssl_verify = true ]]; then
    ssl_verification_mode='verify_peer'
  fi

  # concatenate options encoded in double quotes, see the concatenation comment above.
  # {versions,['tlsv1.2','tlsv1.1',tlsv1]} disables SSLv3 to mitigate the POODLE attack.
  ssl_options=" -rabbit ssl_options [{cacertfile,\"$script_dir/../etc/cacert.pem\"},{certfile,\"$script_dir/../etc/cert.pem\"},{keyfile,\"$script_dir/../etc/key.pem\"},{verify,$ssl_verification_mode},{depth,$ssl_verification_depth},{fail_if_no_peer_cert,$ssl_fail_if_no_peer_cert},{versions,$ssl_supported_tls_versions}$ssl_supported_tls_ciphers]"
  echo "$ssl_options"
}

escape_for_singlequoted_string() {
  # https://stackoverflow.com/a/1250279
  sed "s/'/'\"'\"'/g"
}

create_config_file() {
  local conf_env_file self_node dir nodename script_dir prefix suffix server_start_args plugins_file use_longname
  conf_env_file="$1"
  self_node="$2"
  dir="$3"
  script_dir="$4"
  server_start_args="$5"
  plugins_file="$6"
  use_longname="$7"
  prefix='### AUTOGENERATED BY RABBITMQ CLUSTERING - DO NOT EDIT BELOW ###'
  suffix='### AUTOGENERATED BY RABBITMQ CLUSTERING - DO NOT EDIT ABOVE ###'
  nodename="NODENAME='$self_node'"
  rabbitmq_nodename="RABBITMQ_NODENAME='$self_node'"

  if [[ "$conf_env_file" != " " ]] && [[ -f "$conf_env_file" ]]; then
    cp "$conf_env_file" "$dir/env.backup"
  else
    printf '' > "$dir/env.backup"
  fi

  sed "/$prefix/,/$suffix/d" < "$dir/env.backup" > "$dir/env"

  printf "%s\n" "$prefix" >> "$dir/env"
  printf "%s\n" "$nodename" >> "$dir/env"
  printf "%s\n" "$rabbitmq_nodename" >> "$dir/env"
  printf "%s\n" "$RABBITMQ_BOOT_MODULE" >> "$dir/env"

  printf "CONFIG_FILE=%s\n" "$config_file" >> "$dir/env"
  printf "ADVANCED_CONFIG_FILE=%s\n" "$advanced_config_file" >> "$dir/env"
  printf "%s\n" "$server_start_args" >> "$dir/env"

  # set custom RabbitMQ db / plugin directory not specifying the node name
  printf "RABBITMQ_MNESIA_DIR=%s\n" "$RABBITMQ_MNESIA_DIR" >> "$dir/env"
  printf "RABBITMQ_PLUGINS_EXPAND_DIR=%s\n" "$RABBITMQ_PLUGINS_EXPAND_DIR" >> "$dir/env"
  printf "ENABLED_PLUGINS_FILE=%s\n" "$plugins_file" >> "$dir/env"
  printf "USE_LONGNAME=%s\n" "$use_longname" >> "$dir/env"

  printf "%s\n" "$suffix" >> "$dir/env"

  if [[ "$conf_env_file" != "" ]]; then
    cp "$dir/env" "$conf_env_file"
  fi
}

prepare_for_upgrade() {
  local rabbitmq_nodes nodes_file

  rabbitmq_nodes="$1"
  nodes_file="${2:-/var/vcap/data/upgrade_preparation_nodes}"

  rm -f "$nodes_file"

  OLD_IFS="$IFS"
  IFS=","
  for node in $rabbitmq_nodes; do
    echo "$node" >> "$nodes_file"
  done
  IFS="$OLD_IFS"
}

create_erlang_cookie() {
  local dir erlang_cookie home user group

  dir="$1"
  erlang_cookie="$2"
  home="$3"
  user="$4"
  group="$5"

  echo -n "$erlang_cookie" > "$dir/.erlang.cookie"
  chown "$user":"$group" "$dir/.erlang.cookie"
  chmod 0400 "$dir/.erlang.cookie"
  cp -a "$dir/.erlang.cookie" "$home"
}

# shellcheck disable=SC2128
if [[ "$0" = "$BASH_SOURCE" ]]; then
  main
fi
