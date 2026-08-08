<#
.SYNOPSIS
  Scaffolds a new BeamNG mission folder (offline, no game required).

.DESCRIPTION
  Creates mods\<Mod>\gameplay\missions\<Level>\<Type>\<NNN>-<PascalName>\ with an
  info.json pre-applying the known launch fixes (vehicle-stash exemption, no
  forced provided vehicle) plus stand-in fixed files (obstacles.prefab.json,
  intro.camPath.json). This gets the mission close to launchable, but most
  mission types still need at least a real start position, and some need a
  live-placed type-specific file (e.g. precisionParking's spots.sites.json),
  before the mission will actually work in-game (see SKILL.md - Live
  placement). Creates mods\<Mod>\info.json too if the mod folder doesn't exist yet.

.PARAMETER Mod
  Mod folder name under mods\. Lowercase kebab-case, e.g. 'my-drills'.

.PARAMETER Level
  BeamNG level identifier, e.g. 'west_coast_usa'. Lowercase + underscores.

.PARAMETER Name
  Mission name, kebab-case, e.g. 'reverse-park'.

.PARAMETER Type
  Mission type folder, e.g. 'precisionParking'. Required — pick this from the
  interview in SKILL.md (the verified Tier A worked example, or a type name
  discovered live against the running engine for other built-in types).

.PARAMETER Title
  Display title. Defaults to the title-case form of -Name.

.EXAMPLE
  pwsh -File create-mission.ps1 -Mod my-drills -Level west_coast_usa -Name reverse-park -Type precisionParking
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Mod,
  [Parameter(Mandatory)][string]$Level,
  [Parameter(Mandatory)][string]$Name,
  [Parameter(Mandatory)][string]$Type,
  [string]$Title
)

$ErrorActionPreference = "Stop"

function Assert-Pattern {
  param([string]$Value, [string]$Pattern, [string]$Label)
  if ($Value -notmatch $Pattern) {
    Write-Error "$Label '$Value' is invalid (must match $Pattern)" -ErrorAction Continue
    exit 1
  }
}

function ConvertTo-TitleCase {
  param([string]$KebabName)
  $words = $KebabName -split '-' | Where-Object { $_.Length -gt 0 } | ForEach-Object {
    $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
  }
  return ($words -join ' ')
}

function ConvertTo-PascalCase {
  param([string]$KebabName)
  return (ConvertTo-TitleCase -KebabName $KebabName) -replace ' ', ''
}

function New-ModInfoJsonIfMissing {
  param([string]$ModDir, [string]$ModName)
  if (Test-Path $ModDir) { return }
  New-Item -ItemType Directory -Force -Path $ModDir | Out-Null
  $info = [ordered]@{
    title       = ConvertTo-TitleCase -KebabName $ModName
    description = "BeamNG mod containing missions."
    author      = "TODO"
    version     = "0.1.0"
    type        = "mod"
  }
  Write-JsonFile -Path (Join-Path $ModDir "info.json") -Data $info
}

function Write-JsonFile {
  param([string]$Path, $Data)
  $json = $Data | ConvertTo-Json -Depth 10
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Get-NextMissionNumber {
  param([string]$TypeDir)
  if (-not (Test-Path $TypeDir)) { return "001" }
  $existing = Get-ChildItem -Path $TypeDir -Directory | Where-Object { $_.Name -match '^\d{3}-' }
  if ($existing.Count -eq 0) { return "001" }
  $maxN = [int]($existing | ForEach-Object { [int]($_.Name.Substring(0, 3)) } | Measure-Object -Maximum).Maximum
  return "{0:D3}" -f ($maxN + 1)
}

function New-MissionInfoJson {
  # The setupModules.vehicles / missionTypeData.useProvidedVehicle fixes below are
  # frozen engine facts, not something this script re-derives — SKILL.md's Launch +
  # verify symptom table is the rot detector: if a check there starts failing, the
  # engine moved and this function needs re-verifying against it.
  param([string]$MissionDir, [hashtable]$Fields)
  $data = [ordered]@{
    name             = $Fields.Title
    description      = "Scaffolded mission - set the start position in-game."
    missionType      = $Fields.Type
    retryBehaviour   = "infiniteRetries"
    startCondition   = @{ type = "always" }
    visibleCondition = @{ type = "always" }
    startTrigger     = [ordered]@{
      type   = "coordinates"
      level  = $Fields.Level
      pos    = @(0, 0, 0)
      radius = 6
      rot    = @(0, 0, 0, 1)
    }
    careerSetup      = [ordered]@{ showInCareer = $false; showInFreeroam = $true }
    setupModules     = [ordered]@{
      vehicles = [ordered]@{
        enabled               = $true
        includePlayerVehicle  = $true
        prioritizePlayerVehicle = $true
        vehicles              = @()
      }
    }
    missionTypeData  = [ordered]@{ useProvidedVehicle = $false }
  }
  Write-JsonFile -Path (Join-Path $MissionDir "info.json") -Data $data
}

function New-StandInFixedFiles {
  param([string]$MissionDir)
  $obstacles = [ordered]@{ name = "SimGroup_"; class = "SimGroup"; groupPosition = "0 0 0" }
  Write-JsonFile -Path (Join-Path $MissionDir "obstacles.prefab.json") -Data $obstacles

  $marker = {
    param($time, $trackPosition)
    [ordered]@{
      fov           = 60
      pos           = [ordered]@{ x = 0; y = 0; z = 0 }
      rot           = [ordered]@{ x = 0; y = 0; z = 0; w = 1 }
      time          = $time
      trackPosition = $trackPosition
      movingStart   = $false
      movingEnd     = $false
    }
  }
  $camPath = [ordered]@{
    looped    = $false
    manualFov = $false
    markers   = @((& $marker 0 0), (& $marker 1 1))
  }
  Write-JsonFile -Path (Join-Path $MissionDir "intro.camPath.json") -Data $camPath
}

function Write-NextSteps {
  param([string]$Mod)
  $roboLine = '  (1) robocopy "<repo>\mods\' + $Mod + '" "$env:LOCALAPPDATA\BeamNG\BeamNG.drive\current\mods\unpacked\' + $Mod + '" /MIR'
  Write-Host ""
  Write-Host "Next steps:"
  Write-Host $roboLine
  Write-Host '  (2) in-game console: extensions.load("llmBridge_server") then:'
  Write-Host '      gameplay_missions_missions.reloadCompleteMissionSystem()'
  Write-Host '  (3) Follow SKILL.md - Live placement - to set the start position from your parked car.'
}

Assert-Pattern -Value $Mod -Pattern '^[a-z0-9][a-z0-9-]*$' -Label "Mod"
Assert-Pattern -Value $Name -Pattern '^[a-z0-9][a-z0-9-]*$' -Label "Name"
Assert-Pattern -Value $Level -Pattern '^[a-z0-9_]+$' -Label "Level"

if (-not $Title) { $Title = ConvertTo-TitleCase -KebabName $Name }

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$modDir = Join-Path $repoRoot "mods\$Mod"
New-ModInfoJsonIfMissing -ModDir $modDir -ModName $Mod

$pascalName = ConvertTo-PascalCase -KebabName $Name
$typeDir = Join-Path $modDir "gameplay\missions\$Level\$Type"
$nnn = Get-NextMissionNumber -TypeDir $typeDir

$missionId = "$Level/$Type/$nnn-$pascalName"
$missionDir = Join-Path $typeDir "$nnn-$pascalName"

if (Test-Path $missionDir) {
  Write-Error "Mission folder '$missionId' already exists, refusing to overwrite" -ErrorAction Continue
  exit 1
}

New-Item -ItemType Directory -Force -Path $missionDir | Out-Null
New-MissionInfoJson -MissionDir $missionDir -Fields @{ Title = $Title; Type = $Type; Level = $Level }
New-StandInFixedFiles -MissionDir $missionDir

Write-Host "Mission ID: $missionId"
Write-Host "Created:"
Write-Host "  $missionDir\info.json"
Write-Host "  $missionDir\obstacles.prefab.json"
Write-Host "  $missionDir\intro.camPath.json"

Write-NextSteps -Mod $Mod

exit 0
