package rabbit_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/mapping"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/rabbit"
)

type FakeShell struct {
	Command string
	Args    []string
}

func (s *FakeShell) Run(command string, args []string) error {
	s.Command = command
	s.Args = args
	return nil
}

var _ = Describe("Ctl", func() {

	nodeMapping := mapping.NodeMapping{
		"node0": "new1",
		"node1": "new3",
		"node2": "new5",
	}

	It("It runs the correct rename_cluster command", func() {
		selfNode := "node0"

		fakeShellRunner := FakeShell{}
		ctlRunner := rabbit.CtlRunner{ShellRunner: &fakeShellRunner}
		err := ctlRunner.RenameClusterNodes(selfNode, nodeMapping)
		Expect(err).ToNot(HaveOccurred())
		Expect(fakeShellRunner.Args).To(ConsistOf([]string{
			"-n",
			"rabbit@node0",
			"rename_cluster_node",
			"'rabbit@node0'",
			"'rabbit@new1'",
			"'rabbit@node1'",
			"'rabbit@new3'",
			"'rabbit@node2'",
			"'rabbit@new5'",
		}))
		Expect(fakeShellRunner.Command).To(Equal("rabbitmqctl"))
	})

	It("Returns an error if the self node is empty", func() {
		selfNode := ""

		fakeShellRunner := FakeShell{}
		ctlRunner := rabbit.CtlRunner{ShellRunner: &fakeShellRunner}
		err := ctlRunner.RenameClusterNodes(selfNode, nodeMapping)

		Expect(err).To(MatchError("you must provide a non-empty self node"))

	})

	It("Returns an error if provided with an empty node mapping", func() {
		nodeMapping := mapping.NodeMapping{}
		selfNode := "node0"

		fakeShellRunner := FakeShell{}
		ctlRunner := rabbit.CtlRunner{ShellRunner: &fakeShellRunner}
		err := ctlRunner.RenameClusterNodes(selfNode, nodeMapping)

		Expect(err).To(MatchError("you must provide a non-empty node mapping"))
	})

})
