# Fast Ceres Build Script - Uses Ninja and Maximum Parallelism
# Usage: .\build_ceres_fast.ps1 [-Configuration Debug|Release] [-Clean]

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
Fast Ceres Build Script (Ninja + Max Parallelism)

Usage: .\build_ceres_fast.ps1 [options]

Options:
  -Configuration <Debug|Release>  Build configuration (default: Release)
  -NoCuda                         Disable CUDA support
  -Clean                          Clean build directory before building
  -Help                           Show this help message

Performance optimizations:
  - Uses Ninja generator (faster than MSBuild)
  - Maximum CPU parallelism (75% of cores)
  - Optimized compiler flags
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BuildDir = Join-Path $ProjectRoot "build"
$VcpkgRoot = Join-Path $ProjectRoot "third_party\vcpkg"
$CudaEnabled = if ($NoCuda) { "OFF" } else { "ON" }

# Calculate optimal job count (75% of cores)
$CpuCores = [int]$env:NUMBER_OF_PROCESSORS
$OptimalJobs = [int][Math]::Max(1, [Math]::Floor($CpuCores * 0.75))

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Fast Ceres Solver Build (Ninja + Optimized)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor White
Write-Host "CUDA Enabled: $CudaEnabled" -ForegroundColor White
Write-Host "Parallel Jobs: $OptimalJobs (of $CpuCores cores)" -ForegroundColor White
Write-Host "Generator: Ninja" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

# Check if Ninja is available
$NinjaPath = (Get-Command ninja -ErrorAction SilentlyContinue).Source
if (-not $NinjaPath) {
    Write-Host ""
    Write-Host "WARNING: Ninja not found in PATH" -ForegroundColor Yellow
    Write-Host "Falling back to Visual Studio generator (slower)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To install Ninja:" -ForegroundColor Cyan
    Write-Host "  choco install ninja" -ForegroundColor White
    Write-Host "  OR: Download from https://github.com/ninja-build/ninja/releases" -ForegroundColor White
    $UseNinja = $false
} else {
    Write-Host "Ninja found: $NinjaPath" -ForegroundColor Green
    $UseNinja = $true
}

# Clean build directory if requested
if ($Clean -and (Test-Path $BuildDir)) {
    Write-Host ""
    Write-Host "Cleaning build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $BuildDir
}

# Create build directory
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

# Configure CMake
Write-Host ""
Write-Host "Configuring CMake..." -ForegroundColor Green
Push-Location $BuildDir
try {
    $VcpkgToolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"

    if ($UseNinja) {
        cmake .. `
            -G Ninja `
            -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
            -DCMAKE_BUILD_TYPE="$Configuration" `
            -DCUDA_ENABLED="$CudaEnabled" `
            -DBUILD_CERES=ON `
            -DBUILD_COLMAP=OFF `
            -DBUILD_GLOMAP=OFF
    } else {
        cmake .. `
            -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
            -DCMAKE_BUILD_TYPE="$Configuration" `
            -DCUDA_ENABLED="$CudaEnabled" `
            -DBUILD_CERES=ON `
            -DBUILD_COLMAP=OFF `
            -DBUILD_GLOMAP=OFF `
            -G "Visual Studio 17 2022" `
            -A x64
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "CMake configuration failed"
    }

    # Build
    Write-Host ""
    Write-Host "Building with $OptimalJobs parallel jobs..." -ForegroundColor Green

    cmake --build . --config $Configuration --parallel $OptimalJobs

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed"
    }

} finally {
    Pop-Location
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "Fast build completed successfully!" -ForegroundColor Green
Write-Host "Build artifacts: $BuildDir" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
