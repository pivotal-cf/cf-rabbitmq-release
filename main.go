package main

import (
	"flag"
	"log"
	"os/exec"
	"regexp"
	"strings"
)

func main() {
	log.SetFlags(0)

	rabbitmqctlPath := flag.String("rabbitmqctl-path", "", "Path to rabbitmqctl")
	node := flag.String("node", "", "RabbitMQ node to prepare")
	newRabbitmqVersion := flag.String("new-rabbitmq-version", "", "Version of RabbitMQ that we are upgrading to")
	flag.Parse()

	assertFlag(*rabbitmqctlPath, "rabbitmqctl-path")
	assertFlag(*node, "node")
	assertFlag(*newRabbitmqVersion, "new-rabbitmq-version")

	rabbitmqctlStatusCommand := exec.Command(*rabbitmqctlPath, "status", "-n", *node)

	out, err := rabbitmqctlStatusCommand.Output()
	if err != nil {
		panic(err)
	}

	rabbitMQVersionLine := findRabbitMQVersionLine(out)
	regex := regexp.MustCompile(`^\{rabbit,"RabbitMQ","(.*)"\},$`)
	rabbitMQVersion := regex.FindAllStringSubmatch(rabbitMQVersionLine, -1)[0][1]

	newVersionComponents := strings.Split(*newRabbitmqVersion, ".")
	remoteVersionComponents := strings.Split(rabbitMQVersion, ".")

	if newVersionComponents[1] != remoteVersionComponents[1] {
		if err := exec.Command(*rabbitmqctlPath, "stop_app", "-n", *node).Run(); err != nil {
			panic(err)
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
