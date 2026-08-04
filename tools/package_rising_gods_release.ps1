param(
	[Parameter(Mandatory = $true)]
	[string]$Version,

	[string]$PublishDirectory = "",

	[string]$OutputDirectory = (Join-Path $PSScriptRoot "..\releases"),

	[string]$LuacPath = "",

	[switch]$SkipLua51Validation
)

$ErrorActionPreference = "Stop"

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
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
$stageRoot = Join-Path $outputPath "staging"
$addonStage = Join-Path $stageRoot "coolstats"
$zipPath = Join-Path $outputPath ("coolstats_rising_gods_{0}.zip" -f $Version)
$tocPath = Join-Path $publishPath "coolstats.toc"

if (-not (Test-Path -LiteralPath $tocPath)) {
	throw "Missing addon TOC: $tocPath"
}

$tocVersion = Select-String -LiteralPath $tocPath -Pattern "^## Version:\s*(.+)$" |
	Select-Object -First 1
if (-not $tocVersion -or $tocVersion.Matches[0].Groups[1].Value.Trim() -ne $Version) {
	throw "coolstats.toc version does not match requested release version $Version"
}

if (-not $SkipLua51Validation) {
	$luaValidator = Join-Path $PSScriptRoot "validate_lua51.ps1"
	if (-not (Test-Path -LiteralPath $luaValidator)) {
		throw "Missing Lua 5.1 validator: $luaValidator"
	}
	$validatorArguments = @(
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-File", $luaValidator,
		"-PublishDirectory", $publishPath,
		"-Quiet"
	)
	if (-not [string]::IsNullOrWhiteSpace($LuacPath)) {
		$validatorArguments += @("-LuacPath", $LuacPath)
	}
	& powershell @validatorArguments
	if ($LASTEXITCODE -ne 0) {
		throw "Lua 5.1 validation failed; refusing to package release."
	}
}

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

$resolvedOutput = [System.IO.Path]::GetFullPath($outputPath)
$resolvedStage = [System.IO.Path]::GetFullPath($stageRoot)
if (-not $resolvedStage.StartsWith($resolvedOutput, [System.StringComparison]::OrdinalIgnoreCase)) {
	throw "Refusing to clean staging path outside the release output directory."
}
if (Test-Path -LiteralPath $stageRoot) {
	Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $addonStage -Force | Out-Null

$runtimeFiles = @(
	"CHANGELOG.md",
	"coolstats.toc",
	"coolstats_data_loader.lua",
	"coolstats.lua",
	"coolstats_lootalert.lua",
	"coolstats_lootalert.xml",
	"coolstats_options.lua",
	"coolstats_player_menu.lua",
	"coolstats_talent_catalogs.lua",
	"coolstats_tooltip.lua"
)

$runtimeFiles += Get-ChildItem -LiteralPath (Join-Path $publishPath "assets") -File |
	Where-Object { $_.Extension -match "^\.(blp|ogg)$" } |
	ForEach-Object { "assets/" + $_.Name }

foreach ($relativePath in $runtimeFiles | Sort-Object -Unique) {
	$sourcePath = Join-Path $publishPath ($relativePath.Replace("/", "\"))
	if (-not (Test-Path -LiteralPath $sourcePath)) {
		throw "Missing runtime addon file: $relativePath"
	}
	$destinationPath = Join-Path $addonStage ($relativePath.Replace("/", "\"))
	$destinationDirectory = Split-Path -Parent $destinationPath
	New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
	Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

$cacheAddonPath = Join-Path $publishPath "cache_addon\coolstats_Cache"
if (Test-Path -LiteralPath $cacheAddonPath) {
	$cacheTocPath = Join-Path $cacheAddonPath "coolstats_Cache.toc"
	if (-not (Test-Path -LiteralPath $cacheTocPath)) {
		throw "Missing cache addon TOC: $cacheTocPath"
	}
	$cacheTocVersion = Select-String -LiteralPath $cacheTocPath -Pattern "^## Version:\s*(.+)$" |
		Select-Object -First 1
	if (-not $cacheTocVersion -or $cacheTocVersion.Matches[0].Groups[1].Value.Trim() -ne $Version) {
		throw "coolstats_Cache TOC version does not match requested release version $Version"
	}
	$cacheStage = Join-Path $stageRoot "coolstats_Cache"
	Get-ChildItem -LiteralPath $cacheAddonPath -File |
		Where-Object { $_.Extension -match "^\.(toc|lua)$" } |
		ForEach-Object {
			New-Item -ItemType Directory -Path $cacheStage -Force | Out-Null
			Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $cacheStage $_.Name) -Force
		}
}

$realmDataPath = Join-Path $publishPath "realm_data"
if (-not (Test-Path -LiteralPath $realmDataPath)) {
	throw "Missing Rising Gods realm data directory: $realmDataPath"
}

$expectedRealmAddonName = "coolstats_Data_RisingGods"
$expectedRealmShardPrefix = "${expectedRealmAddonName}_UWU_"
$realmAddons = @(Get-ChildItem -LiteralPath $realmDataPath -Directory -Filter "coolstats_Data_*" | Sort-Object Name)
$unexpectedRealmAddons = @(
	$realmAddons | Where-Object {
		$_.Name -ne $expectedRealmAddonName -and -not $_.Name.StartsWith($expectedRealmShardPrefix, [System.StringComparison]::Ordinal)
	}
)
if ($unexpectedRealmAddons.Count -gt 0) {
	throw "Refusing to package non-Rising-Gods realm data: $($unexpectedRealmAddons.Name -join ', ')"
}

$realmAddon = $realmAddons | Where-Object { $_.Name -eq $expectedRealmAddonName } | Select-Object -First 1
if (-not $realmAddon) {
	throw "Missing required realm addon: $expectedRealmAddonName"
}

$baseDataTocPath = Join-Path $realmAddon.FullName ($realmAddon.Name + ".toc")
if (-not (Test-Path -LiteralPath $baseDataTocPath -PathType Leaf)) {
	throw "Missing Rising Gods data TOC: $baseDataTocPath"
}
$baseChunkLine = Select-String -LiteralPath $baseDataTocPath -Pattern "^## X-coolstats-PlayerChunks:\s*(\d+)$" |
	Select-Object -First 1
if (-not $baseChunkLine) {
	throw "Rising Gods data TOC is missing X-coolstats-PlayerChunks."
}
$baseChunkCount = [int]$baseChunkLine.Matches[0].Groups[1].Value

$requiredShardNames = @()
for ($index = 1; $index -le $baseChunkCount; $index += 1) {
	$requiredShardNames += ("{0}{1:D2}" -f $expectedRealmShardPrefix, $index)
}
foreach ($shardName in $requiredShardNames) {
	if (-not ($realmAddons | Where-Object { $_.Name -eq $shardName } | Select-Object -First 1)) {
		throw "Missing required Rising Gods player shard addon: $shardName"
	}
}

foreach ($realmAddon in $realmAddons) {
	$realmTocPath = Join-Path $realmAddon.FullName ($realmAddon.Name + ".toc")
	if (-not (Test-Path -LiteralPath $realmTocPath)) {
		throw "Missing realm data addon TOC: $realmTocPath"
	}
	$realmTocVersion = Select-String -LiteralPath $realmTocPath -Pattern "^## Version:\s*(.+)$" |
		Select-Object -First 1
	if (-not $realmTocVersion -or $realmTocVersion.Matches[0].Groups[1].Value.Trim() -ne $Version) {
		throw "$($realmAddon.Name) TOC version does not match requested release version $Version"
	}

	$realmStage = Join-Path $stageRoot $realmAddon.Name
	Get-ChildItem -LiteralPath $realmAddon.FullName -Recurse -File |
		Where-Object { $_.Extension -match "^\.(toc|lua)$" } |
		ForEach-Object {
			$relativePath = $_.FullName.Substring($realmAddon.FullName.Length + 1)
			$destinationPath = Join-Path $realmStage $relativePath
			New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
			Copy-Item -LiteralPath $_.FullName -Destination $destinationPath -Force
		}
}

if (Test-Path -LiteralPath $zipPath) {
	Remove-Item -LiteralPath $zipPath -Force
}

$rootLaunchers = @(
	"Update_Rising_Gods_Logs.bat",
	"Update_Rising_Gods_Logs.sh"
)
foreach ($launcher in $rootLaunchers) {
	$rootUpdater = Join-Path $publishPath $launcher
	if (-not (Test-Path -LiteralPath $rootUpdater)) {
		throw "Missing public updater launcher: $rootUpdater"
	}
	Copy-Item -LiteralPath $rootUpdater -Destination (Join-Path $stageRoot $launcher) -Force
}

$updaterStage = Join-Path $stageRoot "coolstats_LogUpdater\tools"
New-Item -ItemType Directory -Path $updaterStage -Force | Out-Null
$updaterFiles = @(
	"update_rising_gods_live_logs.ps1",
	"update_rising_gods_live_logs.py",
	"update_rising_gods.ps1",
	"update_uwu_logs.py",
	"test_rising_gods_data_integrity.ps1",
	"test_rising_gods_data_integrity.py",
	"validate_lua51.ps1"
)
foreach ($file in $updaterFiles) {
	$sourcePath = Join-Path $PSScriptRoot $file
	if (-not (Test-Path -LiteralPath $sourcePath)) {
		throw "Missing public updater helper: $sourcePath"
	}
	Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $updaterStage $file) -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = [System.IO.Compression.ZipFile]::Open(
	$zipPath,
	[System.IO.Compression.ZipArchiveMode]::Create
)
try {
	Get-ChildItem -LiteralPath $stageRoot -Recurse -File |
		ForEach-Object {
			$entryName = $_.FullName.Substring($stageRoot.Length + 1).Replace("\", "/")
			$entry = $archive.CreateEntry(
				$entryName,
				[System.IO.Compression.CompressionLevel]::Optimal
			)
			$entryStream = $entry.Open()
			$fileStream = [System.IO.File]::OpenRead($_.FullName)
			try {
				$fileStream.CopyTo($entryStream)
			}
			finally {
				$fileStream.Dispose()
				$entryStream.Dispose()
			}
		}
}
finally {
	$archive.Dispose()
}

Remove-Item -LiteralPath $stageRoot -Recurse -Force

$zip = Get-Item -LiteralPath $zipPath
Write-Output ("Created {0} ({1:N2} MB)" -f $zip.FullName, ($zip.Length / 1MB))
