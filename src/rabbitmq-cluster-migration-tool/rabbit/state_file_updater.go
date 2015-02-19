package rabbit

import (
	"io/ioutil"
	"strings"

	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/mapping"
)

func UpdateStateFile(nodeMappings mapping.NodeMapping, stateFilePath string) error {
	stateFileContentsRaw, err := ioutil.ReadFile(stateFilePath)
	if err != nil {
		return err
	}

	stateFileContents := string(stateFileContentsRaw)
	for oldNodeName, newNodeName := range nodeMappings {
		stateFileContents = strings.Replace(stateFileContents, oldNodeName, newNodeName, -1)
	}

	err = ioutil.WriteFile(stateFilePath, []byte(stateFileContents), 0644)
	return err
}
