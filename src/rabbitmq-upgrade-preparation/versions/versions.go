package versions

import (
	"fmt"
	"strconv"
	"strings"

	"rabbitmq-upgrade-preparation/logger"

	version "github.com/hashicorp/go-version"
)

type VersionDifference interface {
	PreparationRequired() bool
	UpgradeMessage() string
}

type RabbitVersions struct {
	Desired  string
	Deployed string
}

func (v *RabbitVersions) PreparationRequired() bool {
	desiredVersion := enforceSemver(v.Desired)
	deployedVersion := enforceSemver(v.Deployed)

	return v.checkDesiredVersions(v.Deployed, v.Desired, "3.6.6") ||
		v.checkPatchVersion(deployedVersion, desiredVersion)
}

func (v *RabbitVersions) checkPatchVersion(deployedVersion, desiredVersion *version.Version) bool {
	patchConstraint, _ := version.NewConstraint(fmt.Sprintf("~> %s", deployedVersion))

	return !patchConstraint.Check(desiredVersion)
}

func (v *RabbitVersions) checkDesiredVersions(deployed, desired, boundary string) bool {
	if deployed == desired {
		return false
	}

	boundaryVersion, err := version.NewVersion(boundary)
	if err != nil {
		logger.Err.Fatalln(err)
	}

	deployedVersion, err := version.NewVersion(deployed)
	if err != nil {
		logger.Err.Fatalln(err)
	}

	desiredVersion, err := version.NewVersion(desired)
	if err != nil {
		logger.Err.Fatalln(err)
	}

	return !deployedVersion.GreaterThan(boundaryVersion) && !desiredVersion.LessThan(boundaryVersion)
}

func (v *RabbitVersions) UpgradeMessage() string {
	return fmt.Sprintf("It looks like you are trying to upgrade from RabbitMQ %s to RabbitMQ %s", v.Deployed, v.Desired)
}

type ErlangVersions struct {
	Desired  string
	Deployed string
}

func (v *ErlangVersions) PreparationRequired() bool {
	return isMajorErlangUpgrade(versionComponents(v.Desired), versionComponents(v.Deployed))
}

func (v *ErlangVersions) UpgradeMessage() string {
	return fmt.Sprintf("It looks like you are trying to upgrade from Erlang %s to Erlang %s", v.Deployed, v.Desired)
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
		logger.Err.Fatalln(err)
	}

	var segments []string
	for i := 0; i < 3; i++ {
		segments = append(segments, strconv.Itoa(semver.Segments()[i]))
	}

	semver, _ = version.NewVersion(strings.Join(segments, "."))

	return semver
}
