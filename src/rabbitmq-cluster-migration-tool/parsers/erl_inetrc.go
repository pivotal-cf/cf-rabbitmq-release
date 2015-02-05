package parsers

import (
	"bufio"
	"errors"
	"os"
	"regexp"
	"strings"
)

type IPAddressesWithNodeNames map[string]string

func (i IPAddressesWithNodeNames) NodeNameByIP(ip string) string {
	return i[ip]
}

func ParseErlInetRcFile(filepath string) (IPAddressesWithNodeNames, error) {
	file, err := os.Open(filepath)

	if err != nil {
		return nil, err
	}

	defer file.Close()

	reader := bufio.NewReader(file)
	scanner := bufio.NewScanner(reader)

	ipAddressesWithNodeNames := IPAddressesWithNodeNames{}
	for scanner.Scan() {
		re := regexp.MustCompile("{host, {(.*)}, \\[\"(.*)\"\\]}\\.")
		data := re.FindAllStringSubmatch(scanner.Text(), -1)
		if len(data) >= 1 && len(data[0]) == 3 {
			ipAddress := strings.Replace(data[0][1], ",", ".", -1)
			nodeName := data[0][2]
			ipAddressesWithNodeNames[ipAddress] = nodeName
		}
		//parse the text
	}

	if len(ipAddressesWithNodeNames) == 0 {
		err = errors.New("no hosts provided in erl_inetrc file")
	}

	return ipAddressesWithNodeNames, err
}
