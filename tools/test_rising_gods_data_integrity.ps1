param(
	[Parameter(Mandatory = $true)]
	[string]$DataAddonPath,

	[string]$ExpectedVersion = "",

	[int]$ExpectedMaxPerSpec = 600,

	[int]$MinPlayers = 6000,

	[int]$MaxPlayers = 20000,

	[int]$ExpectedChunkCount = 0,

	[switch]$AllowTemporaryFolderName,

	[switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Read-TextFile {
	param([string]$Path)

	return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Require-File {
	param([string]$Path, [string]$Label)

	if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
		throw "Missing $Label`: $Path"
	}
}

function Require-Match {
	param([string]$Text, [string]$Pattern, [string]$Message)

	if (-not [regex]::IsMatch($Text, $Pattern)) {
		throw $Message
	}
}

function Require-Contains {
	param([string]$Text, [string]$Needle, [string]$Message)

	if (-not $Text.Contains($Needle)) {
		throw $Message
	}
}

function Get-TocMetadataInt {
	param([string]$Text, [string]$Key)

	$pattern = "(?m)^##\s+{0}:\s*(\d+)\s*$" -f [regex]::Escape($Key)
	$match = [regex]::Match($Text, $pattern)
	if (-not $match.Success) {
		return $null
	}
	return [int]$match.Groups[1].Value
}

function Get-ExpectedPlayerChunkCount {
	param([int]$PlayerCount)

	$targetChunkSize = 3000
	$minChunkCount = 6
	$maxChunkCount = 16
	$minimumPlayers = 6000
	if ($PlayerCount -le 0) {
		return 1
	}
	$chunkCount = [Math]::Ceiling($PlayerCount / $targetChunkSize)
	if ($PlayerCount -ge $minimumPlayers) {
		$chunkCount = [Math]::Max($minChunkCount, $chunkCount)
	}
	return [Math]::Min($maxChunkCount, [Math]::Max(1, [int]$chunkCount))
}

$addonPath = [System.IO.Path]::GetFullPath($DataAddonPath)
$addonFolderName = Split-Path -Leaf $addonPath
if ($addonFolderName -ne "coolstats_Data_RisingGods" -and (-not $AllowTemporaryFolderName -or $addonFolderName -notmatch "^coolstats_Data_RisingGods\.__coolstats_update_tmp(_\d+)?$")) {
	throw "Data addon folder must be named coolstats_Data_RisingGods: $addonPath"
}
if (-not (Test-Path -LiteralPath $addonPath -PathType Container)) {
	throw "Missing Rising Gods data addon folder: $addonPath"
}

$tocPath = Join-Path $addonPath "coolstats_Data_RisingGods.toc"
$logDir = Join-Path $addonPath "data\logs\icc"
$headerPath = Join-Path $logDir "coolstats_uwu_data.lua"
Require-File -Path $tocPath -Label "Rising Gods data TOC"
Require-File -Path $headerPath -Label "Rising Gods data header"
if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
	throw "Missing Rising Gods ICC log data directory: $logDir"
}

$unexpectedFiles = @(
	Get-ChildItem -LiteralPath $addonPath -Recurse -File |
		Where-Object { $_.Extension -notmatch "^\.(toc|lua)$" }
)
if ($unexpectedFiles.Count -gt 0) {
	throw "Unexpected non-addon files in data addon: $($unexpectedFiles.FullName -join ', ')"
}

$tocText = Read-TextFile -Path $tocPath
Require-Contains -Text $tocText -Needle "## Title: |cff00c0ffcoolstats|r Data - Rising-Gods" -Message "Rising Gods data TOC title is missing or incorrect."
Require-Contains -Text $tocText -Needle "## RequiredDeps: coolstats" -Message "Rising Gods data TOC must depend on coolstats."
Require-Contains -Text $tocText -Needle "## LoadOnDemand: 1" -Message "Rising Gods data TOC must stay load-on-demand."
Require-Contains -Text $tocText -Needle "## X-coolstats-Realm: Rising-Gods" -Message "Rising Gods realm metadata is missing or incorrect."
Require-Contains -Text $tocText -Needle "## X-coolstats-Phase: icc" -Message "Rising Gods phase metadata is missing or incorrect."
if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
	Require-Contains -Text $tocText -Needle ("## Version: {0}" -f $ExpectedVersion) -Message "Rising Gods data TOC version does not match $ExpectedVersion."
}

$tocPlayerCount = Get-TocMetadataInt -Text $tocText -Key "X-coolstats-PlayerCount"
$tocChunkCount = Get-TocMetadataInt -Text $tocText -Key "X-coolstats-PlayerChunks"
if ($null -eq $tocPlayerCount) {
	throw "Rising Gods data TOC is missing X-coolstats-PlayerCount."
}
if ($null -eq $tocChunkCount) {
	throw "Rising Gods data TOC is missing X-coolstats-PlayerChunks."
}
$calculatedChunkCount = Get-ExpectedPlayerChunkCount -PlayerCount $tocPlayerCount
if ($tocChunkCount -ne $calculatedChunkCount) {
	throw "Rising Gods data TOC has $tocChunkCount chunks for $tocPlayerCount players; expected $calculatedChunkCount."
}
if ($ExpectedChunkCount -le 0) {
	$ExpectedChunkCount = $tocChunkCount
}
elseif ($ExpectedChunkCount -ne $tocChunkCount) {
	throw "Rising Gods data TOC chunk count $tocChunkCount does not match expected $ExpectedChunkCount."
}

$expectedDataFiles = @("coolstats_uwu_data.lua")
for ($index = 1; $index -le $ExpectedChunkCount; $index += 1) {
	$expectedDataFiles += ("coolstats_uwu_data_{0:D2}.lua" -f $index)
}

foreach ($file in $expectedDataFiles) {
	$relativePath = "data\logs\icc\$file"
	Require-File -Path (Join-Path $addonPath $relativePath) -Label "generated Rising Gods data file"
	Require-Contains -Text $tocText -Needle $relativePath -Message "Rising Gods data TOC does not load $relativePath."
}

$chunkFiles = @(
	Get-ChildItem -LiteralPath $logDir -File -Filter "coolstats_uwu_data_*.lua" |
		Sort-Object Name
)
$actualChunkNames = @($chunkFiles | Select-Object -ExpandProperty Name)
$expectedChunkNames = @($expectedDataFiles | Where-Object { $_ -ne "coolstats_uwu_data.lua" })
if (($actualChunkNames -join "|") -ne ($expectedChunkNames -join "|")) {
	throw "Unexpected Rising Gods chunk files. Expected $($expectedChunkNames -join ', '); found $($actualChunkNames -join ', ')."
}

$headerText = Read-TextFile -Path $headerPath
Require-Contains -Text $headerText -Needle 'realm = "Rising-Gods"' -Message "Generated header is not for Rising-Gods."
Require-Contains -Text $headerText -Needle 'phaseId = "icc"' -Message "Generated header is not for the ICC phase."
Require-Contains -Text $headerText -Needle 'defaultRaidName = "Icecrown Citadel"' -Message "Generated header is missing the ICC default raid."
Require-Contains -Text $headerText -Needle 'source = "https://uwu-logs.xyz/top_points"' -Message "Generated header is missing the UwU top-points source."
Require-Contains -Text $headerText -Needle 'topSource = "https://uwu-logs.xyz/top"' -Message "Generated header is missing the UwU top source."
Require-Contains -Text $headerText -Needle 'characterSource = "https://uwu-logs.xyz/character"' -Message "Generated header is missing the UwU character source."
Require-Match -Text $headerText -Pattern ("maxPerSpec\s*=\s*{0}," -f $ExpectedMaxPerSpec) -Message "Generated header maxPerSpec does not match $ExpectedMaxPerSpec."
Require-Match -Text $headerText -Pattern 'generatedAt\s*=\s*"\d{4}-\d{2}-\d{2}T' -Message "Generated header is missing an ISO generatedAt timestamp."
Require-Contains -Text $headerText -Needle "players = {}," -Message "Generated header must initialize an empty players table before chunks load."
Require-Match -Text $headerText -Pattern ("totalPlayers\s*=\s*{0}," -f $tocPlayerCount) -Message "Generated header totalPlayers does not match TOC metadata."
Require-Match -Text $headerText -Pattern ("playerChunkCount\s*=\s*{0}," -f $tocChunkCount) -Message "Generated header playerChunkCount does not match TOC metadata."
if ($headerText -notmatch "playerLoadSteps\s*=\s*\{([^}]*)\}") {
	throw "Generated header is missing playerLoadSteps."
}
$loadSteps = @($Matches[1].Split(",") | ForEach-Object { [int]$_.Trim() })
if ($loadSteps.Count -ne ($tocChunkCount + 1)) {
	throw "Generated header playerLoadSteps has $($loadSteps.Count) entries; expected $($tocChunkCount + 1)."
}
if ($loadSteps[0] -ne 0 -or $loadSteps[-1] -ne $tocPlayerCount) {
	throw "Generated header playerLoadSteps must start at 0 and end at $tocPlayerCount."
}
for ($index = 1; $index -lt $loadSteps.Count; $index += 1) {
	if ($loadSteps[$index] -lt $loadSteps[$index - 1]) {
		throw "Generated header playerLoadSteps must be non-decreasing."
	}
}

$requiredBosses = @(
	"Lord Marrowgar",
	"Lady Deathwhisper",
	"Deathbringer Saurfang",
	"Festergut",
	"Rotface",
	"Professor Putricide",
	"Blood Prince Council",
	"Blood-Queen Lana'thel",
	"Sindragosa",
	"The Lich King",
	"Toravon the Ice Watcher",
	"Halion",
	"Anub'arak"
)
for ($index = 0; $index -lt $requiredBosses.Count; $index += 1) {
	$bossIndex = $index + 1
	$boss = $requiredBosses[$index]
	Require-Match -Text $headerText -Pattern ("\[\s*{0}\s*\]\s*=\s*`"{1}`"" -f $bossIndex, [regex]::Escape($boss)) -Message "Generated header is missing boss $bossIndex`: $boss"
}

$playerKeys = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::Ordinal)
$chunkCounts = @()
foreach ($chunk in $chunkFiles) {
	$text = Read-TextFile -Path $chunk.FullName
	$chunkIndex = [int]([regex]::Match($chunk.Name, "(\d\d)\.lua$").Groups[1].Value)
	$expectedStart = $loadSteps[$chunkIndex - 1] + 1
	Require-Match -Text $text -Pattern ("local\s+chunkStartIndex\s*=\s*{0}" -f $expectedStart) -Message "$($chunk.Name) has an incorrect chunkStartIndex guard."
	Require-Contains -Text $text -Needle "ShouldSkipUwUDataChunk" -Message "$($chunk.Name) is missing the chunk-skip guard."
	Require-Contains -Text $text -Needle "local chunk = {" -Message "$($chunk.Name) does not define a chunk table."
	Require-Contains -Text $text -Needle "coolstatsUwUData.players" -Message "$($chunk.Name) does not merge into coolstatsUwUData.players."
	Require-Contains -Text $text -Needle "for key, player in pairs(chunk) do" -Message "$($chunk.Name) does not merge chunk rows safely."
	if ([regex]::IsMatch($text, '", 0, \d+, \d+, nil,')) {
		throw "Generated data contains rankless player rows in $($chunk.Name)."
	}

	$matches = [regex]::Matches($text, '(?m)^[\t ]+\["([^"]+)"\][\t ]*=')
	$count = $matches.Count
	if ($count -le 0) {
		throw "Generated chunk $($chunk.Name) has no player rows."
	}
	foreach ($match in $matches) {
		$key = $match.Groups[1].Value
		if (-not $playerKeys.Add($key)) {
			throw "Duplicate player key across chunks: $key"
		}
	}
	$chunkCounts += $count
}

$playerCount = $playerKeys.Count
if ($playerCount -ne $tocPlayerCount) {
	throw "Generated data contains $playerCount player rows but TOC metadata says $tocPlayerCount."
}
if ($playerCount -lt $MinPlayers) {
	throw "Generated data contains only $playerCount players; refusing to install."
}
if ($playerCount -gt $MaxPlayers) {
	throw "Generated data contains $playerCount players, above the safety ceiling of $MaxPlayers."
}

$minChunk = ($chunkCounts | Measure-Object -Minimum).Minimum
$maxChunk = ($chunkCounts | Measure-Object -Maximum).Maximum
$allowedChunkSpread = [Math]::Max(30, $ExpectedChunkCount * 5)
if (($maxChunk - $minChunk) -gt $allowedChunkSpread) {
	throw "Generated data chunks are not balanced: min=$minChunk max=$maxChunk."
}

if (-not $Quiet) {
	Write-Output (
		"Rising Gods data integrity passed: players={0} chunks={1} minChunk={2} maxChunk={3} maxPerSpec={4}" -f
		$playerCount,
		$chunkFiles.Count,
		$minChunk,
		$maxChunk,
		$ExpectedMaxPerSpec
	)
}
