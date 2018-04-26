package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"
	"time"

	"github.com/cenkalti/backoff"
	"github.com/pivotal-cf/rabbitmq-upgrade-preparation/rabbitmqctl"
	"github.com/pivotal-cf/rabbitmq-upgrade-preparation/versions"
)

type logWriter struct {
}

func (writer logWriter) Write(bytes []byte) (int, error) {
	return fmt.Print(time.Now().UTC().Format(time.RFC3339) + string(bytes))
}

func main() {
	logger := log.New(new(logWriter), "", 0)

	if os.Args[3] == "shutdown-cluster" {
		shutdownCluster(logger)
		// os.Exit(0)
	} else {
		stopRabbitMQApp(logger)
		// os.Exit(0)
	}
}

func parseStopRabbitMQArgs() (string, string, string, string, time.Duration) {
	rabbitmqctlPath := flag.String("rabbitmqctl-path", "", "Path to rabbitmqctl")
	node := flag.String("node", "", "RabbitMQ node to prepare")
	newRabbitmqVersion := flag.String("new-rabbitmq-version", "", "Version of RabbitMQ that we are upgrading to")
	newErlangVersion := flag.String("new-erlang-version", "", "Version of Erlang that we are upgrading to")
	timeout := flag.Duration("timeout", 60*time.Second, "Maximum time in seconds to wait for the RabbitMQ node that is being prepared")
	flag.Parse()

	assertFlag(*rabbitmqctlPath, "rabbitmqctl-path")
	assertFlag(*node, "node")
	assertFlag(*newRabbitmqVersion, "new-rabbitmq-version")
	assertFlag(*newErlangVersion, "new-erlang-version")

	return *rabbitmqctlPath, *node, *newRabbitmqVersion, *newErlangVersion, *timeout
}

func stopRabbitMQApp(logger *log.Logger) {
	rabbitmqCtlPath, node, desiredRabbitMQVersion, desiredErlangVersion, timeout := parseStopRabbitMQArgs()

	logger.Printf("Checking whether upgrade preparation is necessary for %s\n", node)
	rabbitMQCtl := rabbitmqctl.New(rabbitmqCtlPath)

	backOffStrategy := backoff.NewExponentialBackOff()
	backOffStrategy.MaxElapsedTime = timeout
	backOffStrategy.InitialInterval = 100 * time.Millisecond

	var status rabbitmqctl.RabbitMQCtlStatus
	var statusErr error
	var retryCount int

	operation := func() error {
		retryCount++
		logger.Printf("Trying to connect to %s...\n", node)
		status, statusErr = rabbitMQCtl.Status(node)
		if statusErr != nil {
			err := statusErr.(*rabbitmqctl.Error)

			if err.Status == rabbitmqctl.UnreachableEpmd || err.Status == rabbitmqctl.StoppedRabbitNode {
				logger.Printf("RabbitMQ %s already stopped: %s\n", node, err)
				return nil
			}
		}

		if backOffStrategy.NextBackOff() != backoff.Stop {
			logger.Printf("Failed to connect to %s after %d retries, retrying in %s\n", node, retryCount, backOffStrategy.NextBackOff())
		}
		return statusErr
	}
	retryErr := backoff.Retry(operation, backOffStrategy)

	if retryErr != nil {
		err := retryErr.(*rabbitmqctl.Error)
		if err.Status == rabbitmqctl.UnreachableHost {
			log.Fatalf("Unable to connect to node %s after %d retries within %v: %s", node, retryCount, timeout, err)
		}
	}

	deployedRabbitVersion, ok := status.RabbitMQVersion()
	if !ok {
		logger.Printf("Safe to proceed without stopping RabbitMQ %s application, exiting: RabbitMQ application already stopped\n", node)
		return
	}

	deployedErlangVersion, _ := status.ErlangVersion()

	differences := []versions.VersionDifference{
		&versions.RabbitVersions{Desired: desiredRabbitMQVersion, Deployed: deployedRabbitVersion},
		&versions.ErlangVersions{Desired: desiredErlangVersion, Deployed: deployedErlangVersion},
	}

	for _, difference := range differences {
		logger.Printf("%s\n", difference.UpgradeMessage())
		if difference.PreparationRequired() {
			logger.Println("The cluster needs to be taken offline as it cannot run in mixed mode")
			logger.Printf("Stopping RabbitMQ on %s\n", node)
			if err := rabbitMQCtl.StopApp(node); err != nil {
				log.Fatalf("Failed to stop RabbitMQ on %s: %s", node, err)
			}
			return
		}
	}
	logger.Println("Safe to proceed without taking the cluster offline")
}

type nodeList []string

func (s *nodeList) String() string {
	return fmt.Sprintf("%v", *s)
}

func (s *nodeList) Set(value string) error {
	*s = strings.Split(value, ",")
	return nil
}

func parseShutdownClusterArgs() (string, nodeList, string, string) {
	rabbitmqctlPath := flag.String("rabbitmqctl-path", "", "Path to rabbitmqctl")
	flag.Parse()

	var nodes nodeList

	shutdownClusterFlags := flag.NewFlagSet("shutdown-cluster", flag.PanicOnError)
	newCookie := shutdownClusterFlags.String("new-cookie", "", "cookie for the new deployment")
	oldCookiePath := shutdownClusterFlags.String("old-cookie-path", "", "path for cookie file")
	shutdownClusterFlags.Var(&nodes, "nodes", "list of rabbit nodes")

	shutdownClusterFlags.Parse(flag.Args()[1:])

	assertFlag(*rabbitmqctlPath, "rabbitmqctl-path")
	assertFlag(*newCookie, "new-cookie")
	assertFlag(*oldCookiePath, "old-cookie-path")

	return *rabbitmqctlPath, nodes, *oldCookiePath, *newCookie
}

func shutdownCluster(logger *log.Logger) {
	rabbitmqCtlPath, nodes, oldCookiePath, newCookie := parseShutdownClusterArgs()

	if _, err := os.Stat(oldCookiePath); os.IsNotExist(err) {
		fmt.Println("New deployment, cluster will not be shutdown")
		return
	}

	oldCookie, err := ioutil.ReadFile(oldCookiePath)

	if err != nil {
		logger.Fatalf("Cannot read the cookie: %s\n", err)
	}

	if string(oldCookie) == newCookie {
		fmt.Println("Cookies match, cluster will not be shutdown")
		return
	}

	rabbitMQCtl := rabbitmqctl.New(rabbitmqCtlPath)

	for _, node := range nodes {
		err := rabbitMQCtl.Shutdown(node)
		if err != nil {
			fmt.Printf("Failed to shutdown node %s. Moving on.\n", node)
		} else {
			fmt.Printf("Shutdown RabbitMQ on %s\n", node)
		}
	}
}

func assertFlag(flag, name string) {
	if flag == "" {
		log.Fatalf("Missing -%s flag\n", name)
	}
}
