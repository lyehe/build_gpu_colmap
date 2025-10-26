# Build pycolmap wheels for all installed Python versions using colmap-for-pycolmap
# Usage: .\build_pycolmap_wheels.ps1 [-Configuration Debug|Release] [-NoCuda]

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
Build pycolmap wheels for ALL installed Python versions

This script automatically:
  1. Initializes colmap-for-pycolmap submodule if needed
  2. Builds COLMAP-for-pycolmap with optimized settings
  3. Detects all Python 3.9+ installations
  4. Builds a wheel for each Python version

Usage: .\build_pycolmap_wheels.ps1 [options]

Options:
  -Configuration <Debug|Release>  Build configuration (default: Release)
  -NoCuda                         Build without CUDA support
  -Clean                          Clean build before building
  -Help                           Show this help message

Detection:
  The script searches for Python installations in:
  - py launcher (py -3.9, py -3.10, etc.)
  - PATH environment variable
  - Common installation directories

Requirements:
  - Python 3.9+ (multiple versions recommended)
  - Visual Studio 2022 Build Tools
  - CMake 3.28+
  - Git

Output:
  All wheels in: third_party\colmap-for-pycolmap\wheelhouse\
  - pycolmap-*-cp39-*.whl
  - pycolmap-*-cp310-*.whl
  - pycolmap-*-cp311-*.whl
  - pycolmap-*-cp312-*.whl
  - etc.

Examples:
  .\build_pycolmap_wheels.ps1
  .\build_pycolmap_wheels.ps1 -NoCuda
  .\build_pycolmap_wheels.ps1 -Clean
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ColmapSource = Join-Path $ProjectRoot "third_party\colmap-for-pycolmap"
$BuildDir = Join-Path $ProjectRoot "build"
$ColmapInstall = Join-Path $BuildDir "install\colmap-for-pycolmap"
$VcpkgRoot = Join-Path $ProjectRoot "third_party\vcpkg"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Build pycolmap Wheels for All Python Versions" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor White
Write-Host "CUDA: $(if ($NoCuda) { 'Disabled' } else { 'Enabled' })" -ForegroundColor White
Write-Host "COLMAP Source: $ColmapSource" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

# Helper function to initialize submodules if not already done
function Initialize-Submodule {
    param([string]$SubmodulePath, [string]$Name)

    $FullPath = Join-Path $ProjectRoot $SubmodulePath
    $GitDir = Join-Path $FullPath ".git"

    if (-not (Test-Path $GitDir)) {
        Write-Host ""
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
Write-Host ""
Write-Host "Checking required submodules..." -ForegroundColor Cyan
Initialize-Submodule "third_party\vcpkg" "vcpkg"
Initialize-Submodule "third_party\ceres-solver" "Ceres Solver"
Initialize-Submodule "third_party\colmap-for-pycolmap" "COLMAP for pycolmap"
Write-Host ""

# Bootstrap vcpkg if needed
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

# Build COLMAP-for-pycolmap if not already built or if Clean is specified
$ColmapBin = Join-Path $ColmapInstall "bin\colmap.exe"
$NeedsBuild = (-not (Test-Path $ColmapBin)) -or $Clean

if ($NeedsBuild) {
    Write-Host ""
    Write-Host "Building COLMAP-for-pycolmap..." -ForegroundColor Yellow
    Write-Host "This may take 30-60 minutes on first build..." -ForegroundColor DarkGray
    Write-Host ""

    # Clean build directories if requested
    if ($Clean -and (Test-Path $BuildDir)) {
        Write-Host "Cleaning build directories..." -ForegroundColor Yellow

        # Clean colmap-pycolmap build directory
        $ColmapPycolmapBuild = Join-Path $BuildDir "colmap-pycolmap"
        if (Test-Path $ColmapPycolmapBuild) {
            Write-Host "  Removing $ColmapPycolmapBuild" -ForegroundColor DarkGray
            Remove-Item -Recurse -Force $ColmapPycolmapBuild
        }

        # Clean ExternalProject stamp files
        $ExternalProjectStamps = Join-Path $BuildDir "colmap-for-pycolmap-external-prefix"
        if (Test-Path $ExternalProjectStamps) {
            Write-Host "  Removing $ExternalProjectStamps" -ForegroundColor DarkGray
            Remove-Item -Recurse -Force $ExternalProjectStamps
        }

        # Clean installation directory
        if (Test-Path $ColmapInstall) {
            Write-Host "  Removing $ColmapInstall" -ForegroundColor DarkGray
            Remove-Item -Recurse -Force $ColmapInstall
        }

        # Clean top-level CMakeCache.txt if it exists (may interfere)
        $TopCMakeCache = Join-Path $BuildDir "CMakeCache.txt"
        if (Test-Path $TopCMakeCache) {
            Write-Host "  Removing $TopCMakeCache" -ForegroundColor DarkGray
            Remove-Item -Force $TopCMakeCache
        }

        Write-Host "  Clean complete" -ForegroundColor Green
    }

    if (-not (Test-Path $BuildDir)) {
        New-Item -ItemType Directory -Path $BuildDir | Out-Null
    }

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

    # Configure CMake
    Push-Location $BuildDir
    try {
        $VcpkgToolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"
        $CudaEnabled = if ($NoCuda) { "OFF" } else { "ON" }

        Write-Host "Configuring CMake with Ninja..." -ForegroundColor Cyan
        cmake .. `
            -G Ninja `
            -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
            -DCMAKE_BUILD_TYPE="$Configuration" `
            -DCUDA_ENABLED="$CudaEnabled" `
            -DBUILD_COLMAP=OFF `
            -DBUILD_COLMAP_FOR_PYCOLMAP=ON `
            -DBUILD_GLOMAP=OFF `
            -DBUILD_CERES=ON `
            -DGFLAGS_USE_TARGET_NAMESPACE=ON

        if ($LASTEXITCODE -ne 0) {
            throw "CMake configuration failed"
        }

        Write-Host ""
        Write-Host "Building COLMAP-for-pycolmap..." -ForegroundColor Cyan
        cmake --build . --config $Configuration --parallel

        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }

        # Copy all runtime dependencies to make COLMAP-for-pycolmap fully self-contained
        Write-Host ""
        Write-Host "Copying runtime dependencies..." -ForegroundColor Cyan

        $ColmapBin = Join-Path $ColmapInstall "bin"

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
            Get-ChildItem "$VcpkgBin\*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
                $destFile = Join-Path $ColmapBin $_.Name
                if (-not (Test-Path $destFile)) {
                    Copy-Item $_.FullName $ColmapBin -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Host "    All vcpkg dependencies ensured" -ForegroundColor Green
        }

        $finalCount = (Get-ChildItem "$ColmapBin" -File).Count
        Write-Host "  Total files in COLMAP-for-pycolmap bin: $finalCount" -ForegroundColor Cyan

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
                $InstallBin = Join-Path $ColmapInstall "bin"
                if (Test-Path $InstallBin) {
                    Write-Host "  Copying cuDSS DLLs from: $cuDSSBinDir" -ForegroundColor Yellow
                    Copy-Item "$cuDSSBinDir\*.dll" $InstallBin -Force -ErrorAction SilentlyContinue
                    Write-Host "  cuDSS DLLs copied successfully" -ForegroundColor Green
                    Write-Host "  (delvewheel will bundle these into Python wheels)" -ForegroundColor DarkGray
                } else {
                    Write-Host "  Warning: Install directory not found, skipping cuDSS DLL copy" -ForegroundColor Yellow
                }
            } else {
                Write-Host "  cuDSS not found - skipping DLL copy" -ForegroundColor Gray
                Write-Host "  (This is optional - pycolmap will work without cuDSS)" -ForegroundColor Gray
            }
        }

        Write-Host ""
        Write-Host "COLMAP-for-pycolmap built successfully!" -ForegroundColor Green
    } finally {
        Pop-Location
    }
} else {
    Write-Host ""
    Write-Host "COLMAP-for-pycolmap already built at $ColmapInstall" -ForegroundColor Green
}

# Function to get Python version from executable
function Get-PythonVersion {
    param([string]$PythonExe)

    try {
        $VersionOutput = & $PythonExe --version 2>&1
        if ($VersionOutput -match 'Python (\d+)\.(\d+)\.(\d+)') {
            return @{
                Major = [int]$Matches[1]
                Minor = [int]$Matches[2]
                Patch = [int]$Matches[3]
                Full = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
                Exe = $PythonExe
            }
        }
    } catch {
        return $null
    }
    return $null
}

# Detect all Python installations
Write-Host ""
Write-Host "Detecting Python installations..." -ForegroundColor Yellow

$PythonVersions = @()
$SeenVersions = @{}

# Method 1: Try py launcher (most reliable on Windows)
Write-Host "  Checking py launcher..." -ForegroundColor DarkGray
foreach ($minor in 9..15) {  # Check 3.9 through 3.15
    try {
        $PyLauncherPath = "py"
        $VersionArg = "-3.$minor"

        # Test if this version exists
        $TestOutput = & $PyLauncherPath $VersionArg -c "import sys; print(sys.executable)" 2>&1
        if ($LASTEXITCODE -eq 0 -and $TestOutput) {
            $PythonExe = $TestOutput.Trim()
            if (Test-Path $PythonExe) {
                $Version = Get-PythonVersion $PythonExe
                if ($Version -and -not $SeenVersions.ContainsKey($Version.Full)) {
                    $PythonVersions += $Version
                    $SeenVersions[$Version.Full] = $true
                    Write-Host "    Found: Python $($Version.Full) via py -3.$minor" -ForegroundColor Green
                }
            }
        }
    } catch {
        # Silently continue - version doesn't exist
    }
}

# Method 2: Check PATH
Write-Host "  Checking PATH..." -ForegroundColor DarkGray
$PathCommands = @("python", "python3")
foreach ($cmd in $PathCommands) {
    try {
        $PythonExe = (Get-Command $cmd -ErrorAction SilentlyContinue).Source
        if ($PythonExe) {
            $Version = Get-PythonVersion $PythonExe
            if ($Version -and -not $SeenVersions.ContainsKey($Version.Full)) {
                $PythonVersions += $Version
                $SeenVersions[$Version.Full] = $true
                Write-Host "    Found: Python $($Version.Full) via $cmd" -ForegroundColor Green
            }
        }
    } catch {
        # Continue
    }
}

# Method 3: Common installation directories
Write-Host "  Checking common directories..." -ForegroundColor DarkGray
$CommonDirs = @(
    "$env:LOCALAPPDATA\Programs\Python\Python3*",
    "C:\Python3*",
    "$env:USERPROFILE\AppData\Local\Programs\Python\Python3*"
)

foreach ($pattern in $CommonDirs) {
    $Dirs = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $Dirs) {
        $PythonExe = Join-Path $dir.FullName "python.exe"
        if (Test-Path $PythonExe) {
            $Version = Get-PythonVersion $PythonExe
            if ($Version -and -not $SeenVersions.ContainsKey($Version.Full)) {
                $PythonVersions += $Version
                $SeenVersions[$Version.Full] = $true
                Write-Host "    Found: Python $($Version.Full) at $PythonExe" -ForegroundColor Green
            }
        }
    }
}

# Filter to Python 3.9+
$ValidVersions = $PythonVersions | Where-Object { $_.Major -eq 3 -and $_.Minor -ge 9 } | Sort-Object Major, Minor

if ($ValidVersions.Count -eq 0) {
    Write-Host ""
    Write-Host "ERROR: No Python 3.9+ installations found" -ForegroundColor Red
    Write-Host ""
    Write-Host "To install multiple Python versions:" -ForegroundColor Yellow
    Write-Host "  winget install Python.Python.3.9" -ForegroundColor White
    Write-Host "  winget install Python.Python.3.10" -ForegroundColor White
    Write-Host "  winget install Python.Python.3.11" -ForegroundColor White
    Write-Host "  winget install Python.Python.3.12" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "Found $($ValidVersions.Count) compatible Python version(s):" -ForegroundColor Green
foreach ($ver in $ValidVersions) {
    Write-Host "  - Python $($ver.Full) ($($ver.Exe))" -ForegroundColor White
}

# Build wheel for each Python version
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Building wheels for all versions..." -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

$SuccessfulBuilds = @()
$FailedBuilds = @()

foreach ($ver in $ValidVersions) {
    Write-Host ""
    Write-Host "[$($ValidVersions.IndexOf($ver) + 1)/$($ValidVersions.Count)] Building for Python $($ver.Full)..." -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor DarkGray

    # Temporarily modify PATH to use this Python version
    $OriginalPath = $env:PATH
    $PythonDir = Split-Path $ver.Exe
    $PythonScripts = Join-Path $PythonDir "Scripts"
    $env:PATH = "$PythonDir;$PythonScripts;$OriginalPath"

    try {
        # Build wheel using pip and scikit-build-core
        Write-Host "  Installing/upgrading build tools..." -ForegroundColor DarkGray
        & $ver.Exe -m pip install --quiet --upgrade pip setuptools wheel
        & $ver.Exe -m pip install --quiet --upgrade scikit-build-core[pyproject] pybind11 delvewheel

        Write-Host "  Building wheel with pip..." -ForegroundColor DarkGray

        # Get pybind11 CMake directory (installed by pip)
        # This is needed because vcpkg toolchain intercepts find_package(pybind11)
        $Pybind11CmakeDir = & $ver.Exe -c "import pybind11; print(pybind11.get_cmake_dir())" 2>$null
        $Pybind11CmakeDir = $Pybind11CmakeDir.Trim()

        # Prepare CMake configuration settings for scikit-build-core
        # These are passed to pip wheel via --config-settings
        $VcpkgToolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"
        $VcpkgInstalled = Join-Path $BuildDir "vcpkg_installed"

        # Convert to forward slashes (CMake prefers forward slashes, especially in strings)
        # Keep original variables with backslashes for Windows file operations
        $VcpkgToolchainFixed = $VcpkgToolchain.Replace('\', '/')
        $VcpkgInstalledFixed = $VcpkgInstalled.Replace('\', '/')
        $ColmapInstallFixed = $ColmapInstall.Replace('\', '/')
        $Pybind11CmakeDirFixed = $Pybind11CmakeDir.Replace('\', '/')

        # CMAKE_PREFIX_PATH needs both COLMAP and pybind11 (semicolon-separated)
        $CmakePrefixPath = "${ColmapInstallFixed};${Pybind11CmakeDirFixed}"

        Write-Host "  CMAKE_TOOLCHAIN_FILE: $VcpkgToolchainFixed" -ForegroundColor DarkGray
        Write-Host "  VCPKG_INSTALLED_DIR: $VcpkgInstalledFixed" -ForegroundColor DarkGray
        Write-Host "  CMAKE_PREFIX_PATH: $CmakePrefixPath" -ForegroundColor DarkGray

        Push-Location $ColmapSource
        try {
            # Build wheel using pip with explicit CMake configuration
            # Based on official COLMAP workflow: .github/workflows/build-pycolmap.yml
            & $ver.Exe -m pip wheel . --no-deps -w wheelhouse `
                --config-settings="cmake.define.CMAKE_TOOLCHAIN_FILE=${VcpkgToolchainFixed}" `
                --config-settings="cmake.define.VCPKG_INSTALLED_DIR=${VcpkgInstalledFixed}" `
                --config-settings="cmake.define.CMAKE_PREFIX_PATH=${CmakePrefixPath}" `
                --config-settings="cmake.define.VCPKG_TARGET_TRIPLET=x64-windows"

            if ($LASTEXITCODE -eq 0) {
                # Find the wheel that was just built
                $WheelFile = Get-ChildItem -Path "wheelhouse" -Filter "pycolmap-*.whl" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

                if ($WheelFile) {
                    Write-Host "  Bundling DLLs with delvewheel..." -ForegroundColor DarkGray
                    # Use delvewheel to bundle all DLLs
                    $VcpkgBinPath = Join-Path $VcpkgInstalled "x64-windows\bin"
                    & $ver.Exe -m delvewheel repair -v `
                        --add-path "$VcpkgBinPath" `
                        --add-path "$ColmapInstall\bin" `
                        -w wheelhouse `
                        $WheelFile.FullName

                    if ($LASTEXITCODE -eq 0) {
                        $SuccessfulBuilds += "Python $($ver.Full)"
                        Write-Host ""
                        Write-Host "SUCCESS: Wheel built for Python $($ver.Full)" -ForegroundColor Green
                    } else {
                        $FailedBuilds += "Python $($ver.Full)"
                        Write-Host ""
                        Write-Host "FAILED: delvewheel repair failed for Python $($ver.Full)" -ForegroundColor Red
                    }
                } else {
                    $FailedBuilds += "Python $($ver.Full)"
                    Write-Host ""
                    Write-Host "FAILED: No wheel file found for Python $($ver.Full)" -ForegroundColor Red
                }
            } else {
                $FailedBuilds += "Python $($ver.Full)"
                Write-Host ""
                Write-Host "FAILED: Wheel build failed for Python $($ver.Full)" -ForegroundColor Red
            }
        } finally {
            Pop-Location
        }
    } catch {
        $FailedBuilds += "Python $($ver.Full)"
        Write-Host ""
        Write-Host "ERROR: Exception during build for Python $($ver.Full)" -ForegroundColor Red
        Write-Host "  $_" -ForegroundColor Red
    } finally {
        # Restore original PATH
        $env:PATH = $OriginalPath
        Remove-Item Env:\CMAKE_PREFIX_PATH -ErrorAction SilentlyContinue
    }
}

# Summary
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

if ($SuccessfulBuilds.Count -gt 0) {
    Write-Host ""
    Write-Host "Successful builds ($($SuccessfulBuilds.Count)):" -ForegroundColor Green
    foreach ($build in $SuccessfulBuilds) {
        Write-Host "  [OK] $build" -ForegroundColor Green
    }
}

if ($FailedBuilds.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed builds ($($FailedBuilds.Count)):" -ForegroundColor Red
    foreach ($build in $FailedBuilds) {
        Write-Host "  [FAIL] $build" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "All wheels are in: third_party\colmap-for-pycolmap\wheelhouse\" -ForegroundColor Cyan

$WheelhouseDir = Join-Path $ColmapSource "wheelhouse"
if (Test-Path $WheelhouseDir) {
    $Wheels = Get-ChildItem -Path $WheelhouseDir -Filter "pycolmap-*.whl" | Sort-Object LastWriteTime -Descending
    if ($Wheels.Count -gt 0) {
        Write-Host ""
        Write-Host "Generated wheels:" -ForegroundColor Cyan
        foreach ($wheel in $Wheels) {
            $Size = [math]::Round($wheel.Length / 1MB, 2)
            Write-Host "  - $($wheel.Name) ($Size MB)" -ForegroundColor White
        }
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
if ($FailedBuilds.Count -eq 0) {
    Write-Host "All wheels built successfully!" -ForegroundColor Green
} else {
    Write-Host "Some builds failed - see summary above" -ForegroundColor Yellow
}
Write-Host "================================================================" -ForegroundColor Green
