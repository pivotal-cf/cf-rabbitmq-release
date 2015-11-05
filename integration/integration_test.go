package integration_test

import (
	"os/exec"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Upgrading RabbitMQ", func() {
	execBin := func(args ...string) *gexec.Session {
		cmd := exec.Command(binPath, args...)
		session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
		return session
	}

	var (
		args    []string
		session *gexec.Session
	)

	JustBeforeEach(func() {
		session = execBin(args...)
	})

	BeforeEach(func() {
		args = []string{
			"-rabbitmqctl-path", "/tmp/rabbitmqctl",
			"-node", "node",
			"-new-rabbitmq-version", "0.0.1",
		}
	})

	Context("When there is no new version of rabbit", func() {
		It("exits with a zero exit code", func() {
			session := execBin(args...)
			Eventually(session).Should(gexec.Exit(0))
		})
	})

	Context("When the rabbitmqctl-path is not provided", func() {
		BeforeEach(func() {
			args = []string{
				"-node", "node",
				"-new-rabbitmq-version", "0.0.1",
			}
		})

		It("exits with a non-zero exit code", func() {
			Eventually(session).Should(gexec.Exit())
			Expect(session.ExitCode()).NotTo(BeZero())
		})

		It("provides a meaningful error", func() {
			Eventually(session.Err).Should(gbytes.Say("Missing -rabbitmqctl-path flag"))
		})
	})

	Context("When the node is not provided", func() {
		BeforeEach(func() {
			args = []string{
				"-rabbitmqctl-path", "/tmp/rabbitmqctl",
				"-new-rabbitmq-version", "0.0.1",
			}
		})

		It("exits with a non-zero exit code", func() {
			Eventually(session).Should(gexec.Exit())
			Expect(session.ExitCode()).NotTo(BeZero())
		})

		It("provides a meaningful error", func() {
			Eventually(session.Err).Should(gbytes.Say("Missing -node flag"))
		})
	})

	Context("When the rabbitmq-version is not provided", func() {
		BeforeEach(func() {
			args = []string{
				"-rabbitmqctl-path", "/tmp/rabbitmqctl",
				"-node", "node",
			}
		})

		It("exits with a non-zero exit code", func() {
			Eventually(session).Should(gexec.Exit())
			Expect(session.ExitCode()).NotTo(BeZero())
		})

		It("provides a meaningful error", func() {
			Eventually(session.Err).Should(gbytes.Say("Missing -new-rabbitmq-version flag"))
		})
	})
})
