#!/usr/bin/env bash

delete_old_files() {
  local log_dir
  log_dir="${1:?first argument must be logs path}"

  if [[ -d "$log_dir" ]]
  then
    find "$log_dir" -mmin +$(( 7*24*60 )) -delete
  else
    echo "logs path is not a directory" > /dev/stderr
    return 1
  fi
}

