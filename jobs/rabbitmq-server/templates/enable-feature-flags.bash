#!/bin/bash -e

[ -z "$DEBUG" ] || set -x

set -u

echo "Enabling all feature flags"
rabbitmqctl enable_feature_flag all
echo "Feature flags enabled"
