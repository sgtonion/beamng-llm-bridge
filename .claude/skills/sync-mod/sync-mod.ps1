<#
.SYNOPSIS
  Syncs the repo's mods/<name>/ folder into the BeamNG unpacked-mods folder for live testing.

.DESCRIPTION
  Mirrors mods/<name>/ -> <userfolder>\mods\unpacked\<name> using robocopy /MIR, so the
  installed copy is an EXACT match of the repo (stale/renamed files are removed). Dev-only
  docs (*.md) are excluded so the install contains only real mod content (info.json, lua/, ui/).

  After running, reload in the BeamNG console (~ key) with:
      extensions.reload("llmBridge_server")
  No BeamNG restart needed for GE-Lua changes.

.PARAMETER Mod
  Name of the mod folder under mods\ to sync. Defaults to 'llm-bridge'.

.PARAMETER Dest
  Override the install target. Defaults to the documented BeamNG userfolder 'current' alias.
  For mirror safety, the normalized path must end in mods\unpacked\<Mod> and a
  non-default target also requires -AllowCustomDest.

.PARAMETER AllowCustomDest
  Explicitly permits a validated destination outside the default BeamNG userfolder.

.PARAMETER DryRun
  Show what would change without copying (robocopy /L).

.EXAMPLE
  pwsh -File sync-mod.ps1
  pwsh -File sync-mod.ps1 -DryRun
  pwsh -File sync-mod.ps1 -Mod llm-bridge -Dest "D:\BeamNG-userfolder\mods\unpacked\llm-bridge" -AllowCustomDest
#>
[CmdletBinding()]
param(
  [string]$Mod = "llm-bridge",
  [string]$Dest,
  [switch]$AllowCustomDest,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Get-NormalizedFullPath {
  param([Parameter(Mandatory)][string]$Path)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $root = [System.IO.Path]::GetPathRoot($fullPath)
  if ($fullPath.Length -gt $root.Length) {
    return $fullPath.TrimEnd([char[]]@('\', '/'))
  }
  return $fullPath
}

function Test-PathInside {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Parent
  )
  $prefix = $Parent.TrimEnd([char[]]@('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
  return $Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

if ($Mod -notmatch '^[a-z0-9][a-z0-9-]*$') {
  throw "Mod name '$Mod' is invalid - use lowercase kebab-case (e.g. 'llm-bridge')"
}

$defaultDest = Get-NormalizedFullPath "$env:LOCALAPPDATA\BeamNG\BeamNG.drive\current\mods\unpacked\$Mod"
if (-not $Dest) { $Dest = $defaultDest }
if ([System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Dest)) {
  throw "Destination must be a literal path without wildcard characters: $Dest"
}

# This script lives at <repo-root>\.claude\skills\sync-mod\, so the repo root is three
# Split-Path -Parent hops up. Source is mods\<Mod> relative to that root, so the script
# works regardless of the caller's current directory.
$repoRoot = Get-NormalizedFullPath (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$modsRoot = Get-NormalizedFullPath (Join-Path $repoRoot "mods")
$source = Get-NormalizedFullPath (Join-Path $modsRoot $Mod)
$Dest = Get-NormalizedFullPath $Dest

if (-not [string]::Equals($Dest, $defaultDest, [System.StringComparison]::OrdinalIgnoreCase) -and
    -not $AllowCustomDest) {
  throw "Custom destination requires -AllowCustomDest after reviewing the /MIR target: $Dest"
}

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
  throw "Source mod folder not found: $source"
}
if (-not (Test-PathInside -Path $source -Parent $modsRoot)) {
  throw "Source must remain inside the repository's mods folder: $source"
}

$destParent = Split-Path -Parent $Dest
$destGrandParent = Split-Path -Parent $destParent
$destLeaf = Split-Path -Leaf $Dest
if (-not [string]::Equals($destLeaf, $Mod, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not [string]::Equals((Split-Path -Leaf $destParent), 'unpacked', [System.StringComparison]::OrdinalIgnoreCase) -or
    -not [string]::Equals((Split-Path -Leaf $destGrandParent), 'mods', [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Destination must end in 'mods\unpacked\$Mod'; refusing mirror target: $Dest"
}
if ([string]::Equals($source, $Dest, [System.StringComparison]::OrdinalIgnoreCase) -or
    (Test-PathInside -Path $source -Parent $Dest) -or
    (Test-PathInside -Path $Dest -Parent $source)) {
  throw "Source and destination must not overlap: source=$source destination=$Dest"
}

Write-Host "Source: $source"
Write-Host "Target: $Dest"
Write-Host ("Mode:   MIRROR (exact copy), excluding *.md" + $(if ($DryRun) { "  [DRY RUN]" } else { "" }))

# /MIR  = mirror (copy + purge extras in target)
# /XF   = exclude files by pattern (dev-only docs)
# /NFL /NDL /NJH /NJS = quiet output (no per-file/dir lists, no header/summary)
# /L    = list only (dry run), added conditionally
$roboArgs = @($source, $Dest, "/MIR", "/XF", "*.md", "/NFL", "/NDL", "/NJH", "/NJS")
if ($DryRun) { $roboArgs += "/L" }

robocopy @roboArgs | Out-Host

# robocopy exit codes: 0-7 are success (8+ are real errors). $LASTEXITCODE is the raw code.
$code = $LASTEXITCODE
if ($code -ge 8) {
  Write-Error "robocopy failed with exit code $code"
  exit $code
}

if ($DryRun) {
  Write-Host "Dry run complete — no files changed." -ForegroundColor Yellow
} else {
  Write-Host "Sync complete." -ForegroundColor Green
  if ($Mod -eq "llm-bridge") {
    Write-Host 'In the BeamNG console (~): extensions.reload("llmBridge_server")'
  } else {
    Write-Host 'In the BeamNG console (~): extensions.reload("<ns>_<file>") for the extension you edited'
  }
}
exit 0
