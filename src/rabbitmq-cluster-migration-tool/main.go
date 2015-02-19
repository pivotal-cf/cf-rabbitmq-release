package main

import (
	"log"
	"os"

	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/mapping"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/parsers"
	"github.com/pivotal-cf/cf-rabbitmq-release/src/rabbitmq-cluster-migration-tool/rabbit"
)

func main() {
	if len(os.Args) != 3 {
		log.Fatal("USAGE: <migration_dir_path> <cluster_state_file_path>")
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

	selfIPFilepath := migrationDirPath + "/self_ip"
	selfIP, err := parsers.ParseSelfIPFile(selfIPFilepath)
	if err != nil {
		log.Fatalf("could not parse file %s (%s)", selfIPFilepath, err.Error())
	}

	selfNodeName := oldIPAddressesWithNodeNames.NodeNameByIP(selfIP)
	if selfNodeName == "" {
		log.Fatalf("could not resolve old node name for IP address %s in file %s", selfIP, oldErlInetRcFilepath)
	}

	clusterStateFilePath := os.Args[2]
	renameNodes(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames, selfNodeName, clusterStateFilePath)
}

func renameNodes(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames parsers.IPAddressesWithNodeNames, selfNodeName, clusterStateFilePath string) {
	nodeMappings := mapping.NodeNames(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames)
	if len(nodeMappings) == 0 {
		log.Print("Nothing to be renamed, exiting...")
		os.Exit(0)
	}

	ctlRunner := rabbit.NewCtlRunner()
	err := ctlRunner.RenameClusterNodes(selfNodeName, nodeMappings)

	if err != nil {
		log.Fatalf("failed to execute rename_cluster_node command (err: %s)", err.Error())
	}

	err = rabbit.UpdateStateFile(nodeMappings, clusterStateFilePath)
	if err != nil {
		log.Fatalf("failed to update cluster state file (err: %s)", err.Error())
	}
}
