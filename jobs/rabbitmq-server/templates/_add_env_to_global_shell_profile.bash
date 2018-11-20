#!/usr/bin/env bash

cat > /etc/profile.d/rabbitmq-server-env.sh <<EOF
. /var/vcap/jobs/rabbitmq-server/bin/env
EOF
