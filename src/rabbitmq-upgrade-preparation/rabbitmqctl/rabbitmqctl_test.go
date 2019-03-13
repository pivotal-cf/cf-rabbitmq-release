package rabbitmqctl_test

import (
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"

	. "rabbitmq-upgrade-preparation/rabbitmqctl"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Rabbitmqctl", func() {
	var tmpFile string

	BeforeEach(func() {
		tmpDir, err := ioutil.TempDir("", "rabbitmq-upgrade-tests")
		Expect(err).NotTo(HaveOccurred())
		tmpFile = filepath.Join(tmpDir, "output")

		os.Setenv("TEST_OUTPUT_FILE", tmpFile)
	})

	AfterEach(func() {
		os.Unsetenv("TEST_OUTPUT_FILE")
	})

	Describe("StopApp", func() {
		It("passes the node to the stop_app command", func() {
			cwd, _ := os.Getwd()
			path := filepath.Join(cwd, "test-assets", "rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh")
			err := New(path).StopApp("some-node")
			Expect(err).NotTo(HaveOccurred())

			contents, err := ioutil.ReadFile(tmpFile)
			Expect(err).NotTo(HaveOccurred())

			Expect(string(contents)).To(ContainSubstring("stop_app -n some-node\n"))
		})

		It("returns an error when stop_app fails", func() {
			cwd, _ := os.Getwd()
			path := filepath.Join(cwd, "test-assets", "rabbitmqctl-stop_app-fails.sh")
			err := New(path).StopApp("some-node")

			Expect(err).To(MatchError(errors.New("Failed to stop RabbitMQ app: exit status 3")))
		})
	})

	Describe("Shutdown", func() {
		var tmpFile string

		BeforeEach(func() {
			tmpDir, _ := ioutil.TempDir("", "rabbitmq-upgrade-tests")
			tmpFile = filepath.Join(tmpDir, "shutdown-cluster-file")

			os.Setenv("TEST_OUTPUT_FILE", tmpFile)
		})

		AfterEach(func() {
			os.Remove(tmpFile)
			os.Unsetenv("TEST_OUTPUT_FILE")
		})

		callStopOnNode := func(tmpFile, node string) {
			contents, err := ioutil.ReadFile(tmpFile)

			fmt.Printf(string(contents))
			Expect(err).NotTo(HaveOccurred())
			Expect(strings.Count(string(contents), fmt.Sprintf("shutdown -n %s --no-wait\n", node))).To(Equal(1))
		}

		It("passes the node to the stop command", func() {
			cwd, err := os.Getwd()
			Expect(err).NotTo(HaveOccurred())
			path := filepath.Join(cwd, "test-assets", "rabbitmqctl-echo")

			err = New(path).Shutdown("some-node")
			Expect(err).NotTo(HaveOccurred())

			callStopOnNode(tmpFile, "some-node")
		})

		It("returns an error when stopfails", func() {
			cwd, _ := os.Getwd()
			path := filepath.Join(cwd, "test-assets", "rabbitmqctl-echo-with-fails")
			err := New(path).Shutdown("rabbitmq@node1")

			Expect(err).To(MatchError(ContainSubstring("Failed to shutdown RabbitMQ: exit status 1:\nFail args")))
		})

		It("succeeds when the node not running (exit code 69)", func() {
			cwd, _ := os.Getwd()
			path := filepath.Join(cwd, "test-assets", "rabbitmqctl-stopped-rabbit-node.sh")
			err := New(path).Shutdown("rabbitmq@node1")
			Expect(err).NotTo(HaveOccurred())
		})
	})

	Describe("Status", func() {
		statusForScriptWithNode := func(script, node string) (RabbitMQCtlStatus, *Error) {
			cwd, _ := os.Getwd()
			path := filepath.Join(cwd, "test-assets", script)
			status, err := New(path).Status(node)
			var statusErr *Error

			if err != nil {
				statusErr = err.(*Error)
			}

			return status, statusErr
		}

		statusForScript := func(script string) (RabbitMQCtlStatus, *Error) {
			return statusForScriptWithNode(script, "some-node")
		}

		It("passes the node to the status command", func() {
			_, err := statusForScriptWithNode("rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh", "my-node")
			Expect(err).NotTo(HaveOccurred())

			contents, ioErr := ioutil.ReadFile(tmpFile)
			Expect(ioErr).NotTo(HaveOccurred())

			Expect(string(contents)).To(ContainSubstring("status -n my-node\n"))
		})

		Context("Status cannot be retrieved", func() {
			It("returns UnreachableHost when the call returns nonzero due to timeout", func() {
				_, err := statusForScript("rabbitmqctl-host-down.sh")
				Expect(err).To(MatchError("Unable to reach epmd and host seems down"))
				Expect(err.Status).To(Equal(UnreachableHost))
			})

			It("returns a UnreachableEpmdError when the call returns nonzero due to epmd not running", func() {
				_, err := statusForScript("rabbitmqctl-epmd-down-host-up.sh")
				Expect(err).To(MatchError("Unable to reach epmd but host seems up"))
				Expect(err.Status).To(Equal(UnreachableEpmd))
			})

			It("returns a StoppedRabbitNodeError when there's no 'rabbit' node running", func() {
				_, err := statusForScript("rabbitmqctl-stopped-rabbit-node.sh")
				Expect(err).To(MatchError("No rabbit node running"))
				Expect(err.Status).To(Equal(StoppedRabbitNode))
			})

			It("returns a generic error when there is some unspecified error", func() {
				_, err := statusForScript("rabbitmqctl-unknown-error.sh")
				Expect(err).To(MatchError("Unknown error"))
				Expect(err.Status).To(Equal(Unknown))
			})
		})

		Context("RabbitMQ application is running", func() {
			It("doesn't return an error", func() {
				_, err := statusForScript("rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh")
				Expect(err).NotTo(HaveOccurred())
			})

			It("returns a status with the version of RabbitMQ", func() {
				status, _ := statusForScript("rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh")
				version, _ := status.RabbitMQVersion()
				Expect(version).To(Equal("3.4.3.1"))
			})

			It("returns ok from a RabbitMQ version query", func() {
				status, _ := statusForScript("rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh")
				_, ok := status.RabbitMQVersion()

				Expect(ok).To(BeTrue())
			})
		})

		Context("RabbitMQ application is not running", func() {
			It("doesn't return an error", func() {
				_, err := statusForScript("rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh")
				Expect(err).NotTo(HaveOccurred())
			})

			It("returns not ok from a RabbitMQ version query", func() {
				status, _ := statusForScript("rabbitmqctl-rabbitmq-app-stopped.sh")
				_, ok := status.RabbitMQVersion()

				Expect(ok).To(BeFalse())
			})
		})

		Context("when the erlang version is present", func() {
			It("returns a status with only major version of Erlang", func() {
				status, _ := statusForScript("rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh")
				version, _ := status.ErlangVersion()
				Expect(version).To(Equal("17"))
			})

			It("doesn't return an error from an Erlang version query", func() {
				status, _ := statusForScript("rabbitmqctl-erlang-17-rabbit-3.4.3.1.sh")
				_, err := status.ErlangVersion()
				Expect(err).NotTo(HaveOccurred())
			})
		})

		Context("when the erlang version is not present", func() {
			It("returns an error from an Erlang version query", func() {
				status, _ := statusForScript("rabbitmqctl-erlang-version-not-available.sh")
				_, err := status.ErlangVersion()
				Expect(err).To(MatchError(errors.New("No Erlang version available")))
			})
		})
	})
})
