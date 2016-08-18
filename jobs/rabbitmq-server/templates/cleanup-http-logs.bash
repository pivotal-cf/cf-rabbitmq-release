#!/bin/bash

source /var/vcap/jobs/rabbitmq-server/lib/delete_old_files.bash
delete_old_files /var/vcap/sys/log/rabbitmq-server/management-ui
