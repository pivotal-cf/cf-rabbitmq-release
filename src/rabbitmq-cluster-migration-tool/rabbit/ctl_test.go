package rabbit_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/mapping"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/rabbit"
)

type FakeShell struct {
	Command   string
	Args      []string
	NodePairs []string
}

func (s *FakeShell) Run(command string, args []string) error {
	s.Command = command
	s.Args = args
	s.NodePairs = []string{}
	//the nodes get renamed in pairs, we want to test the pairs are correct
	for i := 3; i < len(args); i += 2 {
		s.NodePairs = append(s.NodePairs, args[i]+args[i+1])
	}
	return nil
}

var _ = Describe("Ctl", func() {

	nodeMapping := mapping.NodeMapping{
		"node0": "new1",
		"node1": "new3",
		"node2": "new5",
	}

	It("runs the correct rename_cluster command", func() {
		selfNode := "node0"

		fakeShellRunner := FakeShell{}
		ctlRunner := rabbit.CtlRunner{ShellRunner: &fakeShellRunner}
		err := ctlRunner.RenameClusterNodes(selfNode, nodeMapping)
		Expect(err).ToNot(HaveOccurred())

		Expect(fakeShellRunner.Args[:3]).To(Equal([]string{
			"-n",
			"rabbit@node0",
			"rename_cluster_node",
		}))

		Expect(fakeShellRunner.NodePairs).To(ConsistOf([]string{
			"rabbit@node1rabbit@new3",
			"rabbit@node2rabbit@new5",
			"rabbit@node0rabbit@new1",
		}))
		Expect(fakeShellRunner.Command).To(Equal("rabbitmqctl"))
	})

	It("returns an error if the self node is empty", func() {
		selfNode := ""

		fakeShellRunner := FakeShell{}
		ctlRunner := rabbit.CtlRunner{ShellRunner: &fakeShellRunner}
		err := ctlRunner.RenameClusterNodes(selfNode, nodeMapping)

		Expect(err).To(MatchError("you must provide a non-empty self node"))

	})

	It("returns an error if provided with an empty node mapping", func() {
		nodeMapping := mapping.NodeMapping{}
		selfNode := "node0"

		fakeShellRunner := FakeShell{}
		ctlRunner := rabbit.CtlRunner{ShellRunner: &fakeShellRunner}
		err := ctlRunner.RenameClusterNodes(selfNode, nodeMapping)

		Expect(err).To(MatchError("you must provide a non-empty node mapping"))
	})

})
