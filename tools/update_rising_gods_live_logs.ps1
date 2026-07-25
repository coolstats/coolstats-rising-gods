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
$script:StepIndex = 0
$script:StepTotal = 0
$script:StepLabels = @()

function Get-RunStepLabels {
	param(
		[bool]$ValidateOnly,
		[bool]$SkipApiValidation,
		[bool]$NoInstall
	)

	$steps = @("Check updater files")
	if ($ValidateOnly) {
		$steps += "Validate existing generated data"
		$steps += "Finish"
		return $steps
	}

	$steps += "Confirm update plan"
	if (-not $SkipApiValidation) {
		$steps += "Validate UwU profile"
	}
	if (-not $NoInstall) {
		$steps += "Check live AddOns write access"
	}
	$steps += "Download UwU logs and rebuild data"
	$steps += "Validate generated data"
	if ($NoInstall) {
		$steps += "Finish local refresh"
	}
	else {
		$steps += "Install live data addon"
	}
	$steps += "Finish"
	return $steps
}

function Initialize-UiProgress {
	param([string[]]$Steps)

	$script:StepLabels = @($Steps)
	$script:StepTotal = $script:StepLabels.Count
	$script:StepIndex = 0
}

function Get-AsciiProgressBar {
	param(
		[int]$Percent,
		[int]$Width = 28
	)

	$filled = [Math]::Floor(($Percent / 100) * $Width)
	if ($filled -lt 0) { $filled = 0 }
	if ($filled -gt $Width) { $filled = $Width }
	return ("[" + ("#" * $filled) + ("-" * ($Width - $filled)) + "]")
}

function Write-UiHeader {
	Write-Host ""
	Write-Host "============================================================" -ForegroundColor DarkCyan
	Write-Host "                  c o o l s t a t s" -ForegroundColor Cyan
	Write-Host "                  Rising Gods logs" -ForegroundColor DarkCyan
	Write-Host "============================================================" -ForegroundColor DarkCyan
	Write-Host " Data-only updater for coolstats_Data_RisingGods" -ForegroundColor Gray
	Write-Host " No admin rights, no credentials, no GitHub publishing." -ForegroundColor Gray
	Write-Host ""
}

function Get-TocVersion {
	param([string]$TocPath)

	if (-not (Test-Path -LiteralPath $TocPath)) {
		return ""
	}
	$versionLine = Select-String -LiteralPath $TocPath -Pattern "^## Version:\s*(.+)$" | Select-Object -First 1
	if (-not $versionLine) {
		return ""
	}
	return $versionLine.Matches[0].Groups[1].Value.Trim()
}

function Get-UpdaterLayout {
	$hostRoot = Get-NormalizedFullPath (Join-Path $PSScriptRoot "..")
	$sourceDataAddon = Join-Path $hostRoot "realm_data\coolstats_Data_RisingGods"
	$installedAddOnsRoot = Get-NormalizedFullPath (Join-Path $hostRoot "..")
	$installedCoreToc = Join-Path $installedAddOnsRoot "coolstats\coolstats.toc"
	$installedDataAddon = Join-Path $installedAddOnsRoot "coolstats_Data_RisingGods"
	$updaterScript = Join-Path $hostRoot "tools\update_rising_gods.ps1"
	$pythonUpdater = Join-Path $hostRoot "tools\update_uwu_logs.py"

	if ((Test-Path -LiteralPath (Join-Path $hostRoot "coolstats.toc")) -and (Test-Path -LiteralPath $sourceDataAddon) -and (Test-Path -LiteralPath $updaterScript) -and (Test-Path -LiteralPath $pythonUpdater)) {
		return @{
			Kind = "Source"
			Root = $hostRoot
			AddOnsRoot = $null
			CoreToc = Join-Path $hostRoot "coolstats.toc"
			LiveDataAddon = $sourceDataAddon
			WorkDataAddon = $sourceDataAddon
			JsonOutput = Join-Path $hostRoot "data\uwu_logs_rising_gods.json"
			BossCache = Join-Path $hostRoot "data\uwu_character_boss_cache_rising_gods.json"
		}
	}

	if ((Test-Path -LiteralPath $installedCoreToc) -and (Test-Path -LiteralPath $installedDataAddon) -and (Test-Path -LiteralPath $updaterScript) -and (Test-Path -LiteralPath $pythonUpdater)) {
		return @{
			Kind = "Installed"
			Root = $hostRoot
			AddOnsRoot = $installedAddOnsRoot
			CoreToc = $installedCoreToc
			LiveDataAddon = $installedDataAddon
			WorkDataAddon = Join-Path $hostRoot "work\coolstats_Data_RisingGods"
			JsonOutput = Join-Path $hostRoot "data\uwu_logs_rising_gods.json"
			BossCache = Join-Path $hostRoot "data\uwu_character_boss_cache_rising_gods.json"
		}
	}

	throw "Could not identify updater layout. Run from the source repository or from an extracted release inside Interface\AddOns."
}

function Write-Step {
	param([string]$Message)

	if ($script:StepTotal -gt 0) {
		$script:StepIndex += 1
		if ($script:StepIndex -gt $script:StepTotal) {
			$script:StepIndex = $script:StepTotal
		}
		$percent = [Math]::Floor((($script:StepIndex - 1) / [Math]::Max($script:StepTotal, 1)) * 100)
		$bar = Get-AsciiProgressBar -Percent $percent
		Write-Progress -Activity "coolstats Rising Gods log updater" -Status $Message -PercentComplete $percent
		Write-Host ""
		Write-Host ("[{0}/{1}] {2} {3}%" -f $script:StepIndex, $script:StepTotal, $bar, $percent) -ForegroundColor DarkCyan
		Write-Host $Message -ForegroundColor Cyan
	}
	else {
		Write-Host ""
		Write-Host ("== {0}" -f $Message) -ForegroundColor Cyan
	}
}

function Complete-UiProgress {
	param([string]$Message = "Complete")

	$bar = Get-AsciiProgressBar -Percent 100
	Write-Progress -Activity "coolstats Rising Gods log updater" -Status $Message -PercentComplete 100 -Completed
	Write-Host ""
	Write-Host ("[{0}/{0}] {1} 100%" -f [Math]::Max($script:StepTotal, 1), $bar) -ForegroundColor Green
	Write-Host $Message -ForegroundColor Green
}

function Confirm-UpdatePlan {
	param(
		[string]$RepositoryRoot,
		[string]$AddOnsPath,
		[int]$MaxPerSpec,
		[int]$BulkTopLimit,
		[string[]]$BossName,
		[bool]$SkipApiValidation,
		[bool]$NoInstall,
		[bool]$Yes
	)

	Write-Host ""
	Write-Host "Update plan" -ForegroundColor Yellow
	Write-Host ("  Source folder:      {0}" -f $RepositoryRoot)
	Write-Host ("  Live install:       {0}" -f ($(if ($NoInstall) { "disabled (-NoInstall)" } else { $AddOnsPath })))
	Write-Host ("  Addon folder:       coolstats_Data_RisingGods only")
	Write-Host ("  UwU profile check:  {0}" -f ($(if ($SkipApiValidation) { "skipped" } else { "enabled" })))
	Write-Host ("  Ranked pull:        {0} players per class/spec" -f $MaxPerSpec)
	Write-Host ("  Boss pull limit:    {0} rows per boss/class/spec" -f $BulkTopLimit)
	$targetedNames = @($BossName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
	if ($targetedNames.Count -gt 0) {
		Write-Host ("  Targeted repairs:   {0}" -f ($targetedNames -join ", "))
	}
	else {
		Write-Host "  Targeted repairs:   none"
	}
	Write-Host ""
	Write-Host "This will not modify the core coolstats addon or the cache addon." -ForegroundColor Gray
	Write-Host "The previous live data addon is backed up before replacement." -ForegroundColor Gray

	if ($Yes) {
		Write-Host "Confirmation skipped because -Yes was provided." -ForegroundColor DarkGray
		return
	}

	$response = Read-Host "Continue with this update? Type Y to start"
	if ($response -notmatch "^(Y|YES)$") {
		throw "Update canceled by user before any refresh or live install."
	}
}

function Get-NormalizedFullPath {
	param([string]$Path)
	return [System.IO.Path]::GetFullPath($Path)
}

function Assert-PathUnderRoot {
	param(
		[string]$ChildPath,
		[string]$RootPath,
		[string]$Label
	)

	$resolvedRoot = (Get-NormalizedFullPath $RootPath).TrimEnd("\") + "\"
	$resolvedChild = Get-NormalizedFullPath $ChildPath
	$childForCompare = $resolvedChild.TrimEnd("\") + "\"
	if (-not $childForCompare.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "Unsafe $Label path outside expected root: $resolvedChild"
	}
	return $resolvedChild
}

function Join-SafeChildPath {
	param(
		[string]$RootPath,
		[string]$ChildName
	)

	if ([System.IO.Path]::IsPathRooted($ChildName) -or $ChildName.Contains("..") -or $ChildName.Contains("\") -or $ChildName.Contains("/")) {
		throw "Unsafe child path: $ChildName"
	}
	$joined = Join-Path $RootPath $ChildName
	return Assert-PathUnderRoot -ChildPath $joined -RootPath $RootPath -Label $ChildName
}

function Assert-UpdaterLayout {
	param([hashtable]$Layout)

	$required = @(
		"tools\update_rising_gods.ps1",
		"tools\update_uwu_logs.py",
		"tools\test_rising_gods_data_integrity.ps1",
		"tools\validate_lua51.ps1"
	)
	foreach ($relativePath in $required) {
		$path = Join-Path $Layout.Root $relativePath
		if (-not (Test-Path -LiteralPath $path)) {
			throw "Missing required Rising Gods file: $relativePath"
		}
	}

	if (-not (Test-Path -LiteralPath $Layout.CoreToc)) {
		throw "Missing coolstats core TOC: $($Layout.CoreToc)"
	}
	if (-not (Test-Path -LiteralPath $Layout.LiveDataAddon)) {
		throw "Missing Rising Gods data addon: $($Layout.LiveDataAddon)"
	}

	if ($Layout.Kind -eq "Source") {
		$realmRoot = Join-Path $Layout.Root "realm_data"
		$realmAddons = @(Get-ChildItem -LiteralPath $realmRoot -Directory -Filter "coolstats_Data_*")
		$unexpected = @($realmAddons | Where-Object { $_.Name -ne "coolstats_Data_RisingGods" })
		if ($unexpected.Count -gt 0) {
			throw "Refusing to update from a workspace containing non-Rising-Gods realm data: $($unexpected.Name -join ', ')"
		}
	}
}

function Resolve-LiveAddOnsPath {
	param(
		[string]$RequestedPath,
		[string]$RepositoryRoot
	)

	$configPath = Join-Path $RepositoryRoot "data\local_rising_gods_addons_path.txt"
	$path = $RequestedPath
	if ([string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $configPath)) {
		$path = (Get-Content -LiteralPath $configPath -ErrorAction SilentlyContinue | Select-Object -First 1)
		if (-not [string]::IsNullOrWhiteSpace($path)) {
			Write-Host "Using saved AddOns path: $path"
		}
	}

	if ([string]::IsNullOrWhiteSpace($path)) {
		Write-Host "Paste your World of Warcraft Interface\AddOns folder path."
		Write-Host "Use the folder named Interface\AddOns from your WoW install."
		$path = Read-Host "AddOns path"
	}

	if ([string]::IsNullOrWhiteSpace($path)) {
		throw "No AddOns path was provided. Run with -NoInstall to refresh local data only."
	}

	$path = $path.Trim().Trim('"')
	$fullPath = Get-NormalizedFullPath $path
	if ((Split-Path -Leaf $fullPath) -ne "AddOns") {
		throw "The path must be the Interface\AddOns folder, not the World of Warcraft root: $fullPath"
	}
	if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
		throw "AddOns folder does not exist: $fullPath"
	}
	return $fullPath
}

function Save-LiveAddOnsPath {
	param(
		[string]$AddOnsPath,
		[string]$RepositoryRoot
	)

	$dataDir = Join-Path $RepositoryRoot "data"
	New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
	Set-Content -LiteralPath (Join-Path $dataDir "local_rising_gods_addons_path.txt") -Value $AddOnsPath -Encoding ASCII
}

function Invoke-RisingGodsUpdateScript {
	param(
		[string]$RepositoryRoot,
		[string]$Mode,
		[string]$Python,
		[int]$MaxPerSpec,
		[int]$BulkTopLimit,
		[string[]]$BossName,
		[string]$LuaOutput = "",
		[string]$JsonOutput = "",
		[string]$BossCache = "",
		[string]$AddonVersion = "",
		[bool]$AllowInstalledLayout = $false
	)

	$script = Join-Path $RepositoryRoot "tools\update_rising_gods.ps1"
	$arguments = @{
		Mode = $Mode
		Python = $Python
	}
	if ($Mode -eq "Weekly" -or $Mode -eq "Scores") {
		$arguments["MaxPerSpec"] = $MaxPerSpec
	}
	if ($Mode -eq "Weekly") {
		$arguments["BulkTopLimit"] = $BulkTopLimit
	}
	if ($BossName -and $BossName.Count -gt 0) {
		$arguments["BossName"] = $BossName
	}
	if (-not [string]::IsNullOrWhiteSpace($LuaOutput)) {
		$arguments["LuaOutput"] = $LuaOutput
	}
	if (-not [string]::IsNullOrWhiteSpace($JsonOutput)) {
		$arguments["JsonOutput"] = $JsonOutput
	}
	if (-not [string]::IsNullOrWhiteSpace($BossCache)) {
		$arguments["BossCache"] = $BossCache
	}
	if (-not [string]::IsNullOrWhiteSpace($AddonVersion)) {
		$arguments["AddonVersion"] = $AddonVersion
	}
	if ($AllowInstalledLayout) {
		$arguments["AllowInstalledLayout"] = $true
	}

	Push-Location $RepositoryRoot
	try {
		& $script @arguments
		if ($LASTEXITCODE -ne 0) {
			throw "Rising Gods $Mode update failed."
		}
	}
	finally {
		Pop-Location
	}
}

function Assert-RisingGodsDataAddonShape {
	param(
		[string]$DataAddonPath,
		[int]$MinPlayers = 6000,
		[int]$MaxPlayers = 20000
	)

	$addonPath = Get-NormalizedFullPath $DataAddonPath
	$tocPath = Join-Path $addonPath "coolstats_Data_RisingGods.toc"
	$headerPath = Join-Path $addonPath "data\logs\icc\coolstats_uwu_data.lua"
	$chunkDir = Join-Path $addonPath "data\logs\icc"
	if (-not (Test-Path -LiteralPath $tocPath)) {
		throw "Missing Rising Gods data TOC: $tocPath"
	}
	if (-not (Test-Path -LiteralPath $headerPath)) {
		throw "Missing Rising Gods data header: $headerPath"
	}
	if (-not (Select-String -LiteralPath $tocPath -Pattern "^## X-coolstats-Realm:\s*Rising-Gods$" -Quiet)) {
		throw "Rising Gods realm metadata is missing or incorrect in $tocPath"
	}
	if (-not (Select-String -LiteralPath $tocPath -Pattern "^## X-coolstats-Phase:\s*icc$" -Quiet)) {
		throw "Rising Gods phase metadata is missing or incorrect in $tocPath"
	}

	$headerText = [System.IO.File]::ReadAllText($headerPath, [System.Text.Encoding]::UTF8)
	if (-not $headerText.Contains('realm = "Rising-Gods"')) {
		throw "Generated data header is not for Rising-Gods."
	}
	if (-not [regex]::IsMatch($headerText, "maxPerSpec\s*=\s*\d+")) {
		throw "Generated data header is missing maxPerSpec."
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
	foreach ($boss in $requiredBosses) {
		if (-not $headerText.Contains(('"{0}"' -f $boss))) {
			throw "Generated data header is missing boss: $boss"
		}
	}

	$chunks = @(Get-ChildItem -LiteralPath $chunkDir -File -Filter "coolstats_uwu_data_*.lua" | Sort-Object Name)
	if ($chunks.Count -lt 6) {
		throw "Expected at least 6 generated data chunks, found $($chunks.Count)."
	}

	$rowCount = 0
	foreach ($chunk in $chunks) {
		$text = [System.IO.File]::ReadAllText($chunk.FullName, [System.Text.Encoding]::UTF8)
		$rowCount += ([regex]::Matches($text, '(?m)^\s+\["[^"]+"\]\s=')).Count
		if ([regex]::IsMatch($text, '", 0, \d+, \d+, nil,')) {
			throw "Generated data contains rankless player rows in $($chunk.Name)."
		}
	}
	if ($rowCount -lt $MinPlayers) {
		throw "Generated data contains only $rowCount players; refusing to install."
	}
	if ($rowCount -gt $MaxPlayers) {
		throw "Generated data contains $rowCount players, above the safety ceiling of $MaxPlayers."
	}

	return $rowCount
}

function Invoke-RisingGodsDataIntegrityAudit {
	param(
		[string]$RepositoryRoot,
		[string]$DataAddonPath,
		[string]$ExpectedVersion = "",
		[int]$ExpectedMaxPerSpec = 600,
		[switch]$AllowTemporaryFolderName,
		[switch]$Quiet
	)

	$auditScript = Join-Path $RepositoryRoot "tools\test_rising_gods_data_integrity.ps1"
	if (-not (Test-Path -LiteralPath $auditScript)) {
		throw "Missing Rising Gods data integrity audit: $auditScript"
	}

	$arguments = @{
		DataAddonPath = $DataAddonPath
		ExpectedMaxPerSpec = $ExpectedMaxPerSpec
	}
	if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
		$arguments["ExpectedVersion"] = $ExpectedVersion
	}
	if ($Quiet) {
		$arguments["Quiet"] = $true
	}
	if ($AllowTemporaryFolderName) {
		$arguments["AllowTemporaryFolderName"] = $true
	}
	& $auditScript @arguments
}

function Assert-AddOnsWriteAccess {
	param([string]$AddOnsPath)

	$addonsRoot = Get-NormalizedFullPath $AddOnsPath
	$probe = Join-SafeChildPath -RootPath $addonsRoot -ChildName ("_coolstats_write_test_{0}" -f $PID)
	try {
		New-Item -ItemType Directory -Path $probe -Force | Out-Null
		Set-Content -LiteralPath (Join-Path $probe "probe.tmp") -Value "ok" -Encoding ASCII
	}
	catch {
		throw "Windows denied write access to the selected Interface\AddOns folder: $addonsRoot. If World of Warcraft is installed under Program Files, move the game/addon to a writable folder or run the official coolstats updater from an elevated terminal. Original error: $($_.Exception.Message)"
	}
	finally {
		if (Test-Path -LiteralPath $probe) {
			Remove-Item -LiteralPath $probe -Recurse -Force -ErrorAction SilentlyContinue
		}
	}
}

function Invoke-OptionalLua51Validation {
	param(
		[string]$RepositoryRoot,
		[string]$ValidationRoot = "",
		[string]$LuacPath,
		[bool]$RequireLua51
	)

	function Resolve-OptionalLuac51Path {
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
		return $null
	}

	if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
		$ValidationRoot = $RepositoryRoot
	}
	$ValidationRoot = Get-NormalizedFullPath $ValidationRoot
	$validator = Join-Path $RepositoryRoot "tools\validate_lua51.ps1"
	$resolvedLuac = Resolve-OptionalLuac51Path -RequestedPath $LuacPath
	if (-not $resolvedLuac) {
		if ($RequireLua51) {
			throw "Could not locate Lua 5.1 luac. Install luac 5.1, pass -LuacPath, or set LUAC51."
		}
		Write-Warning "Lua 5.1 compiler validation was skipped because luac 5.1 was not found."
		Write-Warning "Official releases still require Lua 5.1 validation; this local updater also keeps a live backup before install."
		return
	}

	if (Test-Path -LiteralPath (Join-Path $ValidationRoot "coolstats.toc")) {
		$arguments = @(
			"-NoProfile",
			"-ExecutionPolicy", "Bypass",
			"-File", $validator,
			"-PublishDirectory", $ValidationRoot,
			"-Quiet",
			"-LuacPath", $resolvedLuac
		)
		& powershell @arguments
		if ($LASTEXITCODE -ne 0) {
			throw "Lua 5.1 validation failed; refusing to install generated data."
		}
		return
	}

	$luaFiles = @(Get-ChildItem -LiteralPath $ValidationRoot -Recurse -File -Filter "*.lua" | Sort-Object FullName)
	if ($luaFiles.Count -eq 0) {
		throw "No Lua files found under $ValidationRoot."
	}
	foreach ($file in $luaFiles) {
		& $resolvedLuac -p $file.FullName
		if ($LASTEXITCODE -ne 0) {
			throw "Lua 5.1 validation failed for $($file.FullName); refusing to install generated data."
		}
	}
	Write-Host ("Lua 5.1 validation passed for {0} files." -f $luaFiles.Count)
}

function Install-RisingGodsDataAddon {
	param(
		[string]$RepositoryRoot,
		[string]$AddOnsPath,
		[string]$SourceDataAddon = "",
		[string]$ExpectedVersion = "",
		[int]$ExpectedMaxPerSpec = 600
	)

	$source = $SourceDataAddon
	if ([string]::IsNullOrWhiteSpace($source)) {
		$source = Join-Path $RepositoryRoot "realm_data\coolstats_Data_RisingGods"
	}
	$source = Get-NormalizedFullPath $source
	$addonsRoot = Get-NormalizedFullPath $AddOnsPath
	$target = Join-SafeChildPath -RootPath $addonsRoot -ChildName "coolstats_Data_RisingGods"
	$temp = Join-SafeChildPath -RootPath $addonsRoot -ChildName ("coolstats_Data_RisingGods.__coolstats_update_tmp_{0}" -f $PID)
	$backupRoot = Join-SafeChildPath -RootPath $addonsRoot -ChildName "_coolstats_backups"
	$backup = Join-SafeChildPath -RootPath $backupRoot -ChildName ("coolstats_Data_RisingGods_{0}_{1}" -f (Get-Date -Format "yyyyMMdd_HHmmss"), $PID)
	$oldMoved = $false

	if (-not (Test-Path -LiteralPath (Join-Path $addonsRoot "coolstats\coolstats.toc"))) {
		Write-Warning "The core coolstats addon folder was not found in this AddOns path. Install the official release ZIP if this is a new setup."
	}

	try {
		if (Test-Path -LiteralPath $temp) {
			try {
				Remove-Item -LiteralPath $temp -Recurse -Force
			}
			catch {
				throw "Could not clean the previous temporary update folder: $temp. Close World of Warcraft and any file browser windows using the folder, then try again. Original error: $($_.Exception.Message)"
			}
		}

		try {
			Copy-Item -LiteralPath $source -Destination $temp -Recurse -Force
		}
		catch {
			throw "Could not create the temporary update folder: $temp. Windows may be denying writes to this AddOns folder. If it is under Program Files, move the game/addon to a writable folder or run the official coolstats updater from an elevated terminal. Original error: $($_.Exception.Message)"
		}
		[void](Assert-RisingGodsDataAddonShape -DataAddonPath $temp)
		Invoke-RisingGodsDataIntegrityAudit -RepositoryRoot $RepositoryRoot -DataAddonPath $temp -ExpectedVersion $ExpectedVersion -ExpectedMaxPerSpec $ExpectedMaxPerSpec -AllowTemporaryFolderName -Quiet

		New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
		if (Test-Path -LiteralPath $target) {
			Move-Item -LiteralPath $target -Destination $backup
			$oldMoved = $true
			Write-Host "Backed up old data addon to: $backup"
		}

		Move-Item -LiteralPath $temp -Destination $target
		[void](Assert-RisingGodsDataAddonShape -DataAddonPath $target)
		Invoke-RisingGodsDataIntegrityAudit -RepositoryRoot $RepositoryRoot -DataAddonPath $target -ExpectedVersion $ExpectedVersion -ExpectedMaxPerSpec $ExpectedMaxPerSpec -Quiet
		Write-Host "Installed updated data addon to: $target"
	}
	catch {
		if (Test-Path -LiteralPath $temp) {
			Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
		}
		if ($oldMoved -and -not (Test-Path -LiteralPath $target) -and (Test-Path -LiteralPath $backup)) {
			Move-Item -LiteralPath $backup -Destination $target -ErrorAction SilentlyContinue
			Write-Warning "Restored previous data addon from backup."
		}
		throw
	}
}

try {
	Initialize-UiProgress -Steps (Get-RunStepLabels -ValidateOnly ([bool]$ValidateOnly) -SkipApiValidation ([bool]$SkipApiValidation) -NoInstall ([bool]$NoInstall))
	Write-UiHeader

	$layout = Get-UpdaterLayout
	$repositoryRoot = $layout.Root
	$addonVersion = Get-TocVersion -TocPath $layout.CoreToc
	if ([string]::IsNullOrWhiteSpace($addonVersion)) {
		throw "Could not read addon version from $($layout.CoreToc)."
	}
	Write-Step "Checking updater files"
	Assert-UpdaterLayout -Layout $layout

	if ($ValidateOnly) {
		Write-Step "Validating existing generated data"
		$sourceDataAddon = $layout.LiveDataAddon
		$players = Assert-RisingGodsDataAddonShape -DataAddonPath $sourceDataAddon
		Write-Host "Generated data contains $players ranked players."
		Invoke-RisingGodsDataIntegrityAudit -RepositoryRoot $repositoryRoot -DataAddonPath $sourceDataAddon -ExpectedVersion $addonVersion -ExpectedMaxPerSpec $MaxPerSpec
		$validationRoot = $(if ($layout.Kind -eq "Source") { $repositoryRoot } else { $sourceDataAddon })
		Invoke-OptionalLua51Validation -RepositoryRoot $repositoryRoot -ValidationRoot $validationRoot -LuacPath $LuacPath -RequireLua51 ([bool]$RequireLua51)
		Write-Step "Finishing validation-only run"
		Write-Host "ValidateOnly was set, so no network refresh or live install was performed."
		Complete-UiProgress -Message "Validation-only run complete."
		exit 0
	}

	$pythonCommand = Get-Command $Python -ErrorAction SilentlyContinue
	if (($Python -eq "python" -or [string]::IsNullOrWhiteSpace($Python)) -and -not [string]::IsNullOrWhiteSpace($env:COOLSTATS_PYTHON)) {
		$Python = $env:COOLSTATS_PYTHON
		$pythonCommand = Get-Command $Python -ErrorAction SilentlyContinue
	}
	if (-not $pythonCommand) {
		throw "Python was not found. Install Python 3 and make sure it is available as '$Python'."
	}

	Write-Step "Confirming update plan"
	$liveAddOnsPath = $null
	if (-not $NoInstall) {
		if (-not [string]::IsNullOrWhiteSpace($AddOnsPath)) {
			$liveAddOnsPath = Resolve-LiveAddOnsPath -RequestedPath $AddOnsPath -RepositoryRoot $repositoryRoot
		}
		elseif ($layout.Kind -eq "Installed") {
			$liveAddOnsPath = $layout.AddOnsRoot
			Write-Host "Using this release folder as AddOns path: $liveAddOnsPath"
		}
		else {
			$liveAddOnsPath = Resolve-LiveAddOnsPath -RequestedPath $AddOnsPath -RepositoryRoot $repositoryRoot
		}
	}
	Confirm-UpdatePlan -RepositoryRoot $repositoryRoot -AddOnsPath $liveAddOnsPath -MaxPerSpec $MaxPerSpec -BulkTopLimit $BulkTopLimit -BossName $BossName -SkipApiValidation ([bool]$SkipApiValidation) -NoInstall ([bool]$NoInstall) -Yes ([bool]$Yes)

	if (-not $NoInstall) {
		Write-Step "Checking live AddOns write access"
		Assert-AddOnsWriteAccess -AddOnsPath $liveAddOnsPath
	}

	$generatedDataAddon = $layout.WorkDataAddon
	$luaOutput = Join-Path $generatedDataAddon "data\logs\icc\coolstats_uwu_data.lua"
	$jsonOutput = $layout.JsonOutput
	$bossCache = $layout.BossCache
	$allowInstalledLayout = $layout.Kind -eq "Installed"

	if (-not $SkipApiValidation) {
		Write-Step "Validating Rising Gods UwU profile"
		Invoke-RisingGodsUpdateScript -RepositoryRoot $repositoryRoot -Mode "Validate" -Python $Python -MaxPerSpec $MaxPerSpec -BulkTopLimit $BulkTopLimit -BossName @() -AllowInstalledLayout $allowInstalledLayout
	}

	Write-Step "Refreshing Rising Gods logs"
	if ($layout.Kind -eq "Installed") {
		$workRoot = Join-Path $repositoryRoot "work"
		$resolvedWorkData = Assert-PathUnderRoot -ChildPath $generatedDataAddon -RootPath $workRoot -Label "generated data workspace"
		if (Test-Path -LiteralPath $resolvedWorkData) {
			Remove-Item -LiteralPath $resolvedWorkData -Recurse -Force
		}
	}
	Invoke-RisingGodsUpdateScript -RepositoryRoot $repositoryRoot -Mode "Weekly" -Python $Python -MaxPerSpec $MaxPerSpec -BulkTopLimit $BulkTopLimit -BossName $BossName -LuaOutput $luaOutput -JsonOutput $jsonOutput -BossCache $bossCache -AddonVersion $addonVersion -AllowInstalledLayout $allowInstalledLayout

	Write-Step "Validating generated data"
	$players = Assert-RisingGodsDataAddonShape -DataAddonPath $generatedDataAddon
	Write-Host "Generated data contains $players ranked players."
	Invoke-RisingGodsDataIntegrityAudit -RepositoryRoot $repositoryRoot -DataAddonPath $generatedDataAddon -ExpectedVersion $addonVersion -ExpectedMaxPerSpec $MaxPerSpec
	$validationRoot = $(if ($layout.Kind -eq "Source") { $repositoryRoot } else { $generatedDataAddon })
	Invoke-OptionalLua51Validation -RepositoryRoot $repositoryRoot -ValidationRoot $validationRoot -LuacPath $LuacPath -RequireLua51 ([bool]$RequireLua51)

	if ($NoInstall) {
		Write-Step "Finishing local refresh"
		Write-Host "NoInstall was set, so the live AddOns folder was not changed."
	}
	else {
		Write-Step "Installing live Rising Gods data addon"
		Install-RisingGodsDataAddon -RepositoryRoot $repositoryRoot -AddOnsPath $liveAddOnsPath -SourceDataAddon $generatedDataAddon -ExpectedVersion $addonVersion -ExpectedMaxPerSpec $MaxPerSpec
		if ($layout.Kind -eq "Source") {
			Save-LiveAddOnsPath -AddOnsPath $liveAddOnsPath -RepositoryRoot $repositoryRoot
		}
	}

	Write-Step "Finishing update"
	Complete-UiProgress -Message "Rising Gods log update complete."
}
catch {
	Write-Progress -Activity "coolstats Rising Gods log updater" -Completed
	Write-Host ""
	Write-Host "Update failed:" -ForegroundColor Red
	Write-Host $_.Exception.Message -ForegroundColor Red
	exit 1
}
