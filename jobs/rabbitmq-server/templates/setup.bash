#!/usr/bin/env bash

set -e # bail out early if any command fails
set -o pipefail # fail if any component of any pipe fails

[[ -z "${DEBUG:-""}" ]] || set -x

HOME_DIR="/var/vcap/store/rabbitmq"
HTTP_ACCESS_LOG_DIR="/var/vcap/sys/log/rabbitmq-server/management-ui"
RABBITMQ_MNESIA_BASE="${HOME_DIR}/mnesia"
RABBITMQ_MNESIA_DIR="${RABBITMQ_MNESIA_BASE}/db"
RABBITMQ_PLUGINS_EXPAND_DIR="$RABBITMQ_MNESIA_BASE/db-plugins-expand"
RABBITMQ_BOOT_MODULE="RABBITMQ_BOOT_MODULE=rabbit"
RMQ_VERSION="3.6.12"

main(){
  local script_dir cluster_args load_definitions server_start_args
  script_dir="$(dirname $0)"

  cluster_args=$(create_cluster_args "${RABBITMQ_NODES_STRING}" "${DISK_ALARM_THRESHOLD}" "${CLUSTER_PARTITION_HANDLING}" "${HTTP_ACCESS_LOG_DIR}")

  load_definitions=$(configure_load_definitions "${LOAD_DEFINITIONS}" "${script_dir}")

  tls_listeners=$(configure_tls_listeners "${SSL_KEY}")

  tls_options=$(configure_tls_options "${SSL_KEY}" "${SSL_VERIFY}" "${SSL_VERIFICATION_DEPTH}" "${SSL_FAIL_IF_NO_PEER_CERT}" "${SSL_SUPPORTED_TLS_VERSIONS}" "${script_dir}")

  server_start_args="${cluster_args} ${load_definitions} ${tls_listeners} ${tls_options}"
  server_start_args="$(format_server_start_args "${server_start_args}")"

  create_config_file "${CONF_ENV_FILE}" "${SELF_NODE}" "${DIR}" "${script_dir}" "${server_start_args}"

  prepare_for_upgrade "${RABBITMQ_NODES_STRING}"

  create_erlang_cookie "${ERLANG_COOKIE}"
}

create_cluster_args() {
  local cluster_args rabbitmq_nodes disk_alarm_threshold cluster_partition_handling http_access_log_dir
  rabbitmq_nodes="$1"
  disk_alarm_threshold="$2"
  cluster_partition_handling="$3"
  http_access_log_dir="$4"

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
  cluster_args="$cluster_args -rabbitmq_management http_log_dir \"${http_access_log_dir}\""

  echo "$cluster_args"
}

format_server_start_args() {
  local cluster_args
  cluster_args="$1"

  echo "SERVER_START_ARGS='$cluster_args'"
}

configure_load_definitions() {
  local load_definitions script_dir load_definitions_file_path
  load_definitions="$1"
  script_dir="$2"

  if [[ ! -z "${load_definitions}" ]]; then
    load_definitions_file_path="${script_dir}/../etc/definitions.json"
    echo "-rabbitmq_management load_definitions \"${load_definitions_file_path}\""
  fi
}

configure_tls_listeners() {
  local ssl_key
  ssl_key="$1"

  if [[ ! -z "${ssl_key}" ]]; then
    # if TLS is enabled, disable the non-TLS listener for AMQP 0-9-1 and make the management/HTTP API
    # listener use TLS.
    echo "-rabbit tcp_listeners [] -rabbit ssl_listeners [5671] -rabbitmq_management listener [{port,15672},{ssl,false}] -rabbitmq_mqtt ssl_listeners [8883] -rabbitmq_stomp ssl_listeners [61614]"
  fi
}

configure_tls_options() {
  local ssl_key ssl_verify ssl_verification_mode ssl_verification_depth script_dir ssl_fail_if_no_peer_cert ssl_supported_tls_versions ssl_options
  ssl_key="$1"
  ssl_verify="$2"
  ssl_verification_depth="$3"
  ssl_fail_if_no_peer_cert="$4"
  ssl_supported_tls_versions="$5"
  script_dir="$6"


  if [[ ! -z "${ssl_key}" ]]; then
    ssl_verification_mode='verify_none'
    if [[ $ssl_verify = true ]]; then
      ssl_verification_mode='verify_peer'
    fi

    # concatenate options encoded in double quotes, see the concatenation comment above.
    # {versions,['tlsv1.2','tlsv1.1',tlsv1]} disables SSLv3 to mitigate the POODLE attack.
    ssl_options=" -rabbit ssl_options [{cacertfile,\\\"${script_dir}/../etc/cacert.pem\\\"},{certfile,\\\"${script_dir}/../etc/cert.pem\\\"},{keyfile,\\\"${script_dir}/../etc/key.pem\\\"},{verify,"$ssl_verification_mode"},{depth,$ssl_verification_depth},{fail_if_no_peer_cert,$ssl_fail_if_no_peer_cert},{versions,$ssl_supported_tls_versions}]"
    echo "\"${ssl_options}\""
  fi
}

create_config_file() {
  local conf_env_file self_node dir nodename config script_dir prefix suffix server_start_args
  conf_env_file="$1"
  self_node="$2"
  dir="$3"
  script_dir="$4"
  server_start_args="$5"
  prefix='### AUTOGENERATED BY RABBITMQ CLUSTERING - DO NOT EDIT BELOW ###'
  suffix='### AUTOGENERATED BY RABBITMQ CLUSTERING - DO NOT EDIT ABOVE ###'
  config="CONFIG_FILE='${script_dir}/../etc/rabbitmq'"
  nodename="NODENAME='${self_node}'"

  if [[ "${conf_env_file}" != " " ]] && [[ -f "${conf_env_file}" ]]; then
    cp ${conf_env_file} ${dir}/env.backup
  else
    printf '' > ${dir}/env.backup
  fi

  sed "/${prefix}/,/${suffix}/d" < ${dir}/env.backup > ${dir}/env

  printf "${prefix}\n" >> ${dir}/env
  printf "${nodename}\n" >> ${dir}/env
  printf "${RABBITMQ_BOOT_MODULE}\n" >> ${dir}/env

  printf "${config}\n" >> ${dir}/env
  printf "${server_start_args}\n" >> "${dir}/env"

  # set custom RabbitMQ db / plugin directory not specifying the node name
  printf "RABBITMQ_MNESIA_DIR=${RABBITMQ_MNESIA_DIR}\n" >> ${dir}/env
  printf "RABBITMQ_PLUGINS_EXPAND_DIR=${RABBITMQ_PLUGINS_EXPAND_DIR}\n" >> ${dir}/env

  printf "${suffix}\n" >> ${dir}/env

  if [[ "${conf_env_file}" != "" ]]; then
    cp ${dir}/env ${conf_env_file}
  fi
}

prepare_for_upgrade() {
  local nodes_file rabbitmq_nodes
  nodes_file="/var/vcap/data/upgrade_preparation_nodes"
  rabbitmq_nodes="$1"

  rm -f nodes_file

  OLD_IFS="$IFS"
  IFS=","
  for node in $rabbitmq_nodes; do
    echo $node >> nodes_file
  done
  IFS="$OLD_IFS"
}

create_erlang_cookie() {
  local erlang_cookie user
  erlang_cookie="$1"
  user="vcap"

  printf "${erlang_cookie}" > "${DIR}/.erlang.cookie"
  # chown ${user}:${user} ${DIR}/.erlang.cookie
  # chmod 0400 ${DIR}/.erlang.cookie
  # cp -a "${DIR}/.erlang.cookie" ${HOME}
}

# shellcheck disable=SC2128
if [[ "$0" = "$BASH_SOURCE" ]]; then
  # only run, when called and not sourced
  . /var/vcap/jobs/rabbitmq-server/lib/setup-vars.bash

  . /var/vcap/jobs/rabbitmq-server/lib/rabbitmq-config-vars.bash

  # Unfortunate tight coupling. Beware.
  # We need this for CONF_ENV_FILE, HOME, ERL_INETRC, and for MNESIA_BASE
  . /var/vcap/packages/rabbitmq-server/privbin/rabbitmq-defaults

  main
fi

