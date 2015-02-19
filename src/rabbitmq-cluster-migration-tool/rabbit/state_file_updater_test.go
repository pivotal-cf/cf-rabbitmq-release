package rabbit_test

import (
	"io/ioutil"
	"path/filepath"
)

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/mapping"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/rabbit"
)

var _ = Describe("State File Updater", func() {
	var clusterStateFilePath string

	BeforeEach(func() {
		clusterStateFilePath = "/tmp/cluster_state_file"
		file, err := filepath.Abs("../assets/cluster_state_file_old")

		stateFileContents, err := ioutil.ReadFile(file)
		Expect(err).NotTo(HaveOccurred())

		err = ioutil.WriteFile(clusterStateFilePath, stateFileContents, 0644)
		Expect(err).NotTo(HaveOccurred())
	})

	It("updates the node names in the state file", func() {
		nodeMappings := mapping.NodeMapping{
			"oldhost1": "newhost1",
			"oldhost2": "newhost2",
		}

		rabbit.UpdateStateFile(nodeMappings, clusterStateFilePath)

		updatedStateFileContents, err := ioutil.ReadFile(clusterStateFilePath)
		Expect(err).NotTo(HaveOccurred())

		expectedStateFile, err := filepath.Abs("../assets/cluster_state_file_new")
		Expect(err).NotTo(HaveOccurred())
		expectedStateFileContents, err := ioutil.ReadFile(expectedStateFile)
		Expect(err).NotTo(HaveOccurred())

		Expect(updatedStateFileContents).To(Equal(expectedStateFileContents))
	})
})
