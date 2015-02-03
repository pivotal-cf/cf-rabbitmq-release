package mapping_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestDiff(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Mapping Suite")
}
