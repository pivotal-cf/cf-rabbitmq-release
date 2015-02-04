package mapping_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/mapping"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/parsers"
)

var _ = Describe("IpAdddressNodeNames", func() {
	var oldIPAddressesWithNodeNames parsers.IPAddressesWithNodeNames

	BeforeEach(func() {
		oldIPAddressesWithNodeNames = parsers.IPAddressesWithNodeNames{
			"127.0.0.1": "node0",
			"127.0.0.3": "node2",
			"127.0.0.2": "node1",
		}
	})

	It("returns a map with the node name changes", func() {
		newIPAddressesWithNodeNames := parsers.IPAddressesWithNodeNames{
			"127.0.0.3": "test2",
			"127.0.0.2": "test1",
			"127.0.0.1": "test0",
		}

		expectedDiff := mapping.NodeMapping{
			"node0": "test0",
			"node1": "test1",
			"node2": "test2",
		}

		nodeNamesDiff := mapping.NodeNames(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames)
		Expect(nodeNamesDiff).To(Equal(expectedDiff))
	})

	Context("when a node was deleted in the new configuration", func() {

		It("returns a map with the node name changes", func() {
			newIPAddressesWithNodeNames := parsers.IPAddressesWithNodeNames{
				"127.0.0.3": "test2",
				"127.0.0.1": "test0",
			}

			expectedDiff := mapping.NodeMapping{
				"node0": "test0",
				"node2": "test2",
			}

			nodeNamesDiff := mapping.NodeNames(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames)
			Expect(nodeNamesDiff).To(Equal(expectedDiff))
		})
	})

	Context("when a node name didn't change in the new configuration", func() {

		It("returns a map with the node name changes", func() {
			newIPAddressesWithNodeNames := parsers.IPAddressesWithNodeNames{
				"127.0.0.3": "test2",
				"127.0.0.2": "node1",
				"127.0.0.1": "test0",
			}

			expectedDiff := mapping.NodeMapping{
				"node0": "test0",
				"node2": "test2",
			}

			nodeNamesDiff := mapping.NodeNames(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames)
			Expect(nodeNamesDiff).To(Equal(expectedDiff))
		})
	})
})
