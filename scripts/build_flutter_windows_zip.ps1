$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$FlutterDir = Join-Path $RepoRoot "photolite_flutter"
$ReleaseDir = Join-Path $RepoRoot "release"
$BuildDir = Join-Path $FlutterDir "build\windows\x64\runner\Release"
$ZipPath = Join-Path $ReleaseDir "PhotoLite-Windows-release.zip"

Set-Location $FlutterDir
flutter pub get
flutter build windows --release

New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null
if (Test-Path $ZipPath) {
  Remove-Item $ZipPath -Force
}

Compress-Archive -Path (Join-Path $BuildDir "*") -DestinationPath $ZipPath -Force
Write-Host "Created $ZipPath"
