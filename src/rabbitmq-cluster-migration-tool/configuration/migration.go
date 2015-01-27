package configuration

import (
	"errors"
	"os"
	"path/filepath"
)

type Migrator struct {
	mnesiaDbDirPath string
}

func NewMigrator(mnesiaDbDirPath string) *Migrator {
	return &Migrator{
		mnesiaDbDirPath: mnesiaDbDirPath,
	}
}

func (migrator *Migrator) MigrateConfiguration() error {
	if err := migrator.migrateDB(); err != nil {
		return err
	}

	if err := migrator.migrateConfig(); err != nil {
		return err
	}

	if err := migrator.migratePluginsExpand(); err != nil {
		return err
	}

	return nil
}

func fileAvailable(filePath string) bool {
	_, err := os.Stat(filePath)
	if err != nil {
		return false
	}
	return true
}

func (migrator *Migrator) migrateDB() error {
	newDbPath := filepath.Join(filepath.Dir(migrator.mnesiaDbDirPath), "db")

	if fileAvailable(newDbPath) {
		return errors.New("Already migrated Mnesia DB DIR")
	}

	if fileAvailable(migrator.mnesiaDbDirPath) {
		return os.Rename(migrator.mnesiaDbDirPath, newDbPath)
	} else {
		return errors.New("No Mnesia DB DIR found")
	}
}

func (migrator *Migrator) migrateConfig() error {
	configPath := filepath.Join(migrator.mnesiaDbDirPath + ".config")
	newConfigPath := filepath.Join(filepath.Dir(migrator.mnesiaDbDirPath), "cluster.config")

	if fileAvailable(newConfigPath) {
		return errors.New("Already migrated Mnesia config file")
	}

	if fileAvailable(configPath) {
		return os.Rename(configPath, newConfigPath)
	} else {
		return errors.New("Could not find config file to migrate")
	}
}

func (migrator *Migrator) migratePluginsExpand() error {
	configPath := filepath.Join(migrator.mnesiaDbDirPath + "-plugins-expand")
	newConfigPath := filepath.Join(filepath.Dir(migrator.mnesiaDbDirPath), "plugins-expand")

	if fileAvailable(newConfigPath) {
		return errors.New("Already migrated Mnesia plugins-expand DIR")
	}

	if fileAvailable(configPath) {
		return os.Rename(configPath, newConfigPath)
	} else {
		return errors.New("Could not find plugins-expand DIR to migrate")
	}
}
