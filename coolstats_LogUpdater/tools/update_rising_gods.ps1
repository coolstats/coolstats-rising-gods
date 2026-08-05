param(
	[ValidateSet("Validate", "Scores", "Weekly")]
	[string]$Mode = "Validate",

	[int]$MaxPerSpec = 600,

	[int]$BulkTopLimit = 10000,

	[int]$DuplicateWorkers = 8,

	[int]$BossWorkers = 4,

	[string[]]$BossName = @(),

	[int]$Timeout = 45,

	[int]$Retries = 2,

	[double]$Sleep = 0.08,

	[string]$Python = "python",

	[string]$LuaOutput = "",

	[string]$JsonOutput = "",

	[string]$BossCache = "",

	[string]$AddonVersion = "",

	[switch]$AllowInstalledLayout
)

$ErrorActionPreference = "Stop"
$updater = Join-Path $PSScriptRoot "update_uwu_logs.py"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedToc = Join-Path $repositoryRoot "coolstats.toc"

if (-not (Test-Path -LiteralPath $updater)) {
	throw "Missing Rising Gods updater script: $updater"
}
if (-not (Test-Path -LiteralPath $expectedToc) -and -not $AllowInstalledLayout) {
	throw "Rising Gods updater must run from the coolstats-rising-gods repository."
}

$arguments = @(
	$updater,
	"--server", "Rising-Gods",
	"--phase", "icc",
	"--timeout", $Timeout,
	"--retries", $Retries,
	"--sleep", $Sleep
)

switch ($Mode) {
	"Validate" {
		$arguments += "--validate-profile"
	}
	"Scores" {
		$arguments += @("--max-per-spec", $MaxPerSpec)
	}
	"Weekly" {
		$arguments += @(
			"--weekly",
			"--max-per-spec", $MaxPerSpec,
			"--bulk-top-limit", $BulkTopLimit,
			"--duplicate-workers", $DuplicateWorkers,
			"--boss-workers", $BossWorkers
		)
	}
}

foreach ($name in $BossName) {
	if (-not [string]::IsNullOrWhiteSpace($name)) {
		$arguments += @("--boss-name", $name)
	}
}

if (-not [string]::IsNullOrWhiteSpace($LuaOutput)) {
	$arguments += @("--lua-output", ([System.IO.Path]::GetFullPath($LuaOutput)))
}
if (-not [string]::IsNullOrWhiteSpace($JsonOutput)) {
	$arguments += @("--json-output", ([System.IO.Path]::GetFullPath($JsonOutput)))
}
if (-not [string]::IsNullOrWhiteSpace($BossCache)) {
	$arguments += @("--boss-cache", ([System.IO.Path]::GetFullPath($BossCache)))
}
if (-not [string]::IsNullOrWhiteSpace($AddonVersion)) {
	$arguments += @("--addon-version", $AddonVersion)
}

Push-Location $repositoryRoot
try {
	& $Python @arguments
	if ($LASTEXITCODE -ne 0) {
		throw "Rising Gods UwU Logs update failed in $Mode mode."
	}
}
finally {
	Pop-Location
}

Write-Output "Completed Rising Gods $Mode update."
