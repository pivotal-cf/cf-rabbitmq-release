package main

import (
	"os"

	"rabbitmq-admin/amqp-traffic/internal"
)

var commands = []string{
	"iptables -D INPUT -p tcp --dport 5671 -j DROP", // AMQPS
	"iptables -D INPUT -p tcp --dport 5672 -j DROP", // AMQP
}

func main() {
	os.Exit(internal.ConfirmAndRun(
		"The following commands will be used to unblock AMQP and AMQPS traffic on this node",
		"AMQP and AMQPS traffic is now unblocked",
		"You can view the iptables rules using the command: iptables -L",
		commands,
	))
}
