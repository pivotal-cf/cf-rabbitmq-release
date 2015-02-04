package rabbit

import (
	"log"
	"os/exec"
)

type shell struct{}

func (s *shell) Run(command string, args []string) error {
	cmd := exec.Command(command, args...)
	output, err := cmd.CombinedOutput()
	log.Printf(string(output))
	return err
}
