package main

import (
	"log"
	"os"

	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/mapping"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/parsers"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/rabbit"
)

func main() {
	if len(os.Args) != 2 {
		log.Fatal("USAGE: <migration_dir_path>")
	}

	migrationDirPath := os.Args[1]
	if _, err := os.Stat(migrationDirPath); os.IsNotExist(err) {
		log.Fatalf("migraiton folder does not exist (dir: %s not found)", migrationDirPath)
	} else if err != nil {
		log.Fatalf("an error occured when handling the dir: %s (err: %s)", migrationDirPath, err.Error())
	}

	oldErlInetRcFilepath := migrationDirPath + "/erl_inetrc_old"
	oldIPAddressesWithNodeNames, err := parsers.ParseErlInetRcFile(oldErlInetRcFilepath)
	if err != nil {
		log.Fatalf("could not parse file %s (%s)", oldErlInetRcFilepath, err.Error())
	}

	newErlInetRcFilepath := migrationDirPath + "/erl_inetrc_new"
	newIPAddressesWithNodeNames, err := parsers.ParseErlInetRcFile(newErlInetRcFilepath)
	if err != nil {
		log.Fatalf("could not parse file %s (%s)", newErlInetRcFilepath, err.Error())
	}

	selfIpFilepath := migrationDirPath + "/self_ip"
	selfIp, err := parsers.ParseSelfIpFile(selfIpFilepath)
	if err != nil {
		log.Fatalf("could not parse file %s (%s)", selfIpFilepath, err.Error())
	}

	selfNodeName := oldIPAddressesWithNodeNames.NodeNameByIp(selfIp)
	if selfNodeName == "" {
		log.Fatalf("could not resolve old node name for IP address %s in file %s", selfIp, oldErlInetRcFilepath)
	}

	renameNodes(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames, selfNodeName)
}

func renameNodes(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames parsers.IPAddressesWithNodeNames, selfNodeName string) {
	nodeMappings := mapping.NodeNames(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames)
	if len(nodeMappings) == 0 {
		os.Exit(0)
	}

	ctlRunner := rabbit.NewCtlRunner()
	err := ctlRunner.RenameClusterNodes(selfNodeName, nodeMappings)

	if err != nil {
		log.Fatalf("failed to execute rename_cluster_node command (err: %s)", err.Error())
	}
}
