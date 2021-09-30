#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

set -u

main() {
    enable_stream_queue
}

enable_stream_queue() {
    if feature_flag_supported "stream_queue" && plugin_enabled "rabbitmq_stream"; then
        echo "Making sure stream_queue flag is enabled"
        enable_feature_flag "stream_queue"
    else
        echo "Ignoring stream_queue flag (either not supported or plugin disabled)"
    fi
}

feature_flag_supported() {
    flag_name="$1"
    rabbitmqctl list_feature_flags --quiet | grep -q "$flag_name"
}

plugin_enabled() {
    plugin_name="$1"
    rabbitmq-plugins is_enabled "$plugin_name" >/dev/null 2>&1
}

enable_feature_flag() {
    flag_name="$1"
    rabbitmqctl enable_feature_flag --quiet "$flag_name"
}

main
