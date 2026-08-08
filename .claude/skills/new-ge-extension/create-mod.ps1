[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Mod,
  [string]$Ns,
  [string]$Name = "main",
  [string]$Title,
  [string]$Author = "TODO"
)

$ErrorActionPreference = "Stop"

function Assert-ValidModName {
  param([string]$ModName)
  if ($ModName -notmatch '^[a-z0-9][a-z0-9-]*$') {
    Write-Error "Mod name '$ModName' is invalid - use lowercase kebab-case (e.g. 'hello-hud')" -ErrorAction Continue
    exit 1
  }
}

function Get-CapitalizedSegments {
  param([string]$KebabName)
  return $KebabName -split '-' | Where-Object { $_.Length -gt 0 } | ForEach-Object {
    $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
  }
}

function ConvertTo-CamelCase {
  param([string]$KebabName)
  $segments = @($KebabName -split '-' | Where-Object { $_.Length -gt 0 })
  $head = $segments[0]
  $tail = $segments | Select-Object -Skip 1 | ForEach-Object {
    $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1)
  }
  return ($head + ($tail -join ''))
}

function ConvertTo-TitleCase {
  param([string]$KebabName)
  $words = Get-CapitalizedSegments -KebabName $KebabName
  return ($words -join ' ')
}

function New-ModInfoJson {
  param([string]$ModDir, [string]$JsonTitle, [string]$JsonAuthor)
  $info = [ordered]@{
    title       = $JsonTitle
    description = "BeamNG mod scaffolded from the beamng-llm-bridge template."
    author      = $JsonAuthor
    version     = "0.1.0"
    type        = "mod"
  }
  $json = $info | ConvertTo-Json
  $path = Join-Path $ModDir "info.json"
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($path, $json, $utf8NoBom)
  return $path
}

function New-ExtensionFromTemplate {
  param([string]$TemplatePath, [string]$DestPath, [string]$ExtNs, [string]$ExtName)
  $text = Get-Content -Raw -Path $TemplatePath
  $text = $text -replace "'template'", "'$ExtNs'"
  $headerPattern = [regex]::new(
    '\A-- Minimal GE-Lua extension template\.(\r?\n)--[^\r\n]*',
    [System.Text.RegularExpressions.RegexOptions]::None
  )
  $newHeader = "-- $ExtNs/$ExtName.lua - scaffolded from the beamng-llm-bridge template.`$1-- Module name once loaded: `"$ExtNs`_$ExtName`" (path separators -> underscores)."
  $text = $headerPattern.Replace($text, $newHeader, 1)
  $destDir = Split-Path -Parent $DestPath
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($DestPath, $text, $utf8NoBom)
}

function Write-NextSteps {
  param([string]$ModName, [string]$ExtNs, [string]$ExtName)
  $moduleName = "$ExtNs`_$ExtName"
  $destRoot = '$env:LOCALAPPDATA\BeamNG\BeamNG.drive\current\mods\unpacked\' + $ModName
  Write-Host ""
  Write-Host "Module name: $moduleName"
  Write-Host ""
  Write-Host "Next steps:"
  Write-Host "  robocopy `"<mod-dir>`" `"$destRoot`" /MIR"
  Write-Host "  extensions.load(`"$moduleName`")"
}

Assert-ValidModName -ModName $Mod

if (-not $Ns) { $Ns = ConvertTo-CamelCase -KebabName $Mod }
if (-not $Title) { $Title = ConvertTo-TitleCase -KebabName $Mod }

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$modDir = Join-Path $repoRoot "mods\$Mod"

if (Test-Path $modDir) {
  Write-Error "Mod folder '$Mod' already exists, refusing to overwrite" -ErrorAction Continue
  exit 1
}

New-Item -ItemType Directory -Force -Path $modDir | Out-Null

$infoPath = New-ModInfoJson -ModDir $modDir -JsonTitle $Title -JsonAuthor $Author

$templatePath = Join-Path $PSScriptRoot "template.lua"
$luaPath = Join-Path $modDir "lua\ge\extensions\$Ns\$Name.lua"
New-ExtensionFromTemplate -TemplatePath $templatePath -DestPath $luaPath -ExtNs $Ns -ExtName $Name

Write-Host "Created:"
Write-Host "  $infoPath"
Write-Host "  $luaPath"

Write-NextSteps -ModName $Mod -ExtNs $Ns -ExtName $Name

exit 0
