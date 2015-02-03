package integration_test

import (
	"os/exec"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Migration Tool", func() {
	It("can be executed", func() {
		rabbitClusterMigrationToolPath := buildExecutable("github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool")
		migrationToolCommand := exec.Command(rabbitClusterMigrationToolPath)
		err := migrationToolCommand.Run()

		Ω(err).ShouldNot(HaveOccurred())
	})
})
