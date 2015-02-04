package rabbit

import "os/exec"

type shell struct{}

func (s *shell) Run(command string, args []string) error {
	cmd := exec.Command(command, args...)
	return cmd.Run()
}
