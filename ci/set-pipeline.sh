#!/bin/bash

fly -t rabbit set-pipeline --pipeline rabbitmq-upgrade-preparation \
  --config pipeline.yml \
