param(
	[string]$AddOnsPath = "",

	[int]$MaxPerSpec = 600,

	[int]$BulkTopLimit = 10000,

	[string[]]$BossName = @(),

	[string]$Python = "python",

	[string]$LuacPath = "",

	[switch]$SkipApiValidation,

	[switch]$NoInstall,

	[switch]$ValidateOnly,

	[switch]$Yes,

	[switch]$RequireLua51
)

$ErrorActionPreference = "Stop"

function Resolve-PythonCommand {
	param([string]$Requested)

	$candidates = @()
	if (-not [string]::IsNullOrWhiteSpace($Requested)) {
		$candidates += $Requested
	}
	$candidates += "py"
	$candidates += "python"
	$candidates += "python3"

	foreach ($candidate in $candidates) {
		if ([string]::IsNullOrWhiteSpace($candidate)) {
			continue
		}
		$command = Get-Command $candidate -ErrorAction SilentlyContinue
		if ($command) {
			return $candidate
		}
		if (Test-Path -LiteralPath $candidate -PathType Leaf) {
			return $candidate
		}
	}

	throw "Python 3 was not found. Install Python 3, pass -Python, or use the py launcher."
}

$updater = Join-Path $PSScriptRoot "update_rising_gods_live_logs.py"
if (-not (Test-Path -LiteralPath $updater -PathType Leaf)) {
	throw "Missing update_rising_gods_live_logs.py next to this PowerShell launcher."
}

$pythonCommand = Resolve-PythonCommand -Requested $Python
$arguments = @()

if ($pythonCommand -eq "py") {
	$arguments += "-3"
}

$arguments += $updater

if (-not [string]::IsNullOrWhiteSpace($AddOnsPath)) {
	$arguments += "--addons-path"
	$arguments += $AddOnsPath
}

$arguments += "--max-per-spec"
$arguments += [string]$MaxPerSpec
$arguments += "--bulk-top-limit"
$arguments += [string]$BulkTopLimit

foreach ($name in $BossName) {
	if (-not [string]::IsNullOrWhiteSpace($name)) {
		$arguments += "--boss-name"
		$arguments += $name
	}
}

if (-not [string]::IsNullOrWhiteSpace($LuacPath)) {
	$arguments += "--luac-path"
	$arguments += $LuacPath
}

if ($SkipApiValidation) { $arguments += "--skip-api-validation" }
if ($NoInstall) { $arguments += "--no-install" }
if ($ValidateOnly) { $arguments += "--validate-only" }
if ($Yes) { $arguments += "--yes" }
if ($RequireLua51) { $arguments += "--require-lua51" }

& $pythonCommand @arguments
exit $LASTEXITCODE
