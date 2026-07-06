param(
	[Parameter(Mandatory = $true)]
	[string]$Version,

	[switch]$SkipApiValidation,

	[string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

Push-Location $repositoryRoot
try {
	& $Python -m pytest -q
	if ($LASTEXITCODE -ne 0) {
		throw "Python tests failed."
	}

	if (-not $SkipApiValidation) {
		& (Join-Path $PSScriptRoot "update_rising_gods.ps1") -Mode Validate -Python $Python
	}

	& (Join-Path $PSScriptRoot "package_rising_gods_release.ps1") `
		-Version $Version `
		-PublishDirectory $repositoryRoot `
		-OutputDirectory (Join-Path $repositoryRoot "releases")

	& (Join-Path $PSScriptRoot "validate_rising_gods_release.ps1") -Version $Version
}
finally {
	Pop-Location
}
