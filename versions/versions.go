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
	return isMinorOrMajorRabbitUpgrade(v.desiredVersionComponents(), v.deployedVersionComponents())
}

func (v *RabbitVersions) desiredVersionComponents() []string {
	return strings.Split(v.Desired, ".")
}

func (v *RabbitVersions) deployedVersionComponents() []string {
	return strings.Split(v.Deployed, ".")
}

func isMinorOrMajorRabbitUpgrade(newRabbitVersionComponents, remoteRabbitVersionComponents []string) bool {
	return newRabbitVersionComponents[0] != remoteRabbitVersionComponents[0] ||
		newRabbitVersionComponents[1] != remoteRabbitVersionComponents[1]
}

func (v *ErlangVersions) PreparationRequired() bool {
	return v.Desired != v.Deployed
}
