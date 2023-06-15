#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

set -u

main() {
    enable_standard_features
    enable_stream_features
    enable_mqtt_features
}

enable_standard_features() {
    for feature in "virtual_host_metadata" "quorum_queue" "implicit_default_bindings" "maintenance_mode_status" "user_limits" "classic_queue_type_delivery_support" "tracking_records_in_ets" "listener_records_in_ets" "feature_flags_v2" "direct_exchange_routing_v2" "classic_mirrored_queue_version" "drop_unroutable_metric" "empty_basic_get_metric"
    do
        enable_feature_flag "$feature"
    done
}

enable_stream_features() {
    if plugin_enabled "rabbitmq_stream"; then
        for feature in "stream_queue" "stream_single_active_consumer" "restart_streams" "stream_sac_coordinator_unblock_group"
        do
            enable_feature_flag "$feature"
        done
    else
        echo "Ignoring stream feature flags (plugin disabled)"
    fi
}

enable_mqtt_features() {
    if plugin_enabled "rabbitmq_mqtt"; then
        for feature in "deleta_ra_cluster_mqtt_node" "rabbit_mqtt_qos0_queue"
        do
            enable_feature_flag "$feature"
        done
    else
        echo "Ignoring mqtt feature flags (plugin disabled)"
    fi
}

feature_flag_supported() {
    flag_name="$1"
    echo "Ensuring feature flag $flag_name is supported"
    rabbitmqctl list_feature_flags --quiet | grep -q "$flag_name"
}

plugin_enabled() {
    plugin_name="$1"
    rabbitmq-plugins is_enabled "$plugin_name" >/dev/null 2>&1
}

enable_feature_flag() {
    flag_name="$1"
    if feature_flag_supported "$flag_name"; then
        echo "Enabling feature flag $flag_name"
        rabbitmqctl enable_feature_flag --quiet "$flag_name"
    fi
}

main
