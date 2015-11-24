package versions

import "strings"

type VersionDifference interface {
	PreparationRequired() bool
}

type RabbitVersions struct {
	Desired  string
	Deployed string
}

type ErlangVersions struct {
	Desired  string
	Deployed string
}

func (v *RabbitVersions) PreparationRequired() bool {
	return isMinorOrMajorRabbitUpgrade(versionComponents(v.Desired), versionComponents(v.Deployed))
}

func isMinorOrMajorRabbitUpgrade(desiredRabbitVersionComponents, deployedRabbitVersionComponents []string) bool {
	return desiredRabbitVersionComponents[0] != deployedRabbitVersionComponents[0] ||
		desiredRabbitVersionComponents[1] != deployedRabbitVersionComponents[1]
}

func (v *ErlangVersions) PreparationRequired() bool {
	return isMajorErlangUpgrade(versionComponents(v.Desired), versionComponents(v.Deployed))
}

func isMajorErlangUpgrade(desiredErlangVersionComponents, deployedErlangVersionComponents []string) bool {
	return desiredErlangVersionComponents[0] != deployedErlangVersionComponents[0]
}

func versionComponents(version string) []string {
	return strings.Split(version, ".")
}
