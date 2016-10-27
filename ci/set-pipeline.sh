#!/bin/bash -e

if ! which lpass > /dev/null 2>&1
then
  echo "must have lastpass CLI installed" >&2
  exit 1
fi

ssh_key=$(lpass show "Shared-London Services"/london-ci/git-ssh-key --notes)

fly -t london set-pipeline \
    --pipeline rabbitmq-upgrade-preparation \
    --config pipeline.yml \
    --var git-private-key="${ssh_key}"
