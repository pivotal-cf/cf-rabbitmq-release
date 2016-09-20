#!/bin/bash

source /var/vcap/jobs/rabbitmq-server/lib/delete_old_files.bash

main() {
  delete_all_legacy_http_log_files
  delete_http_log_files
}

delete_all_legacy_http_log_files() {
  rm -f /var/vcap/sys/log/rabbitmq-server/access.log*
}

delete_http_log_files() {
  delete_old_files /var/vcap/sys/log/rabbitmq-server/management-ui
}

main
