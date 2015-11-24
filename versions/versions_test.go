package versions_test

import (
	. "github.com/pivotal-cf/rabbitmq-upgrade-preparation/versions"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Versions", func() {
	Describe("RabbitVersions", func() {
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
	})

	Describe("ErlangVersions", func() {
		It("detects a change in Erlang if there is a major version bump", func() {
			versions := &ErlangVersions{Desired: "18.1", Deployed: "17"}
			Expect(versions.PreparationRequired()).To(BeTrue())
		})

		It("detects no change in Erlang if there is a minor change", func() {
			versions := &ErlangVersions{Desired: "18.1", Deployed: "18"}
			Expect(versions.PreparationRequired()).To(BeFalse())
		})

		It("detects no change in Erlang if there is no change", func() {
			versions := &ErlangVersions{Desired: "18.1", Deployed: "18.1"}
			Expect(versions.PreparationRequired()).To(BeFalse())
		})
	})
})
