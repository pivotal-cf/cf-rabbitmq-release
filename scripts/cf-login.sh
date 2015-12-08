#!/bin/sh

# this assumes CF is deployed to a local VM created by bosh-lite:
# https://github.com/cloudfoundry/bosh-lite
cf api http://api.bosh-lite.com
cf auth admin admin && cf create-org pcf-rabbitmq && cf target -o pcf-rabbitmq && cf create-space dev && cf target -o pcf-rabbitmq -s dev
