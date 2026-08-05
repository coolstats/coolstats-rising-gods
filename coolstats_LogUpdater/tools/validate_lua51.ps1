param(
	[string]$PublishDirectory = "",

	[string]$LuacPath = "",

	[switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Resolve-Luac51Path {
	param([string]$RequestedPath)

	$candidates = @()
	if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
		$candidates += $RequestedPath
	}
	if (-not [string]::IsNullOrWhiteSpace($env:LUAC51)) {
		$candidates += $env:LUAC51
	}

	$command = Get-Command luac5.1 -ErrorAction SilentlyContinue
	if ($command) {
		$candidates += $command.Source
	}
	$command = Get-Command luac -ErrorAction SilentlyContinue
	if ($command) {
		$candidates += $command.Source
	}

	foreach ($candidate in $candidates) {
		if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
			return [System.IO.Path]::GetFullPath($candidate)
		}
	}

	throw "Could not locate Lua 5.1 luac. Install luac 5.1 or pass -LuacPath / set LUAC51."
}

if ([string]::IsNullOrWhiteSpace($PublishDirectory)) {
	$publishCandidates = @(
		(Join-Path $PSScriptRoot "..")
	)
	$PublishDirectory = $publishCandidates |
		Where-Object { Test-Path -LiteralPath (Join-Path $_ "coolstats.toc") } |
		Select-Object -First 1
	if (-not $PublishDirectory) {
		throw "Could not locate a publish directory containing coolstats.toc."
	}
}

$publishPath = [System.IO.Path]::GetFullPath($PublishDirectory)
$tocPath = Join-Path $publishPath "coolstats.toc"
if (-not (Test-Path -LiteralPath $tocPath)) {
	throw "Missing addon TOC: $tocPath"
}

$luac = Resolve-Luac51Path -RequestedPath $LuacPath

$luaFiles = @()
$luaFiles += Get-ChildItem -LiteralPath $publishPath -File -Filter "*.lua"

$cacheAddonPath = Join-Path $publishPath "cache_addon\coolstats_Cache"
if (Test-Path -LiteralPath $cacheAddonPath) {
	$luaFiles += Get-ChildItem -LiteralPath $cacheAddonPath -File -Filter "*.lua"
}

$realmDataPath = Join-Path $publishPath "realm_data"
if (Test-Path -LiteralPath $realmDataPath) {
	$luaFiles += Get-ChildItem -LiteralPath $realmDataPath -Recurse -File -Filter "*.lua"
}

$luaFiles = $luaFiles | Sort-Object FullName -Unique
if (-not $luaFiles -or $luaFiles.Count -eq 0) {
	throw "No Lua files found under $publishPath."
}

if (-not $Quiet) {
	Write-Output ("Lua 5.1 syntax check: {0} files with {1}" -f $luaFiles.Count, $luac)
}

$failed = @()
foreach ($file in $luaFiles) {
	if (-not $Quiet) {
		Write-Output ("luac -p {0}" -f $file.FullName.Substring($publishPath.Length + 1))
	}
	& $luac -p $file.FullName
	if ($LASTEXITCODE -ne 0) {
		$failed += $file.FullName
	}
}

if ($failed.Count -gt 0) {
	throw ("Lua 5.1 validation failed for: " + ($failed -join ", "))
}

Write-Output ("Lua 5.1 validation passed for {0} files." -f $luaFiles.Count)
