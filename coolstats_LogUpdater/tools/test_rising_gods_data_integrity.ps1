param(
	[Parameter(Mandatory = $true)]
	[string]$DataAddonPath,

	[string]$ExpectedVersion = "",

	[int]$ExpectedMaxPerSpec = 600,

	[int]$MinPlayers = 6000,

	[int]$MaxPlayers = 20000,

	[int]$ExpectedChunkCount = 0,

	[switch]$AllowTemporaryFolderName,

	[switch]$RequireShards,

	[switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Resolve-PythonCommand {
	$candidates = @("py", "python", "python3")
	foreach ($candidate in $candidates) {
		$command = Get-Command $candidate -ErrorAction SilentlyContinue
		if ($command) {
			return $candidate
		}
	}
	throw "Python 3 was not found. Install Python 3 or run the cross-platform audit directly."
}

$auditScript = Join-Path $PSScriptRoot "test_rising_gods_data_integrity.py"
if (-not (Test-Path -LiteralPath $auditScript -PathType Leaf)) {
	throw "Missing Rising Gods Python data integrity audit: $auditScript"
}

$pythonCommand = Resolve-PythonCommand
$arguments = @()
if ($pythonCommand -eq "py") {
	$arguments += "-3"
}

$arguments += $auditScript
$arguments += "--data-addon-path"
$arguments += $DataAddonPath
$arguments += "--expected-max-per-spec"
$arguments += [string]$ExpectedMaxPerSpec
$arguments += "--min-players"
$arguments += [string]$MinPlayers
$arguments += "--max-players"
$arguments += [string]$MaxPlayers

if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
	$arguments += "--expected-version"
	$arguments += $ExpectedVersion
}
if ($ExpectedChunkCount -gt 0) {
	$arguments += "--expected-chunk-count"
	$arguments += [string]$ExpectedChunkCount
}
if ($AllowTemporaryFolderName) { $arguments += "--allow-temporary-folder-name" }
if ($RequireShards) { $arguments += "--require-shards" }
if ($Quiet) { $arguments += "--quiet" }

& $pythonCommand @arguments
if ($LASTEXITCODE -ne 0) {
	throw "Rising Gods data integrity audit failed."
}
