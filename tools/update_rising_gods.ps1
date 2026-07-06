param(
	[ValidateSet("Validate", "Scores", "Weekly")]
	[string]$Mode = "Validate",

	[int]$MaxPerSpec = 400,

	[int]$BulkTopLimit = 10000,

	[int]$Timeout = 45,

	[int]$Retries = 2,

	[double]$Sleep = 0.08,

	[string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$updater = Join-Path $PSScriptRoot "update_uwu_logs.py"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$expectedToc = Join-Path $repositoryRoot "coolstats.toc"

if (-not (Test-Path -LiteralPath $updater) -or -not (Test-Path -LiteralPath $expectedToc)) {
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
			"--bulk-top-limit", $BulkTopLimit
		)
	}
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
