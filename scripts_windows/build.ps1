# Build All - Point Cloud Tools Build Script
# Usage: .\build.ps1 [-Configuration Debug|Release] [-NoCuda] [-SkipGlomap] [-SkipColmap] [-Clean]

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [switch]$NoCuda,
    [switch]$SkipGlomap,
    [switch]$SkipColmap,
    [switch]$Clean,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Build All - Point Cloud Tools

Usage: .\build.ps1 [options]

This script builds all components by calling individual build scripts:
  - COLMAP (latest version) - unless -SkipColmap
  - GLOMAP (with dependencies: Ceres, PoseLib, COLMAP v3.11) - unless -SkipGlomap

Options:
  -Configuration <Debug|Release>  Build configuration (default: Release)
  -NoCuda                         Disable CUDA support
  -SkipGlomap                     Skip GLOMAP build
  -SkipColmap                     Skip COLMAP (latest) build
  -Clean                          Clean build directory before building
  -Help                           Show this help message

Examples:
  .\build.ps1                      Build both COLMAP and GLOMAP
  .\build.ps1 -SkipGlomap          Build only COLMAP (latest)
  .\build.ps1 -SkipColmap          Build only GLOMAP
  .\build.ps1 -Clean               Clean and rebuild everything
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Point Cloud Tools - Build All" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor White
Write-Host "CUDA: $(if ($NoCuda) { 'Disabled' } else { 'Enabled' })" -ForegroundColor White

$Components = @()
if (-not $SkipColmap) { $Components += "COLMAP (latest)" }
if (-not $SkipGlomap) { $Components += "GLOMAP" }

if ($Components.Count -eq 0) {
    Write-Host "Error: Nothing to build (both -SkipColmap and -SkipGlomap specified)" -ForegroundColor Red
    exit 1
}

Write-Host "Components: $($Components -join ', ')" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

# Build COLMAP (latest) first if requested
if (-not $SkipColmap) {
    Write-Host ""
    Write-Host "Building COLMAP (latest)..." -ForegroundColor Green

    $BuildArgs = @{
        Configuration = $Configuration
    }
    if ($NoCuda) { $BuildArgs['NoCuda'] = $true }
    if ($Clean) { $BuildArgs['Clean'] = $true; $Clean = $false }  # Only clean once

    $ColmapScript = Join-Path $ScriptDir "build_colmap.ps1"
    & $ColmapScript @BuildArgs

    if ($LASTEXITCODE -ne 0) {
        throw "COLMAP build failed"
    }
}

# Build GLOMAP (with dependencies) if requested
if (-not $SkipGlomap) {
    Write-Host ""
    Write-Host "Building GLOMAP..." -ForegroundColor Green

    $BuildArgs = @{
        Configuration = $Configuration
    }
    if ($NoCuda) { $BuildArgs['NoCuda'] = $true }
    if ($Clean) { $BuildArgs['Clean'] = $true }

    $GlomapScript = Join-Path $ScriptDir "build_glomap.ps1"
    & $GlomapScript @BuildArgs

    if ($LASTEXITCODE -ne 0) {
        throw "GLOMAP build failed"
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "All builds completed successfully!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
