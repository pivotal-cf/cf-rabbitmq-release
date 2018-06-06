package versions_test

import (
	. "rabbitmq-upgrade-preparation/versions"

	. "github.com/onsi/ginkgo/extensions/table"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Versions", func() {
	Describe("RabbitVersions", func() {
		DescribeTable("upgrade preparation required",
			func(deployedVersion, desiredVersion string) {
				versions := &RabbitVersions{Desired: desiredVersion, Deployed: deployedVersion}
				Expect(versions.PreparationRequired()).To(BeTrue())
			},
			Entry("3.4.4.1 to 3.6.3 requires upgrade preparation", "3.4.4.1", "3.6.3"),
			Entry("3.4.4.1 to 3.6.1.904 requires upgrade preparation", "3.4.4.1", "3.6.1.904"),
			Entry("3.5.7 to 3.6.3 requires upgrade preparation", "3.5.7", "3.6.3"),
			Entry("3.6.1.904 to 3.6.6 requires upgrade preparation", "3.6.1.904", "3.6.6"),
			Entry("3.6.3 to 3.6.6 requires upgrade preparation", "3.6.3", "3.6.6"),
			Entry("3.6.5 to 3.6.6 requires upgrade preparation", "3.6.5", "3.6.6"),
			Entry("3.6.3 to 3.6.7 requires upgrade preparation", "3.6.3", "3.6.7"),
			Entry("3.6.5 to 3.6.7 requires upgrade preparation", "3.6.5", "3.6.7"),
			Entry("3.6.5 to 3.7.0 requires upgrade preparation", "3.6.5", "3.7.0"),
			Entry("3.6.6 to 3.7.0 requires upgrade preparation", "3.6.6", "3.7.0"),
			Entry("3.6.6 to 3.6.7 requires upgrade preparation", "3.6.6", "3.6.7"),
			Entry("3.6.6 to 3.6.8 requires upgrade preparation", "3.6.6", "3.6.8"),
			Entry("3.6.6 to 3.6.9 requires upgrade preparation", "3.6.6", "3.6.9"),
		)

		DescribeTable("upgrade preparation not required",
			func(deployedVersion, desiredVersion string) {
				versions := &RabbitVersions{Desired: desiredVersion, Deployed: deployedVersion}
				Expect(versions.PreparationRequired()).To(BeFalse())
			},
			Entry("3.6.1.904 to 3.6.1.904 requires no upgrade preparation", "3.6.1.904", "3.6.1.904"),
			Entry("3.6.1.904 to 3.6.3 requires no upgrade preparation", "3.6.1.904", "3.6.3"),
			Entry("3.6.3 to 3.6.3 requires no upgrade preparation", "3.6.3", "3.6.3"),
			Entry("3.6.3 to 3.6.5 requires no upgrade preparation", "3.6.3", "3.6.5"),
			Entry("3.6.5 to 3.6.5 requires no upgrade preparation", "3.6.5", "3.6.5"),
			Entry("3.6.6 to 3.6.6 requires no upgrade preparation", "3.6.6", "3.6.6"),
			Entry("3.6.9 to 3.6.9 requires no upgrade preparation", "3.6.9", "3.6.9"),
			Entry("3.6.6.903 to 3.6.7 requires no upgrade preparation", "3.6.6.903", "3.6.7"),
			Entry("3.7.0 to 3.7.0 requires no upgrade preparation", "3.7.0", "3.7.0"),
		)

		Describe("UpgradeMessage", func() {
			It("returns the upgrade message", func() {
				versions := &RabbitVersions{Desired: "3.6.6-rc1", Deployed: "3.6.5"}

				Expect(versions.UpgradeMessage()).To(Equal("It looks like you are trying to upgrade from RabbitMQ 3.6.5 to RabbitMQ 3.6.6-rc1"))
			})
		})

		Describe("malformed versions", func() {
			Context("when the desired version of RabbitMQ is malformed", func() {
				It("returns an error", func() {
					versions := &RabbitVersions{Desired: "malformed-version", Deployed: "3.6.5"}

					_, err := versions.PreparationRequired()
					Expect(err).To(MatchError("The desired version of RabbitMQ is malformed: malformed-version"))
				})
			})

			Context("when the deployed version of RabbitMQ is malformed", func() {
				It("returns an error", func() {
					versions := &RabbitVersions{Desired: "3.6.5", Deployed: "malformed-version"}

					_, err := versions.PreparationRequired()
					Expect(err).To(MatchError("The deployed version of RabbitMQ is malformed: malformed-version"))
				})
			})
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

		Describe("UpgradeMessage", func() {
			It("returns the upgrade message", func() {
				versions := &ErlangVersions{Desired: "18.3.4.1", Deployed: "18.3"}

				Expect(versions.UpgradeMessage()).To(Equal("It looks like you are trying to upgrade from Erlang 18.3 to Erlang 18.3.4.1"))
			})
		})

	})

})
