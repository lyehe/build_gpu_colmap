# Fast COLMAP Build Script - Uses Ninja and Maximum Parallelism
# Usage: .\build_colmap_fast.ps1 [-Configuration Debug|Release] [-Clean]

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
Fast COLMAP Build Script (Ninja + Max Parallelism)

Usage: .\build_colmap_fast.ps1 [options]

This script builds:
  - Ceres Solver (dependency)
  - COLMAP (latest version)

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

# Calculate optimal job count (25% of cores for stability)
$CpuCores = [int]$env:NUMBER_OF_PROCESSORS
$OptimalJobs = [int][Math]::Max(1, [Math]::Floor($CpuCores * 0.25))

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
Write-Host "Fast COLMAP Build (Ninja + Optimized)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Modules: Ceres Solver + COLMAP (latest)" -ForegroundColor White
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
Write-Host "Configuring CMake for COLMAP with Ninja..." -ForegroundColor Green
Push-Location $BuildDir
try {
    $VcpkgToolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"

    # Set vcpkg manifest features based on CUDA
    if ($CudaEnabled -eq "ON") {
        $VcpkgFeatures = "cgal;cuda"
    } else {
        $VcpkgFeatures = "cgal"
    }

    cmake .. `
        -G Ninja `
        -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
        -DCMAKE_BUILD_TYPE="$Configuration" `
        -DCUDA_ENABLED="$CudaEnabled" `
        -DBUILD_CERES=ON `
        -DBUILD_COLMAP=ON `
        -DBUILD_GLOMAP=OFF `
        -DVCPKG_MANIFEST_FEATURES="$VcpkgFeatures" `
        -DGFLAGS_USE_TARGET_NAMESPACE=ON

    if ($LASTEXITCODE -ne 0) {
        throw "CMake configuration failed"
    }

    # Build
    Write-Host ""
    Write-Host "Building COLMAP with $OptimalJobs parallel jobs..." -ForegroundColor Green

    cmake --build . --config $Configuration --parallel $OptimalJobs

    if ($LASTEXITCODE -ne 0) {
        throw "Build failed"
    }

    # Copy all runtime dependencies to make COLMAP fully self-contained
    Write-Host ""
    Write-Host "Copying runtime dependencies..." -ForegroundColor Cyan

    $ColmapBin = Join-Path $BuildDir "install\colmap\bin"

    # 1. Copy CUDA runtime DLLs if CUDA is enabled
    if ($CudaEnabled -eq "ON") {
        $CudaBinPaths = @(
            "$env:CUDA_PATH\bin",
            "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\bin",
            "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6\bin",
            "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.0\bin"
        )

        $CudaBinFound = $false
        foreach ($CudaBinPath in $CudaBinPaths) {
            if (Test-Path $CudaBinPath) {
                Write-Host "  Copying CUDA runtime DLLs from: $CudaBinPath" -ForegroundColor DarkGray

                # Copy essential CUDA runtime DLLs
                $CudaDlls = @(
                    "cudart64_*.dll",
                    "curand64_*.dll",
                    "cublas64_*.dll",
                    "cublasLt64_*.dll",
                    "cusparse64_*.dll",
                    "cusolver64_*.dll",
                    "cufft64_*.dll"
                )

                foreach ($pattern in $CudaDlls) {
                    Get-ChildItem "$CudaBinPath\$pattern" -ErrorAction SilentlyContinue | ForEach-Object {
                        Copy-Item $_.FullName $ColmapBin -Force -ErrorAction SilentlyContinue
                    }
                }

                $CudaBinFound = $true
                Write-Host "    CUDA runtime DLLs copied" -ForegroundColor Green
                break
            }
        }

        if (-not $CudaBinFound) {
            Write-Host "    Warning: CUDA bin directory not found, CUDA DLLs not copied" -ForegroundColor Yellow
        }
    }

    # 2. Ensure all vcpkg dependencies are present
    $VcpkgBin = Join-Path $BuildDir "vcpkg_installed\x64-windows\bin"
    if (Test-Path $VcpkgBin) {
        Write-Host "  Ensuring all vcpkg dependencies are present..." -ForegroundColor DarkGray
        # Only copy DLLs that don't already exist (avoid overwriting)
        Get-ChildItem "$VcpkgBin\*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
            $destFile = Join-Path $ColmapBin $_.Name
            if (-not (Test-Path $destFile)) {
                Copy-Item $_.FullName $ColmapBin -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "    All vcpkg dependencies ensured" -ForegroundColor Green
    }

    $finalCount = (Get-ChildItem "$ColmapBin" -File).Count
    Write-Host "  Total files in COLMAP bin: $finalCount" -ForegroundColor Cyan

    # Copy cuDSS DLLs if cuDSS was found and enabled
    if ($CudaEnabled -eq "ON") {
        Write-Host ""
        Write-Host "Checking for cuDSS DLLs to copy..." -ForegroundColor Cyan

        $cuDSSFound = $false
        $cuDSSBinDir = $null

        # Check standard cuDSS installation locations
        $cuDSSSearchPaths = @(
            "$env:ProgramW6432\NVIDIA cuDSS",
            "$env:ProgramFiles\NVIDIA cuDSS",
            "C:\Program Files\NVIDIA cuDSS"
        )

        foreach ($searchPath in $cuDSSSearchPaths) {
            if (Test-Path $searchPath) {
                $cuDSSVersions = Get-ChildItem "$searchPath\v*" -ErrorAction SilentlyContinue | Sort-Object -Descending
                if ($cuDSSVersions) {
                    $cuDSSBinDir = Join-Path $cuDSSVersions[0].FullName "bin"
                    if (Test-Path $cuDSSBinDir) {
                        $cuDSSFound = $true
                        break
                    }
                }
            }
        }

        if ($cuDSSFound) {
            $InstallBin = Join-Path $BuildDir "install\colmap\bin"
            if (Test-Path $InstallBin) {
                Write-Host "  Copying cuDSS DLLs from: $cuDSSBinDir" -ForegroundColor Yellow
                Copy-Item "$cuDSSBinDir\*.dll" $InstallBin -Force -ErrorAction SilentlyContinue
                Write-Host "  cuDSS DLLs copied successfully" -ForegroundColor Green
            } else {
                Write-Host "  Warning: Install directory not found, skipping cuDSS DLL copy" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  cuDSS not found - skipping DLL copy" -ForegroundColor Gray
            Write-Host "  (This is optional - COLMAP will work without cuDSS)" -ForegroundColor Gray
        }
    }

} finally {
    Pop-Location
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "Fast COLMAP build completed successfully!" -ForegroundColor Green
Write-Host "Build artifacts: $BuildDir" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
