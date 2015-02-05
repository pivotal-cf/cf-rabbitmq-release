package parsers

import (
	"errors"
	"io/ioutil"
	"net"
	"strings"
)

func ParseSelfIPFile(filepath string) (string, error) {
	ip, err := ioutil.ReadFile(filepath)
	if err != nil {
		return "", err
	}

	ipString := strings.TrimSpace(string(ip))
	if net.ParseIP(ipString) == nil {
		return "", errors.New("bad ip address in self_ip file")
	}

	return ipString, nil
}
