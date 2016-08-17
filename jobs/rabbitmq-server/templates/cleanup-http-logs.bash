#!/bin/bash

source /var/vcap/jobs/rabbitmq-server/lib/delete_files_over_a_day_old_in_dir.bash
delete_files_over_a_day_old_in_dir /var/vcap/sys/log/rabbitmq-server/management-ui
