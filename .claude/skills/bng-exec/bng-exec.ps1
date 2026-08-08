# bng-exec.ps1 - send authenticated GE-Lua to the running BeamNG llmBridge
# and print its JSON response. The bridge must be loaded in-game first:
#   extensions.load("llmBridge_server")
#
# Usage:
#   pwsh -File .claude/skills/bng-exec/bng-exec.ps1 'return beamng_version'
#   pwsh -File .claude/skills/bng-exec/bng-exec.ps1 'print("hi"); return be:getPlayerVehicleID(0)'
#   pwsh -File .claude/skills/bng-exec/bng-exec.ps1 -Ping
#
# The client creates one cryptographically random capability for each loaded
# bridge session. The current capability is cached under LOCALAPPDATA so
# separate PowerShell invocations can share it; a new session overwrites it.

[CmdletBinding()]
param(
  [Parameter(Position = 0)] [string] $Lua,
  [switch] $Ping
)

$ErrorActionPreference = 'Stop'

$BridgeBase = 'http://127.0.0.1:23512'
$AuthProtocol = 'session-bearer-v1'
$TokenStatePath = Join-Path $env:LOCALAPPDATA 'beamng-llm-bridge\session.json'

function ConvertTo-ResponseText {
  param($Content)
  if ($Content -is [byte[]]) {
    return [System.Text.Encoding]::UTF8.GetString($Content)
  }
  return [string]$Content
}

function Invoke-BridgeRequest {
  param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Token
  )

  $headers = @{}
  if ($Token) { $headers.Authorization = "Bearer $Token" }

  try {
    $response = Invoke-WebRequest -Uri ($BridgeBase + $Path) -Headers $headers -TimeoutSec 10 -UseBasicParsing
  } catch {
    throw "Bridge request failed: $($_.Exception.Message) (is BeamNG running with llmBridge_server loaded?)"
  }

  $body = ConvertTo-ResponseText $response.Content
  try {
    $json = $body | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Bridge returned invalid JSON. Reload the updated llmBridge_server extension. Response: $body"
  }

  return [pscustomobject]@{ Body = $body; Json = $json }
}

function Get-CachedToken {
  if (-not (Test-Path -LiteralPath $TokenStatePath -PathType Leaf)) { return $null }
  try {
    $state = Get-Content -Raw -LiteralPath $TokenStatePath | ConvertFrom-Json -ErrorAction Stop
    $token = [string]$state.token
    if ($token -cmatch '^[0-9a-f]{64}$') { return $token }
  } catch {
    # An invalid cache is replaced after the server requests initialization.
  }
  return $null
}

function New-CapabilityToken {
  $bytes = [byte[]]::new(32)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return [Convert]::ToHexString($bytes).ToLowerInvariant()
}

function Save-CachedToken {
  param([Parameter(Mandatory)][string]$Token)

  $directory = Split-Path -Parent $TokenStatePath
  New-Item -ItemType Directory -Force -Path $directory | Out-Null
  $json = @{ token = $Token } | ConvertTo-Json -Compress
  $tempPath = "$TokenStatePath.$([guid]::NewGuid().ToString('N')).tmp"
  try {
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Move($tempPath, $TokenStatePath, $true)
  } finally {
    if (Test-Path -LiteralPath $tempPath) { [System.IO.File]::Delete($tempPath) }
  }
}

function Assert-AuthProtocol {
  param($Response)
  if ([string]$Response.Json.auth -ne $AuthProtocol) {
    throw 'The running bridge does not support authenticated sessions. Sync the mod and reload llmBridge_server.'
  }
}

function Connect-BridgeSession {
  $token = Get-CachedToken
  $pingResponse = Invoke-BridgeRequest -Path '/ping' -Token $token
  Assert-AuthProtocol $pingResponse

  if ($pingResponse.Json.ok -eq $true -and $pingResponse.Json.pong -eq $true) {
    return [pscustomobject]@{ Token = $token; PingBody = $pingResponse.Body }
  }

  if ($pingResponse.Json.sessionRequired -ne $true) {
    throw "Bridge authentication failed: $($pingResponse.Json.error)"
  }

  $token = New-CapabilityToken
  Save-CachedToken -Token $token

  $sessionResponse = Invoke-BridgeRequest -Path '/session' -Token $token
  Assert-AuthProtocol $sessionResponse
  if ($sessionResponse.Json.ok -ne $true) {
    throw "Bridge session initialization failed: $($sessionResponse.Json.error)"
  }

  $pingResponse = Invoke-BridgeRequest -Path '/ping' -Token $token
  Assert-AuthProtocol $pingResponse
  if ($pingResponse.Json.ok -ne $true -or $pingResponse.Json.pong -ne $true) {
    throw "Authenticated bridge ping failed: $($pingResponse.Json.error)"
  }

  return [pscustomobject]@{ Token = $token; PingBody = $pingResponse.Body }
}

try {
  if (-not $Ping -and -not $Lua) {
    throw 'Provide a Lua string, or use -Ping.'
  }

  $session = Connect-BridgeSession
  if ($Ping) {
    $session.PingBody
    exit 0
  }

  $encodedLua = [System.Uri]::EscapeDataString($Lua)
  $execResponse = Invoke-BridgeRequest -Path "/exec?lua=$encodedLua" -Token $session.Token
  $execResponse.Body
  if ($execResponse.Json.ok -ne $true) { exit 2 }
  exit 0
} catch {
  [Console]::Error.WriteLine("ERR: $($_.Exception.Message)")
  exit 1
}
