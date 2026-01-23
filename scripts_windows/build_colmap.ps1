# Fast COLMAP Build Script - Uses Ninja and Maximum Parallelism
# Usage: .\build_colmap_fast.ps1 [-Configuration Debug|Release] [-Clean]

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [switch]$NoCuda,
    [switch]$Gui,
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
  -Gui                            Enable GUI support (requires Qt)
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
$GuiEnabled = if ($Gui) { "ON" } else { "OFF" }

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

    # Set vcpkg manifest features based on CUDA and GUI
    $VcpkgFeatures = "cgal"
    if ($CudaEnabled -eq "ON") {
        $VcpkgFeatures += ";cuda"
    }
    if ($GuiEnabled -eq "ON") {
        $VcpkgFeatures += ";qt5"
    }

    cmake .. `
        -G Ninja `
        -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
        -DCMAKE_BUILD_TYPE="$Configuration" `
        -DCUDA_ENABLED="$CudaEnabled" `
        -DGUI_ENABLED="$GuiEnabled" `
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

        # First check CUDSS_ROOT environment variable (used in CI)
        if ($env:CUDSS_ROOT -and (Test-Path $env:CUDSS_ROOT)) {
            Write-Host "  Found CUDSS_ROOT: $env:CUDSS_ROOT" -ForegroundColor DarkGray
            # Check for bin directory structure (cuDSS uses bin/12 for CUDA 12.x)
            $possibleBinDirs = @(
                (Join-Path $env:CUDSS_ROOT "bin\12"),   # CUDA 12.x DLLs
                (Join-Path $env:CUDSS_ROOT "bin\13"),   # CUDA 13.x DLLs
                (Join-Path $env:CUDSS_ROOT "bin"),
                (Join-Path $env:CUDSS_ROOT "lib\12"),   # Alternative structure
                (Join-Path $env:CUDSS_ROOT "lib")
            )
            foreach ($binDir in $possibleBinDirs) {
                if (Test-Path $binDir) {
                    $dlls = Get-ChildItem "$binDir\cudss*.dll" -ErrorAction SilentlyContinue
                    if ($dlls) {
                        $cuDSSBinDir = $binDir
                        $cuDSSFound = $true
                        Write-Host "  Found cuDSS DLLs in: $binDir" -ForegroundColor DarkGray
                        break
                    }
                }
            }
        }

        # If not found via CUDSS_ROOT, check standard installation locations
        if (-not $cuDSSFound) {
            $cuDSSSearchPaths = @(
                "$env:ProgramW6432\NVIDIA cuDSS",
                "$env:ProgramFiles\NVIDIA cuDSS",
                "C:\Program Files\NVIDIA cuDSS"
            )

            foreach ($searchPath in $cuDSSSearchPaths) {
                if (Test-Path $searchPath) {
                    $cuDSSVersions = Get-ChildItem "$searchPath\v*" -ErrorAction SilentlyContinue | Sort-Object -Descending
                    if ($cuDSSVersions) {
                        # Check for CUDA version specific subdirectory (e.g., bin/12)
                        $cuDSSBaseBin = Join-Path $cuDSSVersions[0].FullName "bin"
                        $cudaVersionDirs = @("12", "13")  # Try CUDA 12, then 13
                        foreach ($cudaVer in $cudaVersionDirs) {
                            $cuDSSBinDir = Join-Path $cuDSSBaseBin $cudaVer
                            if (Test-Path $cuDSSBinDir) {
                                $dlls = Get-ChildItem "$cuDSSBinDir\cudss*.dll" -ErrorAction SilentlyContinue
                                if ($dlls) {
                                    $cuDSSFound = $true
                                    Write-Host "  Found cuDSS DLLs in: $cuDSSBinDir" -ForegroundColor DarkGray
                                    break
                                }
                            }
                        }
                        if ($cuDSSFound) { break }
                    }
                }
            }
        }

        if ($cuDSSFound) {
            $InstallBin = Join-Path $BuildDir "install\colmap\bin"
            if (Test-Path $InstallBin) {
                Write-Host "  Copying cuDSS DLLs from: $cuDSSBinDir" -ForegroundColor Yellow
                Copy-Item "$cuDSSBinDir\cudss*.dll" $InstallBin -Force -ErrorAction SilentlyContinue
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
