param(
	[Parameter(Mandatory = $true)]
	[string]$Version,

	[string]$PublishDirectory = "",

	[string]$OutputDirectory = (Join-Path $PSScriptRoot "..\releases")
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PublishDirectory)) {
	$publishCandidates = @(
		(Join-Path $PSScriptRoot "..\coolstats_publish"),
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
$zipPath = Join-Path $outputPath ("coolstats_{0}.zip" -f $Version)
$tocPath = Join-Path $publishPath "coolstats.toc"

if (-not (Test-Path -LiteralPath $tocPath)) {
	throw "Missing addon TOC: $tocPath"
}

$tocVersion = Select-String -LiteralPath $tocPath -Pattern "^## Version:\s*(.+)$" |
	Select-Object -First 1
if (-not $tocVersion -or $tocVersion.Matches[0].Groups[1].Value.Trim() -ne $Version) {
	throw "coolstats.toc version does not match requested release version $Version"
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
	"coolstats.toc",
	"coolstats_data_loader.lua",
	"coolstats.lua",
	"coolstats_lootalert.lua",
	"coolstats_lootalert.xml",
	"coolstats_options.lua",
	"coolstats_player_menu.lua",
	"coolstats_tooltip.lua"
)

$runtimeFiles += Get-ChildItem -LiteralPath (Join-Path $publishPath "assets") -File |
	Where-Object { $_.Extension -match "^\.(blp|ogg)$" } |
	ForEach-Object { "assets/" + $_.Name }

$runtimeFiles += Get-ChildItem -LiteralPath (Join-Path $publishPath "data\logs") -Recurse -File -Filter "*.lua" |
	ForEach-Object { $_.FullName.Substring($publishPath.Length + 1).Replace("\", "/") }

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

$realmDataPath = Join-Path $publishPath "realm_data"
if (Test-Path -LiteralPath $realmDataPath) {
	$realmAddons = Get-ChildItem -LiteralPath $realmDataPath -Directory -Filter "coolstats_Data_*"
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
}

if (Test-Path -LiteralPath $zipPath) {
	Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $stageRoot "*") -DestinationPath $zipPath -CompressionLevel Optimal
Remove-Item -LiteralPath $stageRoot -Recurse -Force

$zip = Get-Item -LiteralPath $zipPath
Write-Output ("Created {0} ({1:N2} MB)" -f $zip.FullName, ($zip.Length / 1MB))
