param(
	[ValidateSet("Validate", "Scores", "Weekly")]
	[string]$Mode = "Validate",

	[string[]]$Realms = @("Onyxia", "Icecrown", "Lordaeron"),

	[int]$MaxPerSpec = 400,

	[int]$BulkTopLimit = 10000,

	[int]$Timeout = 45,

	[int]$Retries = 2,

	[double]$Sleep = 0.05,

	[string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$updater = Join-Path $PSScriptRoot "update_uwu_logs.py"

if (-not (Test-Path -LiteralPath $updater)) {
	throw "Missing updater: $updater"
}

foreach ($realm in $Realms) {
	Write-Output ""
	Write-Output ("=== {0}: {1} ===" -f $realm, $Mode)

	$arguments = @(
		$updater,
		"--server", $realm,
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

	& $Python @arguments
	if ($LASTEXITCODE -ne 0) {
		throw "UwU Logs update failed for $realm in $Mode mode."
	}
}

Write-Output ""
Write-Output ("Completed {0} mode for: {1}" -f $Mode, ($Realms -join ", "))
