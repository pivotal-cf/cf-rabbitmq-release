package versions_test

import (
	. "github.com/pivotal-cf/rabbitmq-upgrade-preparation/versions"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Versions", func() {
	It("detects a minor version bump in RabbitMQ", func() {
		versions := &RabbitVersions{Desired: "3.5", Deployed: "3.4.3.1"}
		Expect(versions.PreparationRequired()).To(BeTrue())
	})

	It("detects a major version bump in RabbitMQ", func() {
		versions := &RabbitVersions{Desired: "4.4", Deployed: "3.4.3.1"}
		Expect(versions.PreparationRequired()).To(BeTrue())
	})

	It("detects no change required for a patch version bump in RabbitMQ", func() {
		versions := &RabbitVersions{Desired: "3.4.4.1", Deployed: "3.4.3.1"}
		Expect(versions.PreparationRequired()).To(BeFalse())
	})

	It("detects no change required for a hotfix version bump in RabbitMQ", func() {
		versions := &RabbitVersions{Desired: "3.4.3.2", Deployed: "3.4.3.1"}
		Expect(versions.PreparationRequired()).To(BeFalse())
	})

	It("detects a change in Erlang", func() {
		versions := &ErlangVersions{Desired: "spam", Deployed: "eggs"}
		Expect(versions.PreparationRequired()).To(BeTrue())
	})

	It("detects no change in Erlang", func() {
		versions := &ErlangVersions{Desired: "sausage", Deployed: "sausage"}
		Expect(versions.PreparationRequired()).To(BeFalse())
	})
})
