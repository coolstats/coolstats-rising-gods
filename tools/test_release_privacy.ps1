param(
	[Parameter(Mandatory = $true)]
	[string]$RootPath,

	[switch]$Quiet
)

$ErrorActionPreference = "Stop"

$root = [System.IO.Path]::GetFullPath($RootPath)
if (-not (Test-Path -LiteralPath $root -PathType Container)) {
	throw "Missing release privacy scan root: $root"
}

$textExtensions = @{
	".bat" = $true
	".cmd" = $true
	".lua" = $true
	".md" = $true
	".ps1" = $true
	".py" = $true
	".toc" = $true
	".txt" = $true
	".xml" = $true
}

$patterns = @(
	@{ Name = "absolute Windows drive path"; Pattern = "(?<![A-Za-z])[A-Za-z]:[\\/]" },
	@{ Name = "Windows user profile path"; Pattern = "(?i)(^|[^A-Za-z])Users[\\/][^\\/]+[\\/]" },
	@{ Name = "macOS user profile path"; Pattern = "(?i)/Users/[^/]+/" },
	@{ Name = "Linux home profile path"; Pattern = "(?i)/home/[^/]+/" },
	@{ Name = "legacy WoW install path fragment"; Pattern = "(?i)World of Warcraft 3\.3\.5a" },
	@{ Name = "non-coolstats GitHub owner fragment"; Pattern = "(?i)github\.com/(?!coolstats/)[A-Za-z0-9_.-]+/" }
)

$localFragments = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
if (-not [string]::IsNullOrWhiteSpace($env:USERNAME) -and $env:USERNAME.Length -gt 2) {
	[void]$localFragments.Add($env:USERNAME)
}
if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
	$userProfile = [System.IO.Path]::GetFullPath($env:USERPROFILE)
	[void]$localFragments.Add($userProfile)
	$userLeaf = Split-Path -Leaf $userProfile
	if (-not [string]::IsNullOrWhiteSpace($userLeaf) -and $userLeaf.Length -gt 2) {
		[void]$localFragments.Add($userLeaf)
	}
}

$scanParent = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
foreach ($part in $scanParent.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) {
	if (-not [string]::IsNullOrWhiteSpace($part) -and $part.Length -gt 3 -and $part -notin @("Users", "tools")) {
		[void]$localFragments.Add($part)
	}
}

foreach ($fragment in $localFragments) {
	$patterns += @{
		Name = "local machine fragment"
		Pattern = [regex]::Escape($fragment)
	}
}

$failures = @()
$files = @(
	Get-ChildItem -LiteralPath $root -Recurse -File |
		Where-Object { $textExtensions.ContainsKey($_.Extension.ToLowerInvariant()) } |
		Sort-Object FullName
)

foreach ($file in $files) {
	$text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
	foreach ($pattern in $patterns) {
		if ([regex]::IsMatch($text, $pattern.Pattern)) {
			$relativePath = $file.FullName.Substring($root.Length + 1)
			$failures += ("{0}: {1}" -f $relativePath, $pattern.Name)
		}
	}
}

if ($failures.Count -gt 0) {
	throw ("Release privacy scan failed: " + ($failures -join "; "))
}

if (-not $Quiet) {
	Write-Output ("Release privacy scan passed: {0} text files checked." -f $files.Count)
}
