$ErrorActionPreference = "Stop"

$stateRoot = Join-Path $env:USERPROFILE ".claude-cowork-zh-patch"
$manifest = Join-Path $stateRoot "latest.json"

function Assert-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    Start-Process -FilePath powershell.exe -ArgumentList $args -Verb RunAs -Wait
    exit $LASTEXITCODE
  }
}

function Grant-WriteAccess($target) {
  & takeown.exe /F $target /A | Out-Host
  & icacls.exe $target /grant "*S-1-5-32-544:F" /C | Out-Host
  attrib.exe -R $target
}

Assert-Admin

if (-not (Test-Path -LiteralPath $manifest)) {
  throw "No restore manifest found: $manifest"
}

$data = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
$app = $data.app
$backup = $data.backup
$exe = Join-Path $app "Claude.exe"
$resources = Join-Path $app "resources"
$asar = Join-Path $resources "app.asar"
$enLocale = Join-Path $resources "en-US.json"
$zhLocale = Join-Path $resources "zh-CN.json"

foreach ($required in @((Join-Path $backup "Claude.exe"), (Join-Path $backup "app.asar"))) {
  if (-not (Test-Path -LiteralPath $required)) { throw "Missing backup file: $required" }
}

Get-Process | Where-Object { $_.ProcessName -ieq "claude" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

foreach ($target in @($exe, $asar, $enLocale, $zhLocale, $resources)) {
  if (Test-Path -LiteralPath $target) { Grant-WriteAccess $target }
}

Copy-Item -LiteralPath (Join-Path $backup "Claude.exe") -Destination $exe -Force
Copy-Item -LiteralPath (Join-Path $backup "app.asar") -Destination $asar -Force
if (Test-Path -LiteralPath (Join-Path $backup "en-US.json")) {
  Copy-Item -LiteralPath (Join-Path $backup "en-US.json") -Destination $enLocale -Force
}
if (Test-Path -LiteralPath (Join-Path $backup "zh-CN.json")) {
  Copy-Item -LiteralPath (Join-Path $backup "zh-CN.json") -Destination $zhLocale -Force
}

Start-Process -FilePath $exe -WorkingDirectory $app
Write-Host "Claude files restored from: $backup"
