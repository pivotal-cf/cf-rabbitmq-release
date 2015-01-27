package configuration

import (
	"errors"
	"os"
	"path/filepath"
)

type Migrator struct {
	mnesiaDbDir string
}

func NewMigrator(mnesiaDbDir string) *Migrator {
	return &Migrator{
		mnesiaDbDir: mnesiaDbDir,
	}
}

func (migrator *Migrator) MigrateConfiguration() error {

	newPath := filepath.Join(filepath.Dir(migrator.mnesiaDbDir), "db")

	if fileAvailable(newPath) {
		return errors.New("Already migrated Mnesia DB DIR")
	}

	if fileAvailable(migrator.mnesiaDbDir) {
		return os.Rename(migrator.mnesiaDbDir, newPath)
	} else {
		return errors.New("No Mnesia DB DIR found")
	}

}

func fileAvailable(filePath string) bool {
	_, err := os.Stat(filePath)
	if err != nil {
		return false
	}
	return true
}
