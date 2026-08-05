param(
	[string]$RepositoryDirectory = (Join-Path $PSScriptRoot ".."),

	[string]$Version = "",

	[string]$ZipPath = "",

	[string]$Branch = "warperia",

	[string]$WorktreeDirectory = (Join-Path $PSScriptRoot "..\..\.warperia_coolstats_rising_gods_branch"),

	[string]$ExpectedRemote = "https://github.com/coolstats/coolstats-rising-gods.git",

	[switch]$Push,

	[switch]$KeepWorktree
)

$ErrorActionPreference = "Stop"

$expectedName = "coolstats"
$expectedEmail = "coolstats@users.noreply.github.com"

function Get-FullPath {
	param([string]$Path)
	return [System.IO.Path]::GetFullPath($Path)
}

function Invoke-Git {
	param(
		[string]$Directory,
		[string[]]$Arguments
	)
	$output = & git -C $Directory @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "git -C $Directory $($Arguments -join ' ') failed: $output"
	}
	return $output
}

function Assert-PathInside {
	param(
		[string]$Path,
		[string]$Parent,
		[string]$Label
	)
	$fullPath = Get-FullPath -Path $Path
	$fullParent = Get-FullPath -Path $Parent
	if (-not $fullPath.StartsWith($fullParent, [System.StringComparison]::OrdinalIgnoreCase)) {
		throw "$Label path must stay inside $fullParent, got $fullPath"
	}
}

function Remove-DirectoryIfPresent {
	param(
		[string]$Path,
		[string]$Parent,
		[string]$Label
	)
	if (Test-Path -LiteralPath $Path) {
		Assert-PathInside -Path $Path -Parent $Parent -Label $Label
		Remove-Item -LiteralPath $Path -Recurse -Force
	}
}

function Assert-SourceRepository {
	param([string]$Path)

	$origin = (Invoke-Git -Directory $Path -Arguments @("remote", "get-url", "origin") | Select-Object -First 1).Trim()
	if ($origin -ne $ExpectedRemote) {
		throw "origin remote must be '$ExpectedRemote', got '$origin'."
	}
	$branchName = (Invoke-Git -Directory $Path -Arguments @("branch", "--show-current") | Select-Object -First 1).Trim()
	if ($branchName -ne "main") {
		throw "Source repository must be on main, got '$branchName'."
	}
	Invoke-Git -Directory $Path -Arguments @("config", "user.name", $expectedName) | Out-Null
	Invoke-Git -Directory $Path -Arguments @("config", "user.email", $expectedEmail) | Out-Null
}

function Validate-InstallRoot {
	param([string]$Path)

	$allowedRootFiles = @(
		"README.md",
		"Update_Rising_Gods_Logs.bat",
		"Update_Rising_Gods_Logs.sh"
	)
	$rootFiles = Get-ChildItem -LiteralPath $Path -Force -File |
		Where-Object { $allowedRootFiles -notcontains $_.Name }
	if ($rootFiles.Count -gt 0) {
		throw "Warperia install root has unexpected files: $($rootFiles.Name -join ', ')"
	}

	$folders = Get-ChildItem -LiteralPath $Path -Force -Directory | Sort-Object Name
	if ($folders.Count -eq 0) {
		throw "Warperia install root has no addon folders."
	}
	foreach ($required in @("coolstats", "coolstats_Cache", "coolstats_Data_RisingGods", "coolstats_LogUpdater")) {
		if ($folders.Name -notcontains $required) {
			throw "Warperia install root must contain $required."
		}
	}
	foreach ($forbidden in @("cache_addon", "data", "realm_data", "releases", "tools", ".pytest_cache")) {
		if ($folders.Name -contains $forbidden) {
			throw "Warperia install root must not contain source workspace folder $forbidden."
		}
	}

	$allowedDataPrefix = "coolstats_Data_RisingGods_UWU_"
	foreach ($folder in $folders) {
		if ($folder.Name -eq "coolstats_LogUpdater") {
			continue
		}
		if ($folder.Name -ne "coolstats" -and
			$folder.Name -ne "coolstats_Cache" -and
			$folder.Name -ne "coolstats_Data_RisingGods" -and
			-not $folder.Name.StartsWith($allowedDataPrefix, [System.StringComparison]::Ordinal)) {
			throw "Unexpected install folder: $($folder.Name)"
		}
		$tocPath = Join-Path $folder.FullName ($folder.Name + ".toc")
		if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
			throw "Addon folder $($folder.Name) is missing $($folder.Name).toc"
		}
	}

	return $folders.Name
}

function Write-WarperiaReadme {
	param(
		[string]$Path,
		[string]$SourceReadmePath
	)

	if (-not (Test-Path -LiteralPath $SourceReadmePath -PathType Leaf)) {
		throw "Source README does not exist: $SourceReadmePath"
	}

	$content = [System.IO.File]::ReadAllText($SourceReadmePath)
	$content = $content.Replace('src="assets/', 'src="coolstats/assets/')
	$content = $content.Replace('](assets/', '](coolstats/assets/')
	$readmePath = Join-Path $Path "README.md"
	$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
	[System.IO.File]::WriteAllText($readmePath, $content, $utf8NoBom)
}

$repoPath = Get-FullPath -Path $RepositoryDirectory
if (-not (Test-Path -LiteralPath $repoPath -PathType Container)) {
	throw "Repository directory does not exist: $repoPath"
}

if ([string]::IsNullOrWhiteSpace($ZipPath)) {
	if ([string]::IsNullOrWhiteSpace($Version)) {
		throw "Pass -Version or -ZipPath."
	}
	$ZipPath = Join-Path $repoPath ("releases\coolstats_rising_gods_{0}.zip" -f $Version)
}
$zipFullPath = Get-FullPath -Path $ZipPath
if (-not (Test-Path -LiteralPath $zipFullPath -PathType Leaf)) {
	throw "Release ZIP does not exist: $zipFullPath"
}
if ([string]::IsNullOrWhiteSpace($Version)) {
	$zipName = [System.IO.Path]::GetFileNameWithoutExtension($zipFullPath)
	if ($zipName -match '^coolstats_rising_gods_(.+)$') {
		$Version = $Matches[1]
	} else {
		throw "Could not infer version from ZIP name. Pass -Version."
	}
}

Assert-SourceRepository -Path $repoPath

$releaseValidator = Join-Path $PSScriptRoot "validate_rising_gods_release.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $releaseValidator -Version $Version -ZipPath $zipFullPath
if ($LASTEXITCODE -ne 0) {
	throw "Rising Gods release validation failed; refusing to publish Warperia branch."
}

$workspaceRoot = Get-FullPath -Path (Join-Path $repoPath "..")
$stageRoot = Join-Path $workspaceRoot (".warperia_rising_gods_stage_{0}" -f ($Version -replace '[^0-9A-Za-z._-]', '_'))
$worktreePath = Get-FullPath -Path $WorktreeDirectory

Remove-DirectoryIfPresent -Path $stageRoot -Parent $workspaceRoot -Label "Staging"
New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFullPath, $stageRoot)
Write-WarperiaReadme -Path $stageRoot -SourceReadmePath (Join-Path $repoPath "README.md")
$folderNames = Validate-InstallRoot -Path $stageRoot

Invoke-Git -Directory $repoPath -Arguments @("fetch", "origin") | Out-Null

if (Test-Path -LiteralPath $worktreePath) {
	& git -C $repoPath worktree remove --force $worktreePath *> $null
	if ($LASTEXITCODE -ne 0 -and (Test-Path -LiteralPath $worktreePath)) {
		Remove-DirectoryIfPresent -Path $worktreePath -Parent $workspaceRoot -Label "Warperia worktree"
	}
}

& git -C $repoPath rev-parse --verify --quiet "refs/remotes/origin/$Branch" *> $null
$remoteBranchExists = ($LASTEXITCODE -eq 0)
if ($remoteBranchExists) {
	Invoke-Git -Directory $repoPath -Arguments @("worktree", "add", "--force", "-B", $Branch, $worktreePath, "origin/$Branch") | Out-Null
} else {
	Invoke-Git -Directory $repoPath -Arguments @("worktree", "add", "--force", "--detach", $worktreePath, "HEAD") | Out-Null
	Invoke-Git -Directory $worktreePath -Arguments @("checkout", "--orphan", $Branch) | Out-Null
}

Invoke-Git -Directory $worktreePath -Arguments @("config", "user.name", $expectedName) | Out-Null
Invoke-Git -Directory $worktreePath -Arguments @("config", "user.email", $expectedEmail) | Out-Null

Get-ChildItem -LiteralPath $worktreePath -Force |
	Where-Object { $_.Name -ne ".git" } |
	ForEach-Object {
		Remove-Item -LiteralPath $_.FullName -Recurse -Force
	}

Get-ChildItem -LiteralPath $stageRoot -Force |
	ForEach-Object {
		Copy-Item -LiteralPath $_.FullName -Destination $worktreePath -Recurse -Force
	}

Validate-InstallRoot -Path $worktreePath | Out-Null

$env:GIT_AUTHOR_NAME = $expectedName
$env:GIT_AUTHOR_EMAIL = $expectedEmail
$env:GIT_COMMITTER_NAME = $expectedName
$env:GIT_COMMITTER_EMAIL = $expectedEmail

Invoke-Git -Directory $worktreePath -Arguments @("add", "--all") | Out-Null
& git -C $worktreePath diff --cached --quiet
$hasChanges = ($LASTEXITCODE -ne 0)
if ($hasChanges) {
	Invoke-Git -Directory $worktreePath -Arguments @("commit", "-m", "Update Warperia install branch for coolstats Rising Gods $Version") | Out-Null
	Write-Output "Committed Warperia branch update for coolstats Rising Gods $Version."
} else {
	Write-Output "Warperia branch already matches coolstats Rising Gods $Version."
}

$headLine = (Invoke-Git -Directory $worktreePath -Arguments @("log", "-1", "--format=%H`t%an`t%ae`t%cn`t%ce`t%s") | Select-Object -First 1)
if ($headLine -notmatch "^[0-9a-f]+`t$expectedName`t$([regex]::Escape($expectedEmail))`t$expectedName`t$([regex]::Escape($expectedEmail))`t") {
	throw "Warperia branch commit does not have the expected coolstats identity: $headLine"
}

if ($Push) {
	Invoke-Git -Directory $worktreePath -Arguments @("push", "-u", "origin", $Branch) | Out-Null
	Write-Output "Pushed $Branch to origin."
}

Remove-DirectoryIfPresent -Path $stageRoot -Parent $workspaceRoot -Label "Staging"
if (-not $KeepWorktree) {
	Invoke-Git -Directory $repoPath -Arguments @("worktree", "remove", "--force", $worktreePath) | Out-Null
	Write-Output "Removed generated Warperia worktree."
} else {
	Write-Output "Kept generated Warperia worktree: $worktreePath"
}

Write-Output "Warperia branch folder count: $($folderNames.Count)"
Write-Output "Warperia branch source: $zipFullPath"
