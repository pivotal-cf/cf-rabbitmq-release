package versions

import (
	"fmt"
	"log"
	"strconv"
	"strings"

	version "github.com/hashicorp/go-version"
)

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
	toVersion := enforceSemver(v.Desired)
	fromVersion := enforceSemver(v.Deployed)
	breakingVersion := enforceSemver("3.6.6")

	patchUpgrade, _ := version.NewConstraint(fmt.Sprintf("~> %s", fromVersion))
	breakingVersionUpgrade, _ := version.NewConstraint(fmt.Sprintf("> %s, <= %s", fromVersion, toVersion))
	return breakingVersionUpgrade.Check(breakingVersion) || !patchUpgrade.Check(toVersion)
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

func enforceSemver(v string) *version.Version {
	semver, err := version.NewVersion(v)
	if err != nil {
		log.Fatalln(err)
	}

	var segments []string
	for i := 0; i < 3; i++ {
		segments = append(segments, strconv.Itoa(semver.Segments()[i]))
	}

	semver, _ = version.NewVersion(strings.Join(segments, "."))

	return semver
}
