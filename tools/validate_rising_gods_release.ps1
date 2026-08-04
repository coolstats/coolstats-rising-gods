param(
	[Parameter(Mandatory = $true)]
	[string]$Version,

	[string]$ZipPath = ""
)

$ErrorActionPreference = "Stop"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ([string]::IsNullOrWhiteSpace($ZipPath)) {
	$ZipPath = Join-Path $repositoryRoot ("releases\coolstats_rising_gods_{0}.zip" -f $Version)
}
$ZipPath = [System.IO.Path]::GetFullPath($ZipPath)
if (-not (Test-Path -LiteralPath $ZipPath)) {
	throw "Missing release archive: $ZipPath"
}

$validationRoot = Join-Path $repositoryRoot "releases\validation_rising_gods"
$resolvedRepository = $repositoryRoot.TrimEnd("\") + "\"
$resolvedValidation = [System.IO.Path]::GetFullPath($validationRoot)
if (-not ($resolvedValidation + "\").StartsWith($resolvedRepository, [System.StringComparison]::OrdinalIgnoreCase)) {
	throw "Unsafe validation path: $resolvedValidation"
}
if (Test-Path -LiteralPath $validationRoot) {
	Remove-Item -LiteralPath $validationRoot -Recurse -Force
}

try {
	Expand-Archive -LiteralPath $ZipPath -DestinationPath $validationRoot
	$actualFolders = @(Get-ChildItem -LiteralPath $validationRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
	$requiredFolders = @("coolstats", "coolstats_Cache", "coolstats_Data_RisingGods", "coolstats_LogUpdater")
	foreach ($folder in $requiredFolders) {
		if ($actualFolders -notcontains $folder) {
			throw "Missing required top-level addon folder: $folder"
		}
	}
	$allowedDataPrefix = "coolstats_Data_RisingGods_UWU_"
	$unexpectedFolders = @(
		$actualFolders | Where-Object {
			$requiredFolders -notcontains $_ -and -not $_.StartsWith($allowedDataPrefix, [System.StringComparison]::Ordinal)
		}
	)
	if ($unexpectedFolders.Count -gt 0) {
		throw "Unexpected top-level addon folders: $($unexpectedFolders -join ', ')."
	}

	$requiredLaunchers = @(
		"Update_Rising_Gods_Logs.bat",
		"Update_Rising_Gods_Logs.sh"
	)
	foreach ($launcher in $requiredLaunchers) {
		$launcherPath = Join-Path $validationRoot $launcher
		if (-not (Test-Path -LiteralPath $launcherPath)) {
			throw "Missing public updater launcher at release root: $launcher"
		}
	}

	$requiredUpdaterFiles = @(
		"update_rising_gods_live_logs.ps1",
		"update_rising_gods_live_logs.py",
		"update_rising_gods.ps1",
		"update_uwu_logs.py",
		"test_rising_gods_data_integrity.ps1",
		"test_rising_gods_data_integrity.py",
		"validate_lua51.ps1"
	)
	foreach ($file in $requiredUpdaterFiles) {
		$path = Join-Path $validationRoot "coolstats_LogUpdater\tools\$file"
		if (-not (Test-Path -LiteralPath $path)) {
			throw "Missing public updater helper: $file"
		}
	}

	$forbidden = @("coolstats_Data_Onyxia", "coolstats_Data_Icecrown", "coolstats_Data_Lordaeron")
	foreach ($folder in $forbidden) {
		if (Test-Path -LiteralPath (Join-Path $validationRoot $folder)) {
			throw "Warmane realm data leaked into the Rising Gods release: $folder"
		}
	}

	$tocPaths = @(
		(Join-Path $validationRoot "coolstats\coolstats.toc"),
		(Join-Path $validationRoot "coolstats_Cache\coolstats_Cache.toc"),
		(Join-Path $validationRoot "coolstats_Data_RisingGods\coolstats_Data_RisingGods.toc")
	)
	$tocPaths += @(
		Get-ChildItem -LiteralPath $validationRoot -Directory -Filter "coolstats_Data_RisingGods_UWU_*" |
			ForEach-Object { Join-Path $_.FullName ($_.Name + ".toc") }
	)
	foreach ($tocPath in $tocPaths) {
		$versionLine = Select-String -LiteralPath $tocPath -Pattern "^## Version:\s*(.+)$" | Select-Object -First 1
		if (-not $versionLine -or $versionLine.Matches[0].Groups[1].Value.Trim() -ne $Version) {
			throw "TOC version mismatch in $tocPath"
		}
	}

	$dataToc = $tocPaths[2]
	if (-not (Select-String -LiteralPath $dataToc -Pattern "^## X-coolstats-Realm:\s*Rising-Gods$")) {
		throw "Rising Gods realm metadata is missing or incorrect."
	}
	if (-not (Select-String -LiteralPath $dataToc -Pattern "^## X-coolstats-Phase:\s*icc$")) {
		throw "Rising Gods phase metadata is missing or incorrect."
	}

	$baseDataText = Get-Content -LiteralPath (Join-Path $validationRoot "coolstats_Data_RisingGods\data\logs\icc\coolstats_uwu_data.lua") -Raw
	$chunkLine = Select-String -LiteralPath $dataToc -Pattern "^## X-coolstats-PlayerChunks:\s*(\d+)$" | Select-Object -First 1
	if (-not $chunkLine) {
		throw "Rising Gods player chunk metadata is missing."
	}
	$chunkCount = [int]$chunkLine.Matches[0].Groups[1].Value
	if ($baseDataText -notmatch "playerShardAddons\s*=") {
		throw "Rising Gods release data must use player shard addons."
	}
	for ($index = 1; $index -le $chunkCount; $index += 1) {
		$shardName = "coolstats_Data_RisingGods_UWU_{0:D2}" -f $index
		if (-not (Test-Path -LiteralPath (Join-Path $validationRoot $shardName) -PathType Container)) {
			throw "Missing generated Rising Gods player shard: $shardName"
		}
	}

	$privacyScript = Join-Path $repositoryRoot "tools\test_release_privacy.ps1"
	if (-not (Test-Path -LiteralPath $privacyScript)) {
		throw "Missing release privacy audit: $privacyScript"
	}
	& $privacyScript -RootPath $validationRoot -Quiet

	$auditScript = Join-Path $repositoryRoot "tools\test_rising_gods_data_integrity.ps1"
	if (-not (Test-Path -LiteralPath $auditScript)) {
		throw "Missing Rising Gods data integrity audit: $auditScript"
	}
	& $auditScript -DataAddonPath (Join-Path $validationRoot "coolstats_Data_RisingGods") -ExpectedVersion $Version -ExpectedMaxPerSpec 600 -RequireShards -Quiet
}
finally {
	if (Test-Path -LiteralPath $validationRoot) {
		Remove-Item -LiteralPath $validationRoot -Recurse -Force
	}
}

$zip = Get-Item -LiteralPath $ZipPath
$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $ZipPath
Write-Output ("Validated {0} ({1} bytes)" -f $zip.FullName, $zip.Length)
Write-Output ("SHA256 {0}" -f $hash.Hash)
