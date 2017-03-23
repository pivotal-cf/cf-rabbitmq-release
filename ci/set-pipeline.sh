#!/bin/bash

fly -t zumba set-pipeline --pipeline rabbitmq-upgrade-preparation \
  --config pipeline.yml \
