<#
.SYNOPSIS
  Validate manifests and build distributable zips into ./dist
  - dist/ui-ultra-<version>.zip : full multi-agent package (scripts + manifests + skill)
  - dist/ui-ultra-skill.zip     : skill folder only (manual install)
#>
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Dist = Join-Path $Root 'dist'
$Skill = Join-Path $Root 'skills\ui-ultra'

# --- validate ---
$md = Get-Content (Join-Path $Skill 'SKILL.md') -Raw -Encoding UTF8
if ($md -notmatch '(?s)^---\s*\r?\nname:\s*ui-ultra\s*\r?\n.*?description:.*?\r?\n---') { throw 'SKILL.md frontmatter invalid' }
$ge = Get-Content (Join-Path $Root 'gemini-extension.json') -Raw | ConvertFrom-Json
# Antigravity plugin.json is JSONC: strip // comments before parsing
$ag = ((Get-Content (Join-Path $Root 'plugin.json') -Encoding UTF8) | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json
$version = $ag.version
if ($ge.version -ne $version) { throw "Version mismatch: plugin.json=$version gemini-extension.json=$($ge.version)" }
Write-Host "Manifests OK (v$version)" -ForegroundColor Green

# --- build ---
if (Test-Path $Dist) { Remove-Item -Recurse -Force $Dist }
New-Item -ItemType Directory $Dist | Out-Null
$stage = Join-Path ([IO.Path]::GetTempPath()) ("ui-ultra-build-" + [guid]::NewGuid())
$pkg = Join-Path $stage 'ui-ultra'
New-Item -ItemType Directory -Force $pkg | Out-Null
foreach ($item in 'skills','plugin.json','gemini-extension.json','install.ps1','install.sh','README.md','LICENSE') {
  Copy-Item -Recurse (Join-Path $Root $item) $pkg
}
New-Item -ItemType Directory -Force (Join-Path $pkg 'assets') | Out-Null
Copy-Item (Join-Path $Root 'assets\*.svg') (Join-Path $pkg 'assets\')

Add-Type -AssemblyName System.IO.Compression.FileSystem
function New-Zip($srcDir, $zipPath) {
  # Build with forward-slash entry names so the zip extracts correctly on macOS/Linux
  $zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
  try {
    $base = (Split-Path $srcDir -Parent).TrimEnd('\') + '\'
    Get-ChildItem -Recurse -File -Force $srcDir | ForEach-Object {
      $entry = $_.FullName.Substring($base.Length).Replace('\','/')
      [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry, 'Optimal') | Out-Null
    }
  } finally { $zip.Dispose() }
}

New-Zip $pkg   (Join-Path $Dist "ui-ultra-$version.zip")
New-Zip $Skill (Join-Path $Dist 'ui-ultra-skill.zip')
Remove-Item -Recurse -Force $stage

Get-ChildItem $Dist | ForEach-Object { Write-Host ("  {0,-28} {1,8:N1} KB" -f $_.Name, ($_.Length/1KB)) }
