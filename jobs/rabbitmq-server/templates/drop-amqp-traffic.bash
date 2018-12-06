#!/usr/bin/env bash

set -eu

iptables -A INPUT -p tcp --dport 5671 -j DROP # AMQPS
iptables -A INPUT -p tcp --dport 5672 -j DROP # AMQP
