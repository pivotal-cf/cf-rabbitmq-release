#!/bin/bash

set -e
set -o pipefail

main() {
  run_go_vet
  run_golint
  run_tests "$@"
}

run_go_vet() {
  __message "Running go vet"
  all_go_code_except_Godeps | xargs go tool vet
}

all_go_code_except_Godeps() {
  find . -maxdepth 1 -type d -not -path "*/Godeps*" -a -not -path '*/.git*' -a -not -path '.' "$@"
}

__message() {
  local _message=$1
  echo -e "${_message}..."
}

run_golint() {
  __message "Running golint"

  set +o pipefail
  golint_result=$(
    all_go_code_except_Godeps -exec golint {} \; \
      | grep -v "should have comment" \
      | cat
  )
  set -o pipefail

  if [[ -n $golint_result ]]
  then
    echo "$golint_result"
    exit 1
  else
    echo "No golint errors!"
  fi
}

run_tests() {
  __message "Running tests"

  GOPATH=$PWD/Godeps/_workspace:$GOPATH \
    ginkgo -r -race -skipMeasurements -randomizeAllSpecs "$@"
}

main "$@"

