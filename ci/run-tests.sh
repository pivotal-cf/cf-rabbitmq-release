#!/bin/bash -e

project_dir=$(dirname $0)/..

gopath_project=$GOPATH/src/github.com/pivotal-cf
mkdir -p $gopath_project
cp -r $project_dir $gopath_project/

pushd $gopath_project/rabbitmq-upgrade-preparation
  export GOPATH=$PWD/Godeps/_workspace:$GOPATH
  export PATH=$PWD/Godeps/_workspace/bin:$PATH
  go install github.com/onsi/ginkgo/ginkgo

  ginkgo -r -race -keepGoing -randomizeAllSpecs -skipMeasurements -failOnPending
popd

