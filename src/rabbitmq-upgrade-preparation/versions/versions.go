package versions

import (
	"fmt"
	"strings"

	version "github.com/hashicorp/go-version"
)

type VersionDifference interface {
	PreparationRequired() (bool, error)
	UpgradeMessage() string
}

type RabbitVersions struct {
	Desired  string
	Deployed string
}

func (v *RabbitVersions) PreparationRequired() (bool, error) {
	desiredVersion, err := version.NewVersion(v.Desired)
	if err != nil {
		return false, fmt.Errorf("The desired version of RabbitMQ is malformed: %s", v.Desired)
	}

	deployedVersion, err := version.NewVersion(v.Deployed)
	if err != nil {
		return false, fmt.Errorf("The deployed version of RabbitMQ is malformed: %s", v.Deployed)
	}

	boundaryVersion, err := version.NewVersion("3.6.6")
	if err != nil {
		panic(fmt.Sprintf("boundary version is invalid: %s", err))
	}

	result := checkDesiredVersions(deployedVersion, desiredVersion, boundaryVersion) ||
		checkPatchVersion(deployedVersion, desiredVersion)
	return result, nil
}

func (v *RabbitVersions) UpgradeMessage() string {
	return fmt.Sprintf("It looks like you are trying to upgrade from RabbitMQ %s to RabbitMQ %s", v.Deployed, v.Desired)
}

type ErlangVersions struct {
	Desired  string
	Deployed string
}

func (v *ErlangVersions) PreparationRequired() (bool, error) {
	return isMajorErlangUpgrade(versionComponents(v.Desired), versionComponents(v.Deployed)), nil
}

func (v *ErlangVersions) UpgradeMessage() string {
	return fmt.Sprintf("It looks like you are trying to upgrade from Erlang %s to Erlang %s", v.Deployed, v.Desired)
}

func checkPatchVersion(deployedVersion, desiredVersion *version.Version) bool {
	pureDeployedVersion := convertToPureSemver(deployedVersion)
	pureDesiredVersion := convertToPureSemver(desiredVersion)
	patchConstraint, err := version.NewConstraint(fmt.Sprintf("~> %s", pureDeployedVersion))
	if err != nil {
		panic(fmt.Sprintf("built an invaid contraint: %s", err))
	}

	return !patchConstraint.Check(pureDesiredVersion)
}

func checkDesiredVersions(deployed, desired, boundary *version.Version) bool {
	if deployed.Equal(desired) {
		return false
	}

	return !deployed.GreaterThan(boundary) && !desired.LessThan(boundary)
}

func isMajorErlangUpgrade(desiredErlangVersionComponents, deployedErlangVersionComponents []string) bool {
	return desiredErlangVersionComponents[0] != deployedErlangVersionComponents[0]
}

func versionComponents(version string) []string {
	return strings.Split(version, ".")
}

func convertToPureSemver(v *version.Version) *version.Version {
	segments := v.Segments()
	semver, err := version.NewVersion(fmt.Sprintf("%d.%d.%d", segments[0], segments[1], segments[2]))
	if err != nil {
		panic(fmt.Sprintf("built version number is not semver: %s", err))
	}

	return semver
}
