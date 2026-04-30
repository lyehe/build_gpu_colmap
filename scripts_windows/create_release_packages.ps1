# Create Release Packages Script
# Packages the built COLMAP and matching pycolmap wheels for release

[CmdletBinding()]
param(
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Create Release Packages Script

Usage: .\create_release_packages.ps1

This script packages the built components for GitHub release:
  - COLMAP (from build/install/colmap/)
  - Copies pycolmap wheels (from third_party/colmap-for-pycolmap/wheelhouse/)

Note: GLOMAP has been merged into COLMAP. Use 'colmap global_mapper' for global SfM.

Output: releases/ directory with:
  - COLMAP-<version>-Windows-x64-<variant>.zip
  - matching pycolmap-*.whl files, if present

Prerequisites:
  - Build COLMAP with: .\scripts_windows\build_colmap.ps1
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
$PycolmapWheelhouse = Join-Path $ProjectRoot "third_party\colmap-for-pycolmap\wheelhouse"

$missingComponents = @()

if (-not (Test-Path (Join-Path $ColmapInstall "bin\colmap.exe"))) {
    $missingComponents += "COLMAP (run: .\scripts_windows\build_colmap.ps1)"
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

# Package COLMAP
Write-Host "[1/2] Packaging COLMAP..." -ForegroundColor Green
$ColmapExe = Join-Path $ColmapInstall "bin\colmap.exe"
$ColmapVersionOutput = & $ColmapExe version 2>&1
if ($LASTEXITCODE -eq 0 -and $ColmapVersionOutput -match "COLMAP\s+([^\s]+)") {
    $ColmapVersion = $Matches[1]
} else {
    $ColmapVersion = "unknown"
}
$ColmapVersionSlug = $ColmapVersion -replace "[^A-Za-z0-9.+-]", "-"
$ColmapVariant = "CUDA"
if (Test-Path (Join-Path $ColmapInstall "bin\cudss*.dll")) {
    $ColmapVariant = "CUDA-cuDSS"
}
$ColmapZipName = "COLMAP-$ColmapVersionSlug-Windows-x64-$ColmapVariant.zip"
$ColmapZip = Join-Path $ReleasesDir $ColmapZipName

if (Test-Path $ColmapZip) {
    Remove-Item $ColmapZip -Force
}

Push-Location $ColmapInstall
try {
    # Compress with maximum compression
    Compress-Archive -Path "*" -DestinationPath $ColmapZip -CompressionLevel Optimal
    $colmapSize = [Math]::Round((Get-Item $ColmapZip).Length / 1MB, 2)
    Write-Host "  Created: $ColmapZipName ($colmapSize MB)" -ForegroundColor Green
} finally {
    Pop-Location
}

# Copy pycolmap wheels
Write-Host "[2/2] Copying pycolmap wheels..." -ForegroundColor Green

if (Test-Path $PycolmapWheelhouse) {
    $wheels = Get-ChildItem -Path $PycolmapWheelhouse -Filter "pycolmap-*.whl" |
        Where-Object { $_.Name -like "pycolmap-$ColmapVersion*" }

    if ($wheels.Count -gt 0) {
        foreach ($wheel in $wheels) {
            $destPath = Join-Path $ReleasesDir $wheel.Name
            Copy-Item $wheel.FullName $destPath -Force
            $wheelSize = [Math]::Round((Get-Item $destPath).Length / 1MB, 2)
            Write-Host "  Copied: $($wheel.Name) ($wheelSize MB)" -ForegroundColor Green
        }
    } else {
        Write-Host "  Warning: No pycolmap wheels matching COLMAP $ColmapVersion found in $PycolmapWheelhouse" -ForegroundColor Yellow
        Write-Host "    Run: .\scripts_windows\build_pycolmap_wheels.ps1" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Warning: Pycolmap wheelhouse not found" -ForegroundColor Yellow
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
Write-Host "Note: GLOMAP has been merged into COLMAP." -ForegroundColor Cyan
Write-Host "Use 'colmap global_mapper' for global Structure-from-Motion." -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review and update: releases\RELEASE_NOTES.md" -ForegroundColor White
Write-Host "  2. Create release: .\scripts_windows\create_github_release.ps1" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Green
