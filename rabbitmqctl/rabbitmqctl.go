package rabbitmqctl

import (
	"errors"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

type UnreachableEpmdError struct {
	Message string
}

func (e *UnreachableEpmdError) Error() string {
	return e.Message
}

type StoppedRabbitNodeError struct {
	Message string
}

func (e *StoppedRabbitNodeError) Error() string {
	return e.Message
}

type RabbitMQCtl struct {
	path string
}

func New(path string) *RabbitMQCtl {
	return &RabbitMQCtl{path}
}

func (r *RabbitMQCtl) Status(node string) (RabbitMQCtlStatus, error) {
	out, err := exec.Command(r.path, "status", "-n", node).CombinedOutput()

	if err != nil {
		if strings.Contains(string(out), "* unable to connect to epmd") {
			return RabbitMQCtlStatus{}, &UnreachableEpmdError{"Unable to reach epmd"}
		} else if strings.Contains(string(out), "node 'rabbit' not running at all") {
			return RabbitMQCtlStatus{}, &StoppedRabbitNodeError{"No rabbit node running"}
		}

		return RabbitMQCtlStatus{}, errors.New("Unknown error")
	}

	return RabbitMQCtlStatus{string(out)}, nil
}

type RabbitMQCtlStatus struct {
	output string
}

func (s *RabbitMQCtlStatus) RabbitMQVersion() (string, bool) {
	return matchRegexp(`(?m)^ +\{rabbit,"RabbitMQ","(.*)"\},$`, s.output)
}

func (s *RabbitMQCtlStatus) ErlangVersion() (string, error) {
	version, ok := matchRegexp(`Erlang/OTP ([^ ]+) \[`, s.output)
	if !ok {
		return "", errors.New("No Erlang version available")
	}
	return version, nil
}

func matchRegexp(re string, text string) (string, bool) {
	regex := regexp.MustCompile(re)
	matches := regex.FindAllStringSubmatch(text, -1)
	if len(matches) > 0 {
		return matches[0][1], true
	}
	return "", false
}

func (r *RabbitMQCtl) StopApp(node string) error {
	err := exec.Command(r.path, "stop_app", "-n", node).Run()
	if err != nil {
		return errors.New(fmt.Sprintf("Failed to stop RabbitMQ app: %s", err))
	}
	return nil
}
