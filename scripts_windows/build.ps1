# Build All - Point Cloud Tools Build Script
# Usage: .\build.ps1 [-Configuration Debug|Release] [-NoCuda] [-Clean]

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [switch]$NoCuda,
    [switch]$Clean,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Build All - Point Cloud Tools

Usage: .\build.ps1 [options]

This script builds COLMAP (latest version) by calling the build_colmap.ps1 script.

Note: GLOMAP has been merged into COLMAP 3.14. Use 'colmap global_mapper' for global SfM.

Options:
  -Configuration <Debug|Release>  Build configuration (default: Release)
  -NoCuda                         Disable CUDA support
  -Clean                          Clean build directory before building
  -Help                           Show this help message

Examples:
  .\build.ps1                      Build COLMAP
  .\build.ps1 -Clean               Clean and rebuild
  .\build.ps1 -NoCuda              Build without CUDA support
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Helper function to initialize submodules if not already done
function Initialize-Submodule {
    param([string]$SubmodulePath, [string]$Name)

    $FullPath = Join-Path $ProjectRoot $SubmodulePath
    $GitDir = Join-Path $FullPath ".git"

    if (-not (Test-Path $GitDir)) {
        Write-Host "Initializing $Name submodule..." -ForegroundColor Yellow
        Push-Location $ProjectRoot
        try {
            git submodule update --init --recursive $SubmodulePath
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to initialize $Name submodule"
            }
            Write-Host "  $Name initialized successfully" -ForegroundColor Green
        } finally {
            Pop-Location
        }
    }
}

# Initialize required submodules
Write-Host "Checking required submodules..." -ForegroundColor Cyan
Initialize-Submodule "third_party\vcpkg" "vcpkg"
Initialize-Submodule "third_party\ceres-solver" "Ceres Solver"
Initialize-Submodule "third_party\colmap" "COLMAP"
Write-Host ""

# Bootstrap vcpkg if needed
$VcpkgRoot = Join-Path $ProjectRoot "third_party\vcpkg"
$VcpkgExe = Join-Path $VcpkgRoot "vcpkg.exe"
if (-not (Test-Path $VcpkgExe)) {
    Write-Host "Bootstrapping vcpkg..." -ForegroundColor Yellow
    $BootstrapScript = Join-Path $ScriptDir "bootstrap.ps1"
    & $BootstrapScript -NoPrompt
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to bootstrap vcpkg"
    }
    Write-Host ""
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Point Cloud Tools - Build All" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor White
Write-Host "CUDA: $(if ($NoCuda) { 'Disabled' } else { 'Enabled' })" -ForegroundColor White
Write-Host "Components: COLMAP (latest)" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

# Build COLMAP
Write-Host ""
Write-Host "Building COLMAP (latest)..." -ForegroundColor Green

$BuildArgs = @{
    Configuration = $Configuration
}
if ($NoCuda) { $BuildArgs['NoCuda'] = $true }
if ($Clean) { $BuildArgs['Clean'] = $true }

$ColmapScript = Join-Path $ScriptDir "build_colmap.ps1"
& $ColmapScript @BuildArgs

if ($LASTEXITCODE -ne 0) {
    throw "COLMAP build failed"
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Note: GLOMAP has been merged into COLMAP 3.14." -ForegroundColor Cyan
Write-Host "Use 'colmap global_mapper' for global Structure-from-Motion." -ForegroundColor Cyan
