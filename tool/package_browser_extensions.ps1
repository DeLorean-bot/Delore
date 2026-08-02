param(
  [string]$OutputDirectory = "build/browser_extensions"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputPath = Join-Path $projectRoot $OutputDirectory

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$legacyArchive = Join-Path $outputPath "delore-browser-bridge-chromium.zip"
if (Test-Path -LiteralPath $legacyArchive) {
  Remove-Item -LiteralPath $legacyArchive -Force
}

$packages = @{
  "edge" = "chromium"
  "chromium-local" = "chromium"
  "firefox" = "firefox"
}

foreach ($packageName in $packages.Keys) {
  $sourcePath = Join-Path $projectRoot "assets/browser_extension/$($packages[$packageName])"
  $archivePath = Join-Path $outputPath "delore-browser-bridge-$packageName.zip"
  if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
  }
  Compress-Archive -Path (Join-Path $sourcePath "*") -DestinationPath $archivePath
}

Write-Output "Browser extension packages: $outputPath"
