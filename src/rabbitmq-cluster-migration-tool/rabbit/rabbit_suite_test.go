package rabbit_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"testing"
)

func TestRabbit(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Rabbit Suite")
}
