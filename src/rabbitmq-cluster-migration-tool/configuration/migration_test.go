package configuration_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/pivotal-cf/cf-rabbit-release/src/rabbitmq-cluster-migration-tool/configuration"
)

var _ = Describe("migrating a legacy configuration", func() {

	legacyMnesiaDbDir := filepath.Join("/", "tmp", "legacyMnesiaDbDir")
	genericMnesiaDbDir := filepath.Join("/", "tmp", "db")

	Context("when there is no legacy configuration or generic configuration", func() {
		It("returns a useful error", func() {
			migrator := NewMigrator(legacyMnesiaDbDir)
			err := migrator.MigrateConfiguration()
			Ω(err).Should(MatchError("No Mnesia DB DIR found"))
		})
	})

	Context("when there is no legacy configuration and generic configuration is present", func() {

		BeforeEach(func() {
			os.RemoveAll(legacyMnesiaDbDir)
			os.Mkdir(genericMnesiaDbDir, 0744)
		})

		AfterEach(func() {
			os.RemoveAll(legacyMnesiaDbDir)
		})

		It("does nothing", func() {
			migrator := NewMigrator(legacyMnesiaDbDir)
			err := migrator.MigrateConfiguration()
			Ω(err).Should(MatchError("Already migrated Mnesia DB DIR"))

			_, err = os.Stat(genericMnesiaDbDir)
			Ω(err).ShouldNot(HaveOccurred())

			_, err = os.Stat(legacyMnesiaDbDir)
			Ω(err).Should(HaveOccurred())
		})
	})

	Context("when there is a legacy configuration", func() {

		mnesiaDbSubDir := filepath.Join(legacyMnesiaDbDir, "subdir")

		BeforeEach(func() {
			os.RemoveAll(genericMnesiaDbDir)
			os.Mkdir(legacyMnesiaDbDir, 0744)
			os.Mkdir(mnesiaDbSubDir, 0744)
		})

		AfterEach(func() {
			os.RemoveAll(legacyMnesiaDbDir)
			os.RemoveAll(genericMnesiaDbDir)
		})

		It("moves the mnesia DB folder to a generic location", func() {
			migrator := NewMigrator(legacyMnesiaDbDir)
			err := migrator.MigrateConfiguration()
			Ω(err).ShouldNot(HaveOccurred())

			_, err = os.Stat(genericMnesiaDbDir)
			Ω(err).ShouldNot(HaveOccurred())

			_, err = os.Stat(legacyMnesiaDbDir)
			Ω(os.IsNotExist(err)).Should(BeTrue())

		})

		It("moves the mnesia DB sub folders and files to the generic location", func() {
			migrator := NewMigrator(legacyMnesiaDbDir)
			err := migrator.MigrateConfiguration()
			Ω(err).ShouldNot(HaveOccurred())

			path := filepath.Join(genericMnesiaDbDir, "subdir")
			_, err = os.Stat(path)
			Ω(err).ShouldNot(HaveOccurred())
		})
	})
})
