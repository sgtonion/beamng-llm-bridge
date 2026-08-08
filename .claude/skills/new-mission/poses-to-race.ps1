# Turns an ordered list of captured vehicle poses into a race.race.json
# route file in the on-disk shape BeamNG parses (VERIFIED v0.39.4.0).
#
# Input poses file: a JSON array, one entry per gate, in driving order:
#   [
#     { "name": "Start", "pos": [x,y,z], "normal": [x,y,z], "rot": [x,y,z,w] },
#     ...
#   ]
# Capture each entry live with the mark-loop snippet in SKILL.md ("Live
# placement" h) -- pos/normal/rot all come straight from the engine, so this
# script does no math.
#
# Encodes the format traps that cost real debugging time:
#   - pathnodes/segments/startPositions are PLAIN ARRAYS (never the runtime
#     object's .sorted shape, which parses as zero pathnodes with no error)
#   - segments reference pathnode oldId, not index
#   - every pathnode gets its own forward/reverse recovery entries in
#     startPositions -- recovery -1 places that gate 10 m underground
#
# Usage:
#   pwsh -File poses-to-race.ps1 -Poses poses.json -Out race.race.json -Name "My Drill"
#   Add -Closed for a loop course (adds the closing segment last->first).

param(
  [Parameter(Mandatory)][string]$Poses,
  [Parameter(Mandatory)][string]$Out,
  [Parameter(Mandatory)][string]$Name,
  [string]$Description = "",
  [string]$Authors = "",
  [double]$Radius = 7,
  [int]$DefaultLaps = 1,
  [switch]$Closed
)

$ErrorActionPreference = 'Stop'

function Get-NodeId([int]$i) { return 100 + $i }

function Get-PoseName($pose, [int]$i) {
  if ($pose.name) { return [string]$pose.name }
  return ($i -eq 1) ? 'Start' : "Checkpoint$($i - 1)"
}

function New-EmptyCustomFields {
  return [ordered]@{ names = @{}; tags = @{}; types = @{}; values = @{} }
}

function New-Pathnode($pose, [int]$i) {
  return [ordered]@{
    customFields    = New-EmptyCustomFields
    mode            = 'manual'
    name            = Get-PoseName $pose $i
    navRadiusScale  = 1
    normal          = @($pose.normal)
    oldId           = Get-NodeId $i
    pos             = @($pose.pos)
    radius          = $Radius
    recovery        = 2 * $i
    reverseRecovery = 2 * $i + 1
    sidePadding     = @(1, 1)
    visible         = $true
  }
}

function New-StartPosition([string]$posName, [int]$oldId, $pose) {
  return [ordered]@{
    name  = $posName
    oldId = $oldId
    pos   = @($pose.pos)
    rot   = @($pose.rot)
  }
}

# Reverse recovery reuses the forward rot; the verified shipped-format file
# does the same, and drills only run forward.
function New-RecoveryPair($pose, [int]$i) {
  $n = Get-PoseName $pose $i
  return @(
    (New-StartPosition "$n Recovery Forward" (2 * $i) $pose),
    (New-StartPosition "$n Recovery Reverse" (2 * $i + 1) $pose)
  )
}

function New-Segment([int]$i, [int]$fromIdx, [int]$toIdx) {
  return [ordered]@{
    capsules = @{}
    from     = Get-NodeId $fromIdx
    mode     = 'waypoint'
    name     = "Segment $i"
    oldId    = 200 + $i
    to       = Get-NodeId $toIdx
  }
}

function New-Segments([int]$count) {
  $segments = @()
  for ($i = 1; $i -lt $count; $i++) {
    $segments += , (New-Segment $i $i ($i + 1))
  }
  if ($Closed) { $segments += , (New-Segment $count $count 1) }
  return $segments
}

function New-StartPositions($poseList) {
  $entries = @(New-StartPosition 'Start Position fwd' 1 $poseList[0])
  for ($i = 1; $i -le $poseList.Count; $i++) {
    $entries += New-RecoveryPair $poseList[$i - 1] $i
  }
  return $entries
}

function New-RaceFile($poseList) {
  $pathnodes = @(); for ($i = 1; $i -le $poseList.Count; $i++) { $pathnodes += , (New-Pathnode $poseList[$i - 1] $i) }
  return [ordered]@{
    authors                     = $Authors
    classification              = @{}
    date                        = 0
    defaultLaps                 = $DefaultLaps
    defaultStartPosition        = 1
    description                 = $Description
    difficulty                  = 20
    endNode                     = -1
    forwardPrefabs              = @{}
    hideMission                 = $false
    name                        = $Name
    pacenotes                   = @{}
    pathnodes                   = $pathnodes
    prefabs                     = @{}
    reversePrefabs              = @{}
    reverseStartPosition        = 1
    rollingReverseStartPosition = 1
    rollingStartPosition        = 1
    segments                    = @(New-Segments $poseList.Count)
    startNode                   = Get-NodeId 1
    startPositions              = @(New-StartPositions $poseList)
  }
}

$poseList = @(Get-Content -Raw $Poses | ConvertFrom-Json)
if ($poseList.Count -lt 2) { throw "Need at least 2 poses; got $($poseList.Count)." }

New-RaceFile $poseList | ConvertTo-Json -Depth 8 | Set-Content -Path $Out -Encoding utf8
Write-Host "Wrote $Out ($($poseList.Count) pathnodes, $((@(New-Segments $poseList.Count)).Count) segments$($Closed ? ', closed loop' : ''))"
