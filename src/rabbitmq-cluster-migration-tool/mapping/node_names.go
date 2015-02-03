package mapping

import (
	"../parsers"
)

func NodeNames(oldIPAddressesWithNodeNames, newIPAddressesWithNodeNames parsers.IPAddressesWithNodeNames) map[string]string {
	mappingResult := map[string]string{}
	for ip, node := range oldIPAddressesWithNodeNames {
		if newNodeName := newIPAddressesWithNodeNames.NodeNameByIp(ip); newNodeName != "" {
			if newNodeName != node {
				mappingResult[node] = newNodeName
			}
		}
	}
	return mappingResult
}
