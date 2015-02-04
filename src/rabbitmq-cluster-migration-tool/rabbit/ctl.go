package rabbit

import (
	"errors"
	"fmt"
	"strings"

	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/mapping"
)

type AShellRunner interface {
	Run(string, []string) error
}

type CtlRunner struct {
	ShellRunner AShellRunner
}

func NewCtlRunner() *CtlRunner {
	return &CtlRunner{
		ShellRunner: &shell{},
	}
}

func (r *CtlRunner) RenameClusterNodes(selfNode string, nodeMapping mapping.NodeMapping) error {
	command, err := generateRenameClusterNodesCommand(selfNode, nodeMapping)
	if err != nil {
		return err
	}

	return r.ShellRunner.Run("rabbitmqctl", strings.Split(command, " "))
}

func generateRenameClusterNodesCommand(selfNode string, nodeMapping mapping.NodeMapping) (string, error) {
	if len(strings.TrimSpace(selfNode)) == 0 {
		return "", errors.New("you must provide a non-empty self node")
	}

	if len(nodeMapping) == 0 {
		return "", errors.New("you must provide a non-empty node mapping")
	}

	command := fmt.Sprintf("-n rabbit@%s rename_cluster_node", selfNode)
	for oldNodeName, newNodeName := range nodeMapping {
		command = fmt.Sprintf("%s rabbit@%s rabbit@%s", command, oldNodeName, newNodeName)
	}
	return command, nil
}
