#!/bin/bash

fly -t zumba set-pipeline --pipeline rabbitmq-cluster-migration-tool \
  --config pipeline.yml \
