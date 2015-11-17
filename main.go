package main

import (
	"flag"
	"log"
	"os"
	"os/exec"
	"regexp"
	"strings"
)

func main() {
	stdoutLog := log.New(os.Stdout, "", 0)
	log.SetFlags(0)

	rabbitmqctlPath := flag.String("rabbitmqctl-path", "", "Path to rabbitmqctl")
	node := flag.String("node", "", "RabbitMQ node to prepare")
	newRabbitmqVersion := flag.String("new-rabbitmq-version", "", "Version of RabbitMQ that we are upgrading to")
	flag.Parse()

	assertFlag(*rabbitmqctlPath, "rabbitmqctl-path")
	assertFlag(*node, "node")
	assertFlag(*newRabbitmqVersion, "new-rabbitmq-version")

	stdoutLog.Printf(
		"Checking whether upgrade preparation is necessary: -rabbitmqctl-path %s -node %s -new-rabbitmq-version %s",
		*rabbitmqctlPath, *node, *newRabbitmqVersion,
	)

	out, err := exec.Command(*rabbitmqctlPath, "status", "-n", *node).CombinedOutput()
	if err != nil {
		if strings.Contains(string(out), "timeout") {
			log.Fatalf("'%s status -n %s' returned with error '%s' and '%s', Unable to determine state of RabbitMQ, exiting with failure as it is not safe to proceed", *rabbitmqctlPath, *node, string(out), err)
		}

		stdoutLog.Printf("'%s status -n %s' returned with error '%s' and '%s', Erlang VM likely down. Do not need to stop RabbitMQ", *rabbitmqctlPath, *node, string(out), err)
		return
	}

	newVersionComponents := strings.Split(*newRabbitmqVersion, ".")
	remoteRabbitVersion, ok := parseRemoteRabbitMQVersion(out)
	if !ok {
		stdoutLog.Println(
			"'%s status -n %s' reported that rabbit is down, erlang VM still up. Do not need to stop RabbitMQ",
			*rabbitmqctlPath, *node,
		)
		return
	}

	remoteVersionComponents := strings.Split(remoteRabbitVersion, ".")

	if isMinorOrMajorUpgrade(newVersionComponents, remoteVersionComponents) {
		stdoutLog.Println("There was a new minor or major version. Stopping RabbitMQ")
		if out, err := exec.Command(*rabbitmqctlPath, "stop_app", "-n", *node).CombinedOutput(); err != nil {
			log.Fatalf("'%s stop_app -n %s' returned with error '%s' and '%s', Failed to stop RabbitMQ.", *rabbitmqctlPath, *node, string(out), err)
		}
	}
}

func assertFlag(flag, name string) {
	if flag == "" {
		log.Fatalf("Missing -%s flag\n", name)
	}
}

func findRabbitMQVersionLine(out []byte) string {
	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		if strings.Contains(line, "{rabbit,") {
			return strings.TrimSpace(line)
		}
	}

	return ""
}

func isMinorOrMajorUpgrade(newVersionComponents, remoteVersionComponents []string) bool {
	return newVersionComponents[0] != remoteVersionComponents[0] ||
		newVersionComponents[1] != remoteVersionComponents[1]
}

func parseRemoteRabbitMQVersion(rabbitMqctlStatusCommandOutput []byte) (string, bool) {
	rabbitMQVersionLine := findRabbitMQVersionLine(rabbitMqctlStatusCommandOutput)
	regex := regexp.MustCompile(`^\{rabbit,"RabbitMQ","(.*)"\},$`)
	matches := regex.FindAllStringSubmatch(rabbitMQVersionLine, -1)
	if len(matches) > 0 {
		return matches[0][1], true
	}
	return "", false
}
