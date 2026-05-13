$ErrorActionPreference = "Stop"

$repo = Resolve-Path (Join-Path $PSScriptRoot "..")
$asarBin = Join-Path $repo "node_modules\.bin\asar.cmd"
$stateRoot = Join-Path $env:USERPROFILE ".claude-cowork-zh-patch"
$backupRoot = Join-Path $stateRoot "backups"
$workRoot = Join-Path $stateRoot "work"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $backupRoot $stamp
$workDir = Join-Path $workRoot $stamp
$translations = Join-Path $repo "translations\zh-CN.json"

function Assert-Admin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    Start-Process -FilePath powershell.exe -ArgumentList $args -Verb RunAs -Wait
    exit $LASTEXITCODE
  }
}

function Find-ClaudeApp {
  $root = "C:\Program Files\WindowsApps"
  $apps = Get-ChildItem -LiteralPath $root -Directory -Filter "Claude_*__pzs8sxrjxfjjc" -ErrorAction Stop |
    Where-Object { Test-Path (Join-Path $_.FullName "app\resources\app.asar") } |
    Sort-Object LastWriteTime -Descending
  if (-not $apps) { throw "Cannot find Claude Desktop under $root." }
  return (Join-Path $apps[0].FullName "app")
}

function Grant-WriteAccess($target) {
  & takeown.exe /F $target /A | Out-Host
  & icacls.exe $target /grant "*S-1-5-32-544:F" /C | Out-Host
  attrib.exe -R $target
}

Assert-Admin

if (-not (Test-Path -LiteralPath $asarBin)) {
  throw "Missing $asarBin. Run npm install first."
}

$app = Find-ClaudeApp
$exe = Join-Path $app "Claude.exe"
$resources = Join-Path $app "resources"
$asar = Join-Path $resources "app.asar"
$enLocale = Join-Path $resources "en-US.json"
$zhLocale = Join-Path $resources "zh-CN.json"
$patchedAsar = Join-Path $backupDir "app.zh-CN.asar"
$manifest = Join-Path $stateRoot "latest.json"

New-Item -ItemType Directory -Force -Path $backupDir, $workDir | Out-Null

Get-Process | Where-Object { $_.ProcessName -ieq "claude" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Copy-Item -LiteralPath $exe -Destination (Join-Path $backupDir "Claude.exe") -Force
Copy-Item -LiteralPath $asar -Destination (Join-Path $backupDir "app.asar") -Force
if (Test-Path -LiteralPath $enLocale) { Copy-Item -LiteralPath $enLocale -Destination (Join-Path $backupDir "en-US.json") -Force }
if (Test-Path -LiteralPath $zhLocale) { Copy-Item -LiteralPath $zhLocale -Destination (Join-Path $backupDir "zh-CN.json") -Force }

& $asarBin extract $asar $workDir
node (Join-Path $repo "scripts\patch-asar.cjs") $workDir $translations
& $asarBin pack $workDir $patchedAsar

foreach ($locale in @($enLocale, $zhLocale)) {
  if (Test-Path -LiteralPath $locale) {
    Copy-Item -LiteralPath $locale -Destination (Join-Path $backupDir ([IO.Path]::GetFileName($locale) + ".working")) -Force
    node (Join-Path $repo "scripts\update-locale.cjs") (Join-Path $backupDir ([IO.Path]::GetFileName($locale) + ".working")) $translations
  }
}

foreach ($target in @($exe, $asar, $enLocale, $zhLocale, $resources)) {
  if (Test-Path -LiteralPath $target) { Grant-WriteAccess $target }
}

Copy-Item -LiteralPath $patchedAsar -Destination $asar -Force
if (Test-Path (Join-Path $backupDir "en-US.json.working")) {
  Copy-Item -LiteralPath (Join-Path $backupDir "en-US.json.working") -Destination $enLocale -Force
}
if (Test-Path (Join-Path $backupDir "zh-CN.json.working")) {
  Copy-Item -LiteralPath (Join-Path $backupDir "zh-CN.json.working") -Destination $zhLocale -Force
}

$headerHash = (node (Join-Path $repo "scripts\get-asar-header-hash.cjs") $asar).Trim()
node (Join-Path $repo "scripts\patch-exe-hash.cjs") $exe $headerHash

$manifestData = [ordered]@{
  app = $app
  backup = $backupDir
  installedAt = (Get-Date).ToString("o")
  asarHeaderHash = $headerHash
}
$manifestData | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifest -Encoding UTF8

Start-Process -FilePath $exe -WorkingDirectory $app
Write-Host "Claude Cowork Chinese patch installed."
Write-Host "Backup: $backupDir"
