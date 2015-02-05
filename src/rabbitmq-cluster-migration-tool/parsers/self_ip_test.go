package parsers_test

import (
	"path/filepath"

	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/parsers"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("SelfIp", func() {
	It("parses the IP address from the provided file", func() {
		filepath, err := filepath.Abs("../assets/self_ip")
		Expect(err).ToNot(HaveOccurred())
		ipAddress, err := parsers.ParseSelfIPFile(filepath)
		Expect(err).ToNot(HaveOccurred())
		Expect(ipAddress).To(Equal("172.16.87.39"))
	})

	It("returns an error if the file is not found", func() {
		_, err := parsers.ParseSelfIPFile("/badfilepath")
		Expect(err).To(HaveOccurred())
	})

	It("returns an error if the ip address is invalid", func() {
		filepath, err := filepath.Abs("../assets/self_ip_invalid")
		Expect(err).ToNot(HaveOccurred())
		_, err = parsers.ParseSelfIPFile(filepath)
		Expect(err).To(MatchError("bad ip address in self_ip file"))
	})

	It("returns an error if there are multiple ip addresses in the file", func() {
		filepath, err := filepath.Abs("../assets/self_ip_multiple_ips")
		Expect(err).ToNot(HaveOccurred())
		_, err = parsers.ParseSelfIPFile(filepath)
		Expect(err).To(MatchError("bad ip address in self_ip file"))
	})
})
