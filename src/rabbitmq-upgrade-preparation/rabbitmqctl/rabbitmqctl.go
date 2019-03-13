package rabbitmqctl

import (
	"errors"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

type Status int

const (
	UnreachableHost Status = iota
	UnreachableEpmd
	StoppedRabbitNode
	Unknown
)

type Error struct {
	Message string
	Status  Status
}

func (e *Error) Error() string {
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
		if strings.Contains(string(out), "timeout (timed out)") {
			return RabbitMQCtlStatus{}, &Error{Message: "Unable to reach epmd and host seems down", Status: UnreachableHost}
		} else if strings.Contains(string(out), "address (cannot connect to host/port") {
			return RabbitMQCtlStatus{}, &Error{Message: "Unable to reach epmd but host seems up", Status: UnreachableEpmd}
		} else if strings.Contains(string(out), "node 'rabbit' not running at all") {
			return RabbitMQCtlStatus{}, &Error{Message: "No rabbit node running", Status: StoppedRabbitNode}
		}

		return RabbitMQCtlStatus{}, &Error{Message: "Unknown error", Status: Unknown}
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
		return fmt.Errorf("Failed to stop RabbitMQ app: %s", err)
	}
	return nil
}

func (r *RabbitMQCtl) Shutdown(node string) error {
	output, err := exec.Command(r.path, "shutdown", "-n", node, "--no-wait").CombinedOutput()
	if err != nil {
		if strings.Contains(string(output), "epmd reports: node 'rabbit' not running at all") {
			// Note, when we move to Go 1.12, we can use this instead:
			// if exitErr, ok := err.(*exec.ExitError); ok {
			// 	if exitErr.ExitCode() == 69 { // already shutdown
			return nil
		}
		return fmt.Errorf("Failed to shutdown RabbitMQ: %s:\n%s", err, string(output))
	}
	return nil
}
