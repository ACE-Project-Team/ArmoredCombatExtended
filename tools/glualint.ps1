param(
	[switch] $Update,
	[string[]] $Path
)

$ErrorActionPreference = "Stop"

$Version = "1.29.0"
$ExpectedSha256 = "31326F158620423DFE78215A11F1C16EF3371EA3D8B5AE0CD8EF60852EB1C3FF"
$ExpectedBinarySha256 = "5A8F3AD0B25409139D2BB42017A3AB051BC7655F669EAF6C76969D896A29335F"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot ".." )).Path
$CacheRoot = Join-Path $PSScriptRoot ".cache\glualint\$Version"
$Archive = Join-Path $CacheRoot "glualint-$Version-Windows.zip"
$Binary = Join-Path $CacheRoot "glualint.exe"
$Config = Join-Path $RepoRoot ".glualint.json"

if ($Update -and (Test-Path -LiteralPath $CacheRoot)) {
	Remove-Item -LiteralPath $CacheRoot -Recurse -Force
}

if (-not (Test-Path -LiteralPath $Binary)) {
	New-Item -ItemType Directory -Path $CacheRoot -Force | Out-Null
	$Download = "https://github.com/FPtje/GLuaFixer/releases/download/$Version/glualint-$Version-Windows.zip"
	Invoke-WebRequest -Uri $Download -OutFile $Archive
	$ActualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Archive).Hash
	if ($ActualSha256 -ne $ExpectedSha256) {
		Remove-Item -LiteralPath $Archive -Force
		throw "GLuaFixer archive checksum mismatch: expected $ExpectedSha256, got $ActualSha256"
	}
	Expand-Archive -LiteralPath $Archive -DestinationPath $CacheRoot -Force
}

$ActualBinarySha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Binary).Hash
if ($ActualBinarySha256 -ne $ExpectedBinarySha256) {
	throw "GLuaFixer executable checksum mismatch: expected $ExpectedBinarySha256, got $ActualBinarySha256"
}

if (-not (Test-Path -LiteralPath $Config)) {
	throw "Missing GLuaFixer config: $Config"
}

if (-not $Path) {
	$EntityPaths = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot "lua/entities") -Directory |
		Where-Object Name -ne "gmod_wire_expression2" |
		ForEach-Object { "lua/entities/$($_.Name)" })
	$Path = @(
		"lua/acf",
		"lua/autorun",
		"lua/cfw",
		"lua/effects",
		"lua/starfall",
		"lua/tests",
		"lua/weapons",
		"tests/lua",
		"tests/gluatest_overrides/lua"
	) + $EntityPaths
}

$ExcludedPrefix = "lua/entities/gmod_wire_expression2"
$RepoPrefix = $RepoRoot.TrimEnd("\", "/") + "\"
$Path = @($Path | ForEach-Object {
	$CandidatePath = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $RepoRoot $_ }
	$ResolvedPath = (Resolve-Path -LiteralPath $CandidatePath).Path
	if (-not ($ResolvedPath.Equals($RepoRoot, [StringComparison]::OrdinalIgnoreCase) -or
		$ResolvedPath.StartsWith($RepoPrefix, [StringComparison]::OrdinalIgnoreCase))) {
		throw "GLuaFixer path is outside the repository: $_"
	}

	$RelativePath = $ResolvedPath.Substring($RepoRoot.Length).TrimStart("\", "/").Replace("\", "/")
	if ($RelativePath -ne $ExcludedPrefix -and -not $RelativePath.StartsWith("$ExcludedPrefix/")) {
		$_
	}
})

if (-not $Path) {
	throw "No files selected for GLuaFixer"
}

Push-Location $RepoRoot
try {
	& $Binary --output-format standard --config $Config lint $Path
	exit $LASTEXITCODE
}
finally {
	Pop-Location
}
