#!/bin/sh
case "$1" in
    list)
        echo "${STUBBED_PLUGINS_LIST}"
        ;;
    set)
        echo "Test enable: $2"
      ;;
    *)
      ;;
esac
