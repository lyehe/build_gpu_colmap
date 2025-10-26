# Create Release Packages Script
# Packages COLMAP 3.13 dev, GLOMAP, and pycolmap wheels for release

[CmdletBinding()]
param(
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Create Release Packages Script

Usage: .\create_release_packages.ps1

This script packages the built components for GitHub release:
  - COLMAP 3.13 dev (from build/install/colmap/)
  - GLOMAP (from build/install/glomap/)
  - Copies pycolmap wheels (from third_party/colmap-for-pycolmap/wheelhouse/)

Output: releases/ directory with:
  - COLMAP-3.13-dev-Windows-x64-CUDA.zip
  - GLOMAP-Windows-x64-CUDA.zip
  - pycolmap-*.whl files

Prerequisites:
  - Build COLMAP 3.13 dev with: .\scripts_windows\build_colmap.ps1
  - Build GLOMAP with: .\scripts_windows\build_glomap.ps1
  - Build pycolmap wheels with: .\scripts_windows\build_pycolmap_wheels.ps1
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BuildDir = Join-Path $ProjectRoot "build"
$InstallDir = Join-Path $BuildDir "install"
$ReleasesDir = Join-Path $ProjectRoot "releases"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Create Release Packages" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Create releases directory if it doesn't exist
if (-not (Test-Path $ReleasesDir)) {
    New-Item -ItemType Directory -Path $ReleasesDir | Out-Null
    Write-Host "Created releases directory: $ReleasesDir" -ForegroundColor Green
}

# Check required installations
$ColmapInstall = Join-Path $InstallDir "colmap"
$GlomapInstall = Join-Path $InstallDir "glomap"
$PycolmapWheelhouse = Join-Path $ProjectRoot "third_party\colmap-for-pycolmap\wheelhouse"

$missingComponents = @()

if (-not (Test-Path (Join-Path $ColmapInstall "bin\colmap.exe"))) {
    $missingComponents += "COLMAP 3.13 dev (run: .\scripts_windows\build_colmap.ps1)"
}

if (-not (Test-Path (Join-Path $GlomapInstall "bin\glomap.exe"))) {
    $missingComponents += "GLOMAP (run: .\scripts_windows\build_glomap.ps1)"
}

if ($missingComponents.Count -gt 0) {
    Write-Host "ERROR: Missing required components:" -ForegroundColor Red
    foreach ($component in $missingComponents) {
        Write-Host "  - $component" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Please build missing components first." -ForegroundColor Yellow
    exit 1
}

# Package COLMAP 3.13 dev
Write-Host "[1/3] Packaging COLMAP 3.13 dev..." -ForegroundColor Green
$ColmapZip = Join-Path $ReleasesDir "COLMAP-3.13-dev-Windows-x64-CUDA.zip"

if (Test-Path $ColmapZip) {
    Remove-Item $ColmapZip -Force
}

Push-Location $ColmapInstall
try {
    # Compress with maximum compression
    Compress-Archive -Path "*" -DestinationPath $ColmapZip -CompressionLevel Optimal
    $colmapSize = [Math]::Round((Get-Item $ColmapZip).Length / 1MB, 2)
    Write-Host "  Created: COLMAP-3.13-dev-Windows-x64-CUDA.zip ($colmapSize MB)" -ForegroundColor Green
} finally {
    Pop-Location
}

# Package GLOMAP
Write-Host "[2/3] Packaging GLOMAP..." -ForegroundColor Green
$GlomapZip = Join-Path $ReleasesDir "GLOMAP-Windows-x64-CUDA.zip"

if (Test-Path $GlomapZip) {
    Remove-Item $GlomapZip -Force
}

Push-Location $GlomapInstall
try {
    Compress-Archive -Path "*" -DestinationPath $GlomapZip -CompressionLevel Optimal
    $glomapSize = [Math]::Round((Get-Item $GlomapZip).Length / 1MB, 2)
    Write-Host "  Created: GLOMAP-Windows-x64-CUDA.zip ($glomapSize MB)" -ForegroundColor Green
} finally {
    Pop-Location
}

# Copy pycolmap wheels
Write-Host "[3/3] Copying pycolmap wheels..." -ForegroundColor Green

if (Test-Path $PycolmapWheelhouse) {
    $wheels = Get-ChildItem -Path $PycolmapWheelhouse -Filter "pycolmap-*.whl"

    if ($wheels.Count -gt 0) {
        foreach ($wheel in $wheels) {
            $destPath = Join-Path $ReleasesDir $wheel.Name
            Copy-Item $wheel.FullName $destPath -Force
            $wheelSize = [Math]::Round((Get-Item $destPath).Length / 1MB, 2)
            Write-Host "  Copied: $($wheel.Name) ($wheelSize MB)" -ForegroundColor Green
        }
    } else {
        Write-Host "  ⚠ No pycolmap wheels found in $PycolmapWheelhouse" -ForegroundColor Yellow
        Write-Host "    Run: .\scripts_windows\build_pycolmap_wheels.ps1" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠ Pycolmap wheelhouse not found" -ForegroundColor Yellow
    Write-Host "    Run: .\scripts_windows\build_pycolmap_wheels.ps1" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "Release Packages Created Successfully!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Package Location: $ReleasesDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Contents:" -ForegroundColor Yellow
Get-ChildItem -Path $ReleasesDir -Filter "*.zip" | ForEach-Object {
    $size = if ($_.Length -gt 1GB) {
        "{0:N2} GB" -f ($_.Length / 1GB)
    } else {
        "{0:N2} MB" -f ($_.Length / 1MB)
    }
    Write-Host "  - $($_.Name) ($size)" -ForegroundColor White
}

Get-ChildItem -Path $ReleasesDir -Filter "*.whl" | ForEach-Object {
    $size = if ($_.Length -gt 1GB) {
        "{0:N2} GB" -f ($_.Length / 1GB)
    } else {
        "{0:N2} MB" -f ($_.Length / 1MB)
    }
    Write-Host "  - $($_.Name) ($size)" -ForegroundColor White
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review and update: releases\RELEASE_NOTES.md" -ForegroundColor White
Write-Host "  2. Create release: .\scripts_windows\create_github_release.ps1" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Green
