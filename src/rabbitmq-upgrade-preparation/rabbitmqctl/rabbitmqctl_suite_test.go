package rabbitmqctl_test

import (
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	"testing"
)

func TestRabbitmqctl(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Rabbitmqctl Suite")
}
