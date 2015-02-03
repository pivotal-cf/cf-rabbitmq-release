package configuration_test

import (
	"os"
	"path/filepath"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	. "github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/configuration"
)

var _ = Describe("migrating a legacy configuration", func() {

	mnesiaDir := filepath.Join("/", "tmp", "mnesia")
	legacyMnesiaDbDir := filepath.Join(mnesiaDir, "rabbit@node0")
	genericMnesiaDbDir := filepath.Join(mnesiaDir, "db")

	Context("when there is no legacy configuration or generic configuration", func() {

		BeforeEach(func() {
			os.RemoveAll(mnesiaDir)
		})

		It("returns a useful error", func() {
			migrator := NewMigrator(legacyMnesiaDbDir)
			err := migrator.MigrateConfiguration()
			Ω(err).Should(MatchError("No Mnesia DB DIR found"))
		})
	})

	Context("when there is no legacy configuration and generic configuration is present", func() {

		BeforeEach(func() {
			os.RemoveAll(mnesiaDir)
			os.MkdirAll(genericMnesiaDbDir, 0744)
		})

		AfterEach(func() {
			os.RemoveAll(mnesiaDir)
		})

		It("raises an error alerting that the db has been migrated", func() {
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

		legacyConfigFile := filepath.Join(legacyMnesiaDbDir + ".config")
		legacyPluginsExplandDir := filepath.Join(legacyMnesiaDbDir + "-plugins-expand")

		BeforeEach(func() {
			mnesiaDbSubDir := filepath.Join(legacyMnesiaDbDir, "subdir")
			os.RemoveAll(genericMnesiaDbDir)
			os.MkdirAll(legacyMnesiaDbDir, 0744)
			os.MkdirAll(mnesiaDbSubDir, 0744)
			os.Create(legacyConfigFile)
			os.MkdirAll(legacyPluginsExplandDir, 0744)
		})

		AfterEach(func() {
			os.RemoveAll(mnesiaDir)
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

			subDirPath := filepath.Join(genericMnesiaDbDir, "subdir")
			_, err = os.Stat(subDirPath)
			Ω(err).ShouldNot(HaveOccurred())
		})

		It("moves the .config file to a generic location", func() {
			migrator := NewMigrator(legacyMnesiaDbDir)
			err := migrator.MigrateConfiguration()
			Ω(err).ShouldNot(HaveOccurred())

			_, err = os.Stat(legacyConfigFile)
			Ω(err).Should(HaveOccurred())

			_, err = os.Stat(filepath.Join(mnesiaDir, "cluster.config"))
			Ω(err).ShouldNot(HaveOccurred())
		})

		It("moves the plugins-expand dir to a generic location", func() {
			migrator := NewMigrator(legacyMnesiaDbDir)
			err := migrator.MigrateConfiguration()
			Ω(err).ShouldNot(HaveOccurred())

			_, err = os.Stat(legacyPluginsExplandDir)
			Ω(err).Should(HaveOccurred())

			_, err = os.Stat(filepath.Join(mnesiaDir, "plugins-expand"))
			Ω(err).ShouldNot(HaveOccurred())
		})
	})
})
