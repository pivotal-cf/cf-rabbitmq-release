package main

import (
	"fmt"

	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/configuration"
)

func main() {
	migrator := configuration.NewMigrator("")
	err := migrator.MigrateConfiguration()

	if err != nil {
		fmt.Printf("Finished with error: %s", err)
	}

}
