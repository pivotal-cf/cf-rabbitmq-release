#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

set -u

LOG_DIR=/var/vcap/sys/log/rabbitmq-server

main() {
  append_rabbitmq_server_and_erlang_to_global_path_via_login_shell
  ensure_rabbitmqctl_in_login_shell_path
}

send_all_output_to_logfile() {
  exec 1> >(tee -a "${LOG_DIR}/add-rabbitmqctl-to-path.log")
  exec 2> >(tee -a "${LOG_DIR}/add-rabbitmqctl-to-path.log")
}

append_rabbitmq_server_and_erlang_to_global_path_via_login_shell() {
  echo "export PATH=$PATH:/var/vcap/packages/rabbitmq-server/bin/:/var/vcap/packages/erlang/bin" > /etc/profile.d/add_rabbitmqctl_to_path.sh
}

ensure_rabbitmqctl_in_login_shell_path() {
  bash -l -c "rabbitmqctl eval 'node().'" ||
  echo "rabbitmqctl not in PATH"
}

send_all_output_to_logfile
main
