package main

import (
	"flag"
	"log"
	"os"

	"github.com/pivotal-cf/rabbitmq-upgrade-preparation/rabbitmqctl"
	"github.com/pivotal-cf/rabbitmq-upgrade-preparation/versions"
)

func main() {
	stdoutLog := log.New(os.Stdout, "", 0)
	log.SetFlags(0)

	args := parseArgs()

	stdoutLog.Printf(
		"Checking whether upgrade preparation is necessary: -rabbitmqctl-path %s -node %s -new-rabbitmq-version %s -new-erlang-version %s",
		args.rabbitmqctlPath, args.node, args.desiredRabbitMQVersion, args.desiredErlangVersion,
	)

	rabbitMQCtl := rabbitmqctl.New(args.rabbitmqctlPath)

	status, err := rabbitMQCtl.Status(args.node)
	if _, ok := err.(*rabbitmqctl.UnreachableVMError); ok {
		log.Fatalf("Not safe to proceed, exiting: %s", err)
	}
	if _, ok := err.(*rabbitmqctl.UnreachableEpmdError); ok {
		stdoutLog.Printf("Safe to proceed without stopping RabbitMQ application, exiting: %s", err)
		return
	} else if _, ok := err.(*rabbitmqctl.StoppedRabbitNodeError); ok {
		stdoutLog.Printf("Safe to proceed without stopping RabbitMQ application, exiting: %s", err)
		return
	}

	deployedRabbitVersion, ok := status.RabbitMQVersion()
	if !ok {
		stdoutLog.Println(
			"Safe to proceed without stopping RabbitMQ application, exiting: RabbitMQ application already stopped")
		return
	}

	deployedErlangVersion, _ := status.ErlangVersion()

	differences := []versions.VersionDifference{
		&versions.RabbitVersions{Desired: args.desiredRabbitMQVersion, Deployed: deployedRabbitVersion},
		&versions.ErlangVersions{Desired: args.desiredErlangVersion, Deployed: deployedErlangVersion},
	}

	for _, difference := range differences {
		if difference.PreparationRequired() {
			stdoutLog.Println("Stopping RabbitMQ application")
			if err := rabbitMQCtl.StopApp(args.node); err != nil {
				log.Fatalf("Failed to stop RabbitMQ: %s", err)
			}
			return
		}
	}

	stdoutLog.Println("Safe to proceed without stopping RabbitMQ application, exiting: No breaking upgrade")
}

type Args struct {
	rabbitmqctlPath        string
	node                   string
	desiredRabbitMQVersion string
	desiredErlangVersion   string
}

func parseArgs() Args {
	rabbitmqctlPath := flag.String("rabbitmqctl-path", "", "Path to rabbitmqctl")
	node := flag.String("node", "", "RabbitMQ node to prepare")
	newRabbitmqVersion := flag.String("new-rabbitmq-version", "", "Version of RabbitMQ that we are upgrading to")
	newErlangVersion := flag.String("new-erlang-version", "", "Version of Erlang that we are upgrading to")
	flag.Parse()

	assertFlag(*rabbitmqctlPath, "rabbitmqctl-path")
	assertFlag(*node, "node")
	assertFlag(*newRabbitmqVersion, "new-rabbitmq-version")
	assertFlag(*newErlangVersion, "new-erlang-version")

	return Args{
		rabbitmqctlPath: *rabbitmqctlPath,
		node:            *node,
		desiredRabbitMQVersion: *newRabbitmqVersion,
		desiredErlangVersion:   *newErlangVersion,
	}
}

func assertFlag(flag, name string) {
	if flag == "" {
		log.Fatalf("Missing -%s flag\n", name)
	}
}
