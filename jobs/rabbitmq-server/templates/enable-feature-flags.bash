#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

set -u

main() {
    enable_all_3_8_features
    enable_all_supported_features
    enable_stream_queue
}

enable_all_3_8_features() {
    for feature in "implicit_default_bindings" "mainenance_mode_status" "quourum_queue" "user_limits" "virtual_host_metadata"
    do
        enable_feature_flag "$feature"
    done
}

enable_all_supported_features() {
    for feature in "classic_morrored_queue_version" "classic_queue_type_delivery_support" "drop_unroutable_metric" "empty_basic_get_metric"
    do
        if feature_flag_supported "$feature"; then
            enable_feature_flag "$feature"
        fi
    done
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
