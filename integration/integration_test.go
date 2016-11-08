package integration_test

import (
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gbytes"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Upgrading RabbitMQ", func() {
	execBin := func(args ...string) *gexec.Session {
		args = append(args, "-timeout=1s")
		cmd := exec.Command(binPath, args...)
		session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
		Expect(err).ToNot(HaveOccurred())
		return session
	}

	var (
		args    []string
		session *gexec.Session

		tmpDir  string
		tmpFile string
	)

	itExitsWithZero := func() {
		It("exits with a zero exit code", func() {
			Eventually(session).Should(gexec.Exit(0))
		})
	}

	itExitsWithNonZero := func() {
		It("exits with a non-zero exit code", func() {
			Eventually(session).Should(gexec.Exit())
			Expect(session.ExitCode()).NotTo(BeZero())
		})
	}

	itCallsStopApp := func() {
		It("calls stop app", func() {
			Eventually(session).Should(gexec.Exit())

			contents, err := ioutil.ReadFile(tmpFile)
			Expect(err).NotTo(HaveOccurred())
			Expect(strings.Count(string(contents), "stop_app -n rabbit@host\n")).To(Equal(1))
			Eventually(session.Out).Should(gbytes.Say("It looks like you are trying to upgrade"))
			Eventually(session.Out).Should(gbytes.Say("The cluster needs to be taken offline as it cannot run in mixed mode"))
			Eventually(session.Out).Should(gbytes.Say("Stopping RabbitMQ on rabbit@host"))
		})
	}

	itDoesntCallStopApp := func() {
		It("doesn't call stop app", func() {
			_, err := os.Stat(tmpFile)
			Expect(os.IsNotExist(err)).To(BeTrue())
			Consistently(session.Out).ShouldNot(gbytes.Say("Stopping RabbitMQ"))
		})
	}

	JustBeforeEach(func() {
		session = execBin(args...)
	})

	BeforeEach(func() {
		args = []string{
			"-rabbitmqctl-path", "/idontexist/rabbitmqctl",
			"-node", "node",
			"-new-rabbitmq-version", "0.0.1",
			"-new-erlang-version", "17",
		}

		var err error
		tmpDir, err = ioutil.TempDir("", "rabbitmq-upgrade-tests")
		Expect(err).NotTo(HaveOccurred())
		tmpFile = filepath.Join(tmpDir, "erlang-17-rabbit-3.4.3.1.txt")

		os.Setenv("TEST_OUTPUT_FILE", tmpFile)
	})

	AfterEach(func() {
		Expect(os.RemoveAll(tmpDir)).To(Succeed())
	})

	Context("Any time the tool is run", func() {
		It("should log the arguments it has received", func() {
			Eventually(session.Out).Should(gbytes.Say("Checking whether upgrade preparation is necessary for node"))
			Eventually(session.Out).Should(gbytes.Say("Safe to proceed without stopping RabbitMQ node application, exiting: RabbitMQ application already stopped"))
		})
	})

	Context("When there is no new version of RabbitMQ or Erlang", func() {
		BeforeEach(func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())
			args = []string{
				"-rabbitmqctl-path", filepath.Join(cwd, "..", "rabbitmqctl", "test-assets", "rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh"),
				"-node", "rabbit@host",
				"-new-rabbitmq-version", "3.4.3.1",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithZero()
		itDoesntCallStopApp()

		It("logs the fact that it doesn't need to stop RabbitMQ", func() {
			Eventually(session.Out).Should(gbytes.Say("Safe to proceed without taking the cluster offline"))
		})
	})

	Context("When upgrading Erlang", func() {
		BeforeEach(func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())

			args = []string{
				"-rabbitmqctl-path", filepath.Join(cwd, "..", "rabbitmqctl", "test-assets", "rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh"),
				"-node", "rabbit@host",
				"-new-rabbitmq-version", "3.4.3.1",
				"-new-erlang-version", "17.1",
			}
		})

		itExitsWithZero()
		itDoesntCallStopApp()
	})

	Context("When upgrading RabbitMQ", func() {
		BeforeEach(func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())

			args = []string{
				"-rabbitmqctl-path", filepath.Join(cwd, "..", "rabbitmqctl", "test-assets", "rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh"),
				"-node", "rabbit@host",
				"-new-rabbitmq-version", "4.4.0.0",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithZero()
		itCallsStopApp()
	})

	Context("When upgrading both Erlang and RabbitMQ", func() {
		BeforeEach(func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())

			args = []string{
				"-rabbitmqctl-path", filepath.Join(cwd, "..", "rabbitmqctl", "test-assets", "rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh"),
				"-node", "rabbit@host",
				"-new-rabbitmq-version", "4.4.0.0",
				"-new-erlang-version", "17.1",
			}
		})

		itCallsStopApp()
	})

	Context("When the rabbitmq app is not running", func() {
		BeforeEach(func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())

			args = []string{
				"-rabbitmqctl-path", filepath.Join(cwd, "..", "rabbitmqctl", "test-assets", "rabbitmqctl-rabbitmq-app-stopped.sh"),
				"-node", "rabbit@host",
				"-new-rabbitmq-version", "3.4.3.1",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithZero()
		itDoesntCallStopApp()

		It("logs that RabbitMQ is down through stdout (no need to stop, not an error)", func() {
			Eventually(session.Out).Should(gbytes.Say("Safe to proceed without stopping RabbitMQ rabbit@host application, exiting: RabbitMQ application already stopped"))
		})
	})

	Context("When the 'rabbit' node is not running", func() {
		BeforeEach(func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())

			args = []string{
				"-rabbitmqctl-path", filepath.Join(cwd, "..", "rabbitmqctl", "test-assets", "rabbitmqctl-stopped-rabbit-node.sh"),
				"-node", "rabbit@host",
				"-new-rabbitmq-version", "3.4.3.1",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithZero()
		itDoesntCallStopApp()

		It("logs that the 'rabbit' node is down through stdout (no need to stop)", func() {
			Eventually(session.Out).Should(gbytes.Say("RabbitMQ rabbit@host already stopped: No rabbit node running"))
		})
	})

	Context("When rabbitmqctl cannot reach the remote epmd but host seems up", func() {
		BeforeEach(func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())

			args = []string{
				"-rabbitmqctl-path", filepath.Join(cwd, "..", "rabbitmqctl", "test-assets", "rabbitmqctl-epmd-down-host-up.sh"),
				"-node", "rabbit@host",
				"-new-rabbitmq-version", "3.4.3.1",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithZero()
		itDoesntCallStopApp()

		It("logs that the remote epmd cannot be reached, but that this is OK", func() {
			Eventually(session.Out).Should(gbytes.Say("RabbitMQ rabbit@host already stopped: Unable to reach epmd but host seems up"))
		})
	})

	Context("When rabbitmqctl cannot reach the remote host", func() {
		BeforeEach(func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())

			args = []string{
				"-rabbitmqctl-path", filepath.Join(cwd, "..", "rabbitmqctl", "test-assets", "rabbitmqctl-host-down.sh"),
				"-node", "rabbit@host",
				"-new-rabbitmq-version", "3.4.3.1",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithNonZero()
		itDoesntCallStopApp()

		It("logs connection attempt to node", func() {
			Eventually(session.Out).Should(gbytes.Say("Trying to connect to rabbit@host..."))
		})

		It("logs connection retry to node", func() {
			Eventually(session.Out).Should(gbytes.Say(`Failed to connect to rabbit@host after \d retries, retrying in \d+\.\d+ms`))
		})

		It("does not log connection retry to node after retry timeout is exceeded", func() {
			Consistently(session.Out, 2*time.Second).ShouldNot(gbytes.Say("Failed to connect to rabbit@host after 3 retries, retrying in -1ns"))
		})

		It("logs to stderr, because we're in an unsafe state", func() {
			Eventually(session.Err).Should(gbytes.Say("Unable to connect to node rabbit@host after 3 retries within 1s: Unable to reach epmd and host seems down"))
		})
	})

	Context("When the stop_app fails", func() {
		BeforeEach(func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())

			args = []string{
				"-rabbitmqctl-path", filepath.Join(cwd, "..", "rabbitmqctl", "test-assets", "rabbitmqctl-stop_app-fails.sh"),
				"-node", "rabbit@host",
				"-new-rabbitmq-version", "3.5.6",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithNonZero()
		itCallsStopApp()

		It("logs that it failed to stop RabbitMQ", func() {
			Eventually(session.Err).Should(gbytes.Say("Failed to stop RabbitMQ"))
		})
	})

	Context("When the rabbitmqctl-path is not provided", func() {
		BeforeEach(func() {
			args = []string{
				"-node", "node",
				"-new-rabbitmq-version", "0.0.1",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithNonZero()

		It("provides a meaningful error", func() {
			Eventually(session.Err).Should(gbytes.Say("Missing -rabbitmqctl-path flag"))
		})
	})

	Context("When the node is not provided", func() {
		BeforeEach(func() {
			args = []string{
				"-rabbitmqctl-path", "/tmp/rabbitmqctl",
				"-new-rabbitmq-version", "0.0.1",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithNonZero()

		It("provides a meaningful error", func() {
			Eventually(session.Err).Should(gbytes.Say("Missing -node flag"))
		})
	})

	Context("When the new-rabbitmq-version is not provided", func() {
		BeforeEach(func() {
			args = []string{
				"-rabbitmqctl-path", "/tmp/rabbitmqctl",
				"-node", "node",
				"-new-erlang-version", "17",
			}
		})

		itExitsWithNonZero()

		It("provides a meaningful error", func() {
			Eventually(session.Err).Should(gbytes.Say("Missing -new-rabbitmq-version flag"))
		})
	})

	Context("When the new-erlang-version argument is not provided", func() {
		BeforeEach(func() {
			args = []string{
				"-rabbitmqctl-path", "/tmp/rabbitmqctl",
				"-node", "node",
				"-new-rabbitmq-version", "3.4.3.1",
			}
		})

		itExitsWithNonZero()

		It("provides a meaningful error", func() {
			Eventually(session.Err).Should(gbytes.Say("Missing -new-erlang-version flag"))
		})
	})
})
