<#
.SYNOPSIS
  Copies a mission the in-game editor saved into the userfolder back into the repo.

.DESCRIPTION
  The in-game Mission Editor / Sites Editor / Scenetree write directly to the
  BeamNG userfolder, never to the repo. After live-placing a start position,
  sites file, or prefab in-game, run this to mirror
  <userfolder>\gameplay\missions\<MissionId> -> mods\<Mod>\gameplay\missions\<MissionId>
  so the repo has the authored content.

.PARAMETER Mod
  Mod folder name under mods\ that owns this mission.

.PARAMETER MissionId
  Forward-slash mission id, e.g. west_coast_usa/precisionParking/001-ReversePark.

.PARAMETER DryRun
  Show what would change without copying (robocopy /L).

.EXAMPLE
  pwsh -File vendor-mission.ps1 -Mod my-drills -MissionId west_coast_usa/precisionParking/001-ReversePark
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Mod,
  [Parameter(Mandatory)][string]$MissionId,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ($Mod -notmatch '^[a-z0-9][a-z0-9-]*$') {
  Write-Error "Mod name '$Mod' is invalid - use lowercase kebab-case (e.g. 'my-drills')" -ErrorAction Continue
  exit 1
}

if ($MissionId -notmatch '^[a-z0-9_]+/[A-Za-z0-9]+/\d{3}-[A-Za-z0-9]+$') {
  Write-Error "MissionId '$MissionId' is invalid (expected level/type/NNN-Name)" -ErrorAction Continue
  exit 1
}

$relPath = $MissionId -replace '/', '\'
$userfolder = "$env:LOCALAPPDATA\BeamNG\BeamNG.drive\current"
$src = Join-Path $userfolder "gameplay\missions\$relPath"

if (-not (Test-Path $src)) {
  Write-Error "Source not found: $src`nThe in-game editor has not saved this mission yet (File -> Save Mission)." -ErrorAction Continue
  exit 1
}

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))))
$modsRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot "mods"))
$dest = [System.IO.Path]::GetFullPath((Join-Path $modsRoot "$Mod\gameplay\missions\$relPath"))
$modsPrefix = $modsRoot.TrimEnd([char[]]@('\', '/')) + [System.IO.Path]::DirectorySeparatorChar
if (-not $dest.StartsWith($modsPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  Write-Error "Destination escaped the repository's mods folder: $dest" -ErrorAction Continue
  exit 1
}

Write-Host "Source: $src"
Write-Host "Target: $dest"
Write-Host ("Mode:   MIRROR (exact copy)" + $(if ($DryRun) { "  [DRY RUN]" } else { "" }))

$roboArgs = @($src, $dest, "/MIR", "/NFL", "/NDL", "/NJH", "/NJS")
if ($DryRun) { $roboArgs += "/L" }

robocopy @roboArgs | Out-Host

$code = $LASTEXITCODE
if ($code -ge 8) {
  Write-Error "robocopy failed with exit code $code"
  exit $code
}

if ($DryRun) {
  Write-Host "Dry run complete - no files changed." -ForegroundColor Yellow
} else {
  Write-Host "Vendor complete: $MissionId copied into mods\$Mod." -ForegroundColor Green
  Write-Host "Re-deploy the mod (robocopy repo mod -> unpacked) so the game and repo stay in sync."
}
exit 0
