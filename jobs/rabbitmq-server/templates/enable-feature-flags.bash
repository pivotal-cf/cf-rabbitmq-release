#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

set -u

main() {
    enable_feature_flag "all"
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
