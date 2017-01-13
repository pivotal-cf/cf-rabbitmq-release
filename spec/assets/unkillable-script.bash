#!/bin/bash -e

main() {
  sleep 30
}

trap main SIGINT SIGTERM

main
