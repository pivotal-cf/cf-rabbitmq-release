package parsers_test

import (
	"io/ioutil"
	"path/filepath"

	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/parsers"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("ErlInetrc", func() {

	It("can parse the ipsWithNodeNames and ips from a given file", func() {
		file, err := filepath.Abs("../assets/erl_inetrc_old")
		Expect(err).ToNot(HaveOccurred())

		ipsWithNodeNames, err := parsers.ParseErlInetRcFile(file)
		Expect(err).ToNot(HaveOccurred())
		a := parsers.IPAddressesWithNodeNames{
			"172.16.87.39": "node0",
			"172.16.87.51": "node1",
			"172.16.87.40": "node2",
			"172.16.87.52": "node3",
		}
		Expect(ipsWithNodeNames).To(Equal(a))
	})

	It("returns an error there are no hosts in the file", func() {
		file, err := ioutil.TempFile("/tmp", "erl_inetrc")
		Expect(err).ToNot(HaveOccurred())

		_, err = parsers.ParseErlInetRcFile(file.Name())
		Expect(err).To(MatchError("no hosts provided in erl_inetrc file"))
	})

	It("returns an error if the file can't be found", func() {
		_, err := parsers.ParseErlInetRcFile("/badfilepath")
		Expect(err).To(HaveOccurred())
	})

	Context("when the file has been successfully parsed", func() {

		var ipsWithNodeNames parsers.IPAddressesWithNodeNames

		BeforeEach(func() {
			file, err := filepath.Abs("../assets/erl_inetrc_old")
			Expect(err).ToNot(HaveOccurred())

			ipsWithNodeNames, err = parsers.ParseErlInetRcFile(file)
			Expect(err).ToNot(HaveOccurred())
		})

		It("can provide the hostname given the ip address", func() {
			nodeName := ipsWithNodeNames.NodeNameByIP("172.16.87.39")
			Expect(nodeName).To(Equal("node0"))
		})

		It("returns an empty string if the ip address is not found", func() {
			nodeName := ipsWithNodeNames.NodeNameByIP("10.10.10.10")
			Expect(nodeName).To(BeEmpty())
		})
	})
})
