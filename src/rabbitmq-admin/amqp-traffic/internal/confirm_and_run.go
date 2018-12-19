package internal

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/vito/go-interact/interact"
)

const (
	ok     = 0
	failed = 1
)

func ConfirmAndRun(explanation, success, helper string, commands []string) int {
	showExplanation(explanation, helper, commands)
	warnIfNotRoot()

	carryOn := false
	if err := interact.NewInteraction("Continue?").Resolve(&carryOn); err != nil {
		fmt.Printf("Error: %s\n", err)
		return failed
	}

	if !carryOn {
		fmt.Println("Stopped.")
		return failed
	}

	if runCommands(commands) {
		fmt.Printf("\nFailed\n\n")
		return failed
	}

	fmt.Printf("\n%s\n\n", success)
	return ok
}

func showExplanation(explanation, helper string, commands []string) {
	fmt.Printf("%s:\n\n", explanation)
	for _, cmd := range commands {
		fmt.Printf(" -  %s\n", cmd)
	}
	fmt.Println("") // For spacing
	fmt.Println(helper)
	fmt.Println("") // For spacing
}

func runCommands(commands []string) bool {
	errors := false
	for _, cmd := range commands {
		command := exec.Command("/usr/bin/env", strings.Split(cmd, " ")...)
		command.Stdout = os.Stdout
		command.Stdin = os.Stdin
		command.Stderr = os.Stderr
		if err := command.Run(); err != nil {
			fmt.Printf("Error running command '%s': %s\n", cmd, err)
			errors = true
		}
	}
	return errors
}

func warnIfNotRoot() {
	if getUid() != 0 {
		fmt.Printf("WARNING, this command should be run as the root user!\n\n")
	}
}

func getUid() int {
	if fakeUid := os.Getenv("FAKE_UID"); fakeUid != "" {
		if value, err := strconv.Atoi(fakeUid); err != nil {
			panic(err)
		} else {
			return value
		}
	}

	return os.Getuid()
}
