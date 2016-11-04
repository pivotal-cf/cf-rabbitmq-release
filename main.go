package main

import (
	"flag"
	"log"
	"os"
	"time"

	"github.com/cenkalti/backoff"
	"github.com/pivotal-cf/rabbitmq-upgrade-preparation/rabbitmqctl"
	"github.com/pivotal-cf/rabbitmq-upgrade-preparation/versions"
)

func main() {
	logger := log.New(os.Stdout, "", 0)
	log.SetFlags(0)

	args := parseArgs()

	logger.Printf("Checking whether upgrade preparation is necessary for %s\n", args.node)
	rabbitMQCtl := rabbitmqctl.New(args.rabbitmqctlPath)
	backOffStrategy := backoff.NewExponentialBackOff()
	backOffStrategy.MaxElapsedTime = args.timeout
	backOffStrategy.Multiplier = 1.0

	var (
		status     rabbitmqctl.RabbitMQCtlStatus
		retryCount int
	)

	retryErr := backoff.Retry(func() error {
		retryCount++
		var statusErr error
		status, statusErr = rabbitMQCtl.Status(args.node)
		return statusErr
	}, backOffStrategy)

	if retryErr != nil {
		err := retryErr.(*rabbitmqctl.Error)
		if err.Status == rabbitmqctl.UnreachableHost {
			log.Fatalf("Unable to connect to node %s after %d retries within %v: %s", args.node, retryCount, args.timeout, err)
		} else if err.Status == rabbitmqctl.UnreachableEpmd || err.Status == rabbitmqctl.StoppedRabbitNode {
			logger.Printf("RabbitMQ %s already stopped: %s\n", args.node, err)
			return
		}
	}

	deployedRabbitVersion, ok := status.RabbitMQVersion()
	if !ok {
		logger.Printf("Safe to proceed without stopping RabbitMQ %s application, exiting: RabbitMQ application already stopped\n", args.node)
		return
	}

	deployedErlangVersion, _ := status.ErlangVersion()

	differences := []versions.VersionDifference{
		&versions.RabbitVersions{Desired: args.desiredRabbitMQVersion, Deployed: deployedRabbitVersion},
		&versions.ErlangVersions{Desired: args.desiredErlangVersion, Deployed: deployedErlangVersion},
	}

	for _, difference := range differences {
		logger.Printf("%s\n", difference.UpgradeMessage())
		if difference.PreparationRequired() {
			logger.Println("The cluster needs to be taken offline as it cannot run in mixed mode")
			logger.Printf("Stopping RabbitMQ on %s\n", args.node)
			if err := rabbitMQCtl.StopApp(args.node); err != nil {
				log.Fatalf("Failed to stop RabbitMQ on %s: %s", args.node, err)
			}
			return
		}
	}
	logger.Println("Safe to proceed without taking the cluster offline")
}

type Args struct {
	rabbitmqctlPath        string
	node                   string
	desiredRabbitMQVersion string
	desiredErlangVersion   string
	timeout                time.Duration
}

func parseArgs() Args {
	rabbitmqctlPath := flag.String("rabbitmqctl-path", "", "Path to rabbitmqctl")
	node := flag.String("node", "", "RabbitMQ node to prepare")
	newRabbitmqVersion := flag.String("new-rabbitmq-version", "", "Version of RabbitMQ that we are upgrading to")
	newErlangVersion := flag.String("new-erlang-version", "", "Version of Erlang that we are upgrading to")
	timeout := flag.Duration("timeout", 60*time.Second, "Maximum time in seconds that you allow rabbitmqctl status to take")
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
		timeout:                *timeout,
	}
}

func assertFlag(flag, name string) {
	if flag == "" {
		log.Fatalf("Missing -%s flag\n", name)
	}
}
