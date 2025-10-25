# Fast GLOMAP Build Script - Uses Ninja and Maximum Parallelism
# Usage: .\build_glomap_fast.ps1 [-Configuration Debug|Release] [-Clean]

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
Fast GLOMAP Build Script (Ninja + Max Parallelism)

Usage: .\build_glomap_fast.ps1 [options]

This script builds:
  - Ceres Solver (dependency, if not already built)
  - PoseLib (dependency, if not already built)
  - COLMAP for GLOMAP (v3.11 - pinned for compatibility)
  - GLOMAP (global structure-from-motion)

Options:
  -Configuration <Debug|Release>  Build configuration (default: Release)
  -NoCuda                         Disable CUDA support
  -Clean                          Clean build directory before building
  -Help                           Show this help message

Performance optimizations:
  - Uses Ninja generator (faster than MSBuild)
  - Maximum CPU parallelism (75% of cores)
  - Optimized compiler flags

Note:
  GLOMAP requires a specific COLMAP version (3.11) which is built
  separately from the latest COLMAP version.
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
Initialize-Submodule "third_party\poselib" "PoseLib"
Initialize-Submodule "third_party\colmap-for-glomap" "COLMAP for GLOMAP"
Initialize-Submodule "third_party\glomap" "GLOMAP"
Write-Host ""

# Bootstrap vcpkg if needed
$VcpkgExe = Join-Path $VcpkgRoot "vcpkg.exe"
if (-not (Test-Path $VcpkgExe)) {
    Write-Host "Bootstrapping vcpkg..." -ForegroundColor Yellow
    $BootstrapScript = Join-Path $ProjectRoot "scripts_windows\bootstrap.ps1"
    & $BootstrapScript -NoPrompt
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to bootstrap vcpkg"
    }
    Write-Host ""
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Fast GLOMAP Build (Ninja + Optimized)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Modules: Ceres + PoseLib + COLMAP 3.11 + GLOMAP" -ForegroundColor White
Write-Host "Configuration: $Configuration" -ForegroundColor White
Write-Host "CUDA Enabled: $CudaEnabled" -ForegroundColor White
Write-Host "Parallel Jobs: $OptimalJobs (of $CpuCores cores)" -ForegroundColor White
Write-Host "Generator: Ninja" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

# Check if Ninja is available (required)
$NinjaPath = (Get-Command ninja -ErrorAction SilentlyContinue).Source
if (-not $NinjaPath) {
    Write-Host ""
    Write-Host "ERROR: Ninja build system not found" -ForegroundColor Red
    Write-Host "Ninja is required for building. Install it with:" -ForegroundColor Yellow
    Write-Host "  choco install ninja" -ForegroundColor White
    Write-Host "  OR download from: https://github.com/ninja-build/ninja/releases" -ForegroundColor White
    throw "Ninja not found"
}
Write-Host "Ninja found: $NinjaPath" -ForegroundColor Green

# Sync COLMAP version for GLOMAP compatibility
$SyncScript = Join-Path $ScriptDir "sync_colmap_for_glomap.ps1"
if (Test-Path $SyncScript) {
    Write-Host ""
    Write-Host "Syncing COLMAP version for GLOMAP compatibility..." -ForegroundColor Yellow
    & $SyncScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: Failed to sync COLMAP version for GLOMAP" -ForegroundColor Yellow
        Write-Host "Build may continue but GLOMAP compatibility is not guaranteed" -ForegroundColor Yellow
    }
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
Write-Host "Configuring CMake for GLOMAP with Ninja..." -ForegroundColor Green
Push-Location $BuildDir
try {
    $VcpkgToolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"

    cmake .. `
        -G Ninja `
        -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
        -DCMAKE_BUILD_TYPE="$Configuration" `
        -DCUDA_ENABLED="$CudaEnabled" `
        -DBUILD_CERES=ON `
        -DBUILD_COLMAP=OFF `
        -DBUILD_GLOMAP=ON

    if ($LASTEXITCODE -ne 0) {
        throw "CMake configuration failed"
    }

    # Build dependencies first (Ceres, PoseLib, COLMAP) before GLOMAP
    # Note: cmake --build with ExternalProject automatically skips targets that are up-to-date
    Write-Host ""
    Write-Host "Building dependencies with $OptimalJobs parallel jobs..." -ForegroundColor Green

    Write-Host "[1/4] Building Ceres Solver..." -ForegroundColor Cyan
    $CeresInstalled = Test-Path "install\ceres\lib\cmake\Ceres\CeresConfig.cmake"
    if ($CeresInstalled) {
        Write-Host "  [Checking if rebuild needed...]" -ForegroundColor DarkGray
    }
    cmake --build . --target ceres-solver-external --config $Configuration --parallel $OptimalJobs
    if ($LASTEXITCODE -ne 0) {
        throw "Ceres build failed"
    }

    Write-Host "[2/4] Building PoseLib..." -ForegroundColor Cyan
    $PoseLibInstalled = Test-Path "install\poselib\lib\cmake\PoseLib\PoseLibConfig.cmake"
    if ($PoseLibInstalled) {
        Write-Host "  [Checking if rebuild needed...]" -ForegroundColor DarkGray
    }
    cmake --build . --target poselib-external-install --config $Configuration --parallel $OptimalJobs
    if ($LASTEXITCODE -ne 0) {
        throw "PoseLib build failed"
    }

    Write-Host "[3/4] Building COLMAP for GLOMAP (v3.11)..." -ForegroundColor Cyan
    $ColmapInstalled = Test-Path "install\colmap-for-glomap\lib\cmake\COLMAP\COLMAPConfig.cmake"
    if ($ColmapInstalled) {
        Write-Host "  [Checking if rebuild needed...]" -ForegroundColor DarkGray
    }
    cmake --build . --target colmap-for-glomap-external-install --config $Configuration --parallel $OptimalJobs
    if ($LASTEXITCODE -ne 0) {
        throw "COLMAP build failed"
    }

    # Now configure and build GLOMAP (dependencies are installed and available)
    Write-Host "[4/4] Building GLOMAP..." -ForegroundColor Green
    $GlomapInstalled = Test-Path "install\glomap\lib\cmake\glomap\glomapConfig.cmake"
    if ($GlomapInstalled) {
        Write-Host "  [Checking if rebuild needed...]" -ForegroundColor DarkGray
    }

    # Create glomap build directory if it doesn't exist
    $GlomapBuildDir = "glomap"
    if (-not (Test-Path $GlomapBuildDir)) {
        New-Item -ItemType Directory -Path $GlomapBuildDir | Out-Null
    }

    # Configure GLOMAP separately now that dependencies are installed
    Write-Host "  Configuring GLOMAP..." -ForegroundColor Cyan
    Push-Location $GlomapBuildDir
    try {
        $GlomapSource = Join-Path (Split-Path -Parent $BuildDir) "third_party\glomap"
        $GlomapInstallDir = Join-Path $BuildDir "install\glomap"
        $CeresDir = Join-Path $BuildDir "install\ceres"
        $PoseLibDir = Join-Path $BuildDir "install\poselib"
        $ColmapDir = Join-Path $BuildDir "install\colmap-for-glomap"

        if ($UseNinja) {
            cmake "$GlomapSource" `
                -G Ninja `
                -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
                -DCMAKE_BUILD_TYPE="$Configuration" `
                -DCMAKE_INSTALL_PREFIX="$GlomapInstallDir" `
                -DCMAKE_PREFIX_PATH="$CeresDir;$PoseLibDir;$ColmapDir" `
                -DPoseLib_DIR="$PoseLibDir\lib\cmake\PoseLib" `
                -DCOLMAP_DIR="$ColmapDir\lib\cmake\COLMAP" `
                -DFETCH_COLMAP=OFF `
                -DFETCH_POSELIB=OFF `
                -DCUDA_ENABLED="$CudaEnabled" `
                -DCMAKE_CUDA_ARCHITECTURES="75;80;86;89;90;120"
        } else {
            cmake "$GlomapSource" `
                -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
                -DCMAKE_BUILD_TYPE="$Configuration" `
                -DCMAKE_INSTALL_PREFIX="$GlomapInstallDir" `
                -DCMAKE_PREFIX_PATH="$CeresDir;$PoseLibDir;$ColmapDir" `
                -DPoseLib_DIR="$PoseLibDir\lib\cmake\PoseLib" `
                -DCOLMAP_DIR="$ColmapDir\lib\cmake\COLMAP" `
                -DFETCH_COLMAP=OFF `
                -DFETCH_POSELIB=OFF `
                -DCUDA_ENABLED="$CudaEnabled" `
                -DCMAKE_CUDA_ARCHITECTURES="75;80;86;89;90;120" `
                -G "Visual Studio 17 2022" `
                -A x64
        }

        if ($LASTEXITCODE -ne 0) {
            throw "GLOMAP configuration failed"
        }

        # Build GLOMAP
        Write-Host "  Building GLOMAP..." -ForegroundColor Cyan
        cmake --build . --config $Configuration --parallel $OptimalJobs

        if ($LASTEXITCODE -ne 0) {
            throw "GLOMAP build failed"
        }

        # Install GLOMAP
        Write-Host "  Installing GLOMAP..." -ForegroundColor Cyan
        cmake --build . --config $Configuration --target install

        if ($LASTEXITCODE -ne 0) {
            throw "GLOMAP install failed"
        }

    } finally {
        Pop-Location
    }

} finally {
    Pop-Location
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "Fast GLOMAP build completed successfully!" -ForegroundColor Green
Write-Host "Build artifacts: $BuildDir" -ForegroundColor Green
Write-Host ""
Write-Host "Installations:" -ForegroundColor Cyan
Write-Host "  Ceres:              $BuildDir\install\ceres" -ForegroundColor White
Write-Host "  PoseLib:            $BuildDir\install\poselib" -ForegroundColor White
Write-Host "  COLMAP for GLOMAP:  $BuildDir\install\colmap-for-glomap" -ForegroundColor White
Write-Host "  GLOMAP:             $BuildDir\install\glomap" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Green
