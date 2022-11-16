package main_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gexec"
)

func TestDropAmqpTraffic(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "RestoreAmqpTraffic Suite")
}

var pathToCmd string

var _ = BeforeSuite(func() {
	var err error
	pathToCmd, err = Build("rabbitmq-admin/amqp-traffic/restore-amqp-traffic")
	Expect(err).NotTo(HaveOccurred())
})

var _ = AfterSuite(func() {
	CleanupBuildArtifacts()
})
