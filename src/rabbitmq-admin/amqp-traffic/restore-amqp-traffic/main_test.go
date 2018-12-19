package main_test

import (
	"fmt"
	"os/exec"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"
	. "github.com/onsi/gomega/gexec"
)

var _ = Describe("Main", func() {
	var pathToCmd string

	BeforeSuite(func() {
		var err error
		pathToCmd, err = Build("rabbitmq-admin/amqp-traffic/restore-amqp-traffic")
		Expect(err).NotTo(HaveOccurred())
	})

	AfterSuite(func() {
		CleanupBuildArtifacts()
	})

	It("prints a message saying what it is going to do", func() {
		session := runWithInput(pathToCmd, "no\n", 0)

		Eventually(session.Out).Should(Say("The following commands will be used to unblock AMQP and AMQPS traffic on this node"))
	})

	It("prints the commands that it is going to run", func() {
		session := runWithInput(pathToCmd, "no\n", 0)

		Eventually(session.Out).Should(Say("iptables -D INPUT -p tcp --dport 5671 -j DROP"))
		Eventually(session.Out).Should(Say("iptables -D INPUT -p tcp --dport 5672 -j DROP"))
	})

	It("prints a command to help debugging", func() {
		session := runWithInput(pathToCmd, "no\n", 0)

		Eventually(session.Out).Should(Say("You can view the iptables rules using the command: iptables -L"))
	})

	When("the user is not root", func() {
		It("warns that the command may not work", func() {
			session := runWithInput(pathToCmd, "no\n", 1)

			Eventually(session.Out).Should(Say("WARNING, this command should be run as the root user!"))
		})
	})

	When("the user says no", func() {
		It("stops", func() {
			session := runWithInput(pathToCmd, "no\n", 0)

			Eventually(session).Should(Exit(1))
			Eventually(session).Should(Say("Stopped"))
		})
	})

	When("the user gives invalid input", func() {
		It("complains", func() {
			session := runWithInput(pathToCmd, "foo\n", 0)

			Eventually(session).Should(Exit(1))
			Eventually(session).Should(Say("invalid input"))
		})
	})

	When("the user says yes", func() {
		It("attempts to run the `iptables` command", func() {
			// Note, we use an empty PATH to make sure command isn't acrtually run during the test
			session := runWithInput(pathToCmd, "yes\n", 0)

			Eventually(session).Should(Exit(1))
			Eventually(session).Should(Say("Error running command 'iptables .* exit status 127"))
			Eventually(session).Should(Say("Failed"))
		})
	})
})

func runWithInput(pathToCmd, input string, fakeUid int) *Session {
	command := exec.Command(pathToCmd)
	command.Stdin = strings.NewReader(input)
	command.Env = []string{
		"PATH=", // So it can't find the iptables command
		fmt.Sprintf("FAKE_UID=%d", fakeUid),
	}
	session, err := Start(command, GinkgoWriter, GinkgoWriter)
	Expect(err).NotTo(HaveOccurred())
	return session
}
