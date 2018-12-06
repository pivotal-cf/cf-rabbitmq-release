#!/usr/bin/env bash

set -eu

iptables -D INPUT -p tcp --dport 5671 -j DROP # AMQPS
iptables -D INPUT -p tcp --dport 5672 -j DROP # AMQP
