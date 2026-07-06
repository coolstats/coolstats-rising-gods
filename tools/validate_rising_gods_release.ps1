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
	$expectedFolders = @("coolstats", "coolstats_Cache", "coolstats_Data_RisingGods")
	$actualFolders = @(Get-ChildItem -LiteralPath $validationRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object)
	$expectedSorted = @($expectedFolders | Sort-Object)
	if (($actualFolders -join "|") -ne ($expectedSorted -join "|")) {
		throw "Unexpected top-level addon folders. Expected $($expectedSorted -join ', '); found $($actualFolders -join ', ')."
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

	$requiredData = @(
		"coolstats_uwu_data.lua",
		"coolstats_uwu_data_01.lua",
		"coolstats_uwu_data_02.lua",
		"coolstats_uwu_data_03.lua",
		"coolstats_uwu_data_04.lua",
		"coolstats_uwu_data_05.lua",
		"coolstats_uwu_data_06.lua"
	)
	foreach ($file in $requiredData) {
		$path = Join-Path $validationRoot "coolstats_Data_RisingGods\data\logs\icc\$file"
		if (-not (Test-Path -LiteralPath $path)) {
			throw "Missing generated Rising Gods data file: $file"
		}
	}
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
