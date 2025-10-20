# Build pycolmap wheel with bundled DLLs
# Usage: .\build_pycolmap_wheel.ps1 [-Configuration Debug|Release] [-NoCuda]

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
Build pycolmap Python wheel with bundled DLLs

This script:
  1. Ensures COLMAP is built and installed
  2. Builds pycolmap Python bindings
  3. Bundles all required DLLs using delvewheel
  4. Creates a redistributable .whl file

Usage: .\build_pycolmap_wheel.ps1 [options]

Options:
  -Configuration <Debug|Release>  Build configuration (default: Release)
  -NoCuda                         Build without CUDA support
  -Clean                          Clean build before building
  -Help                           Show this help message

Requirements:
  - Python 3.9+ with pip
  - COLMAP already built (run build_colmap.ps1 first)
  - delvewheel (installed automatically)

Output:
  Wheel file: dist/pycolmap-*.whl

Examples:
  .\build_pycolmap_wheel.ps1
  .\build_pycolmap_wheel.ps1 -NoCuda
  .\build_pycolmap_wheel.ps1 -Clean -Configuration Debug
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$ColmapSource = Join-Path $ProjectRoot "third_party\colmap"
$BuildDir = Join-Path $ProjectRoot "build"
$ColmapInstall = Join-Path $BuildDir "install\colmap"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Build pycolmap Wheel with Bundled DLLs" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor White
Write-Host "CUDA: $(if ($NoCuda) { 'Disabled' } else { 'Enabled' })" -ForegroundColor White
Write-Host "COLMAP Source: $ColmapSource" -ForegroundColor White
Write-Host "COLMAP Install: $ColmapInstall" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

# Check if COLMAP is built
if (-not (Test-Path $ColmapInstall)) {
    Write-Host ""
    Write-Host "ERROR: COLMAP not found at $ColmapInstall" -ForegroundColor Red
    Write-Host "Please build COLMAP first:" -ForegroundColor Yellow
    Write-Host "  .\scripts_windows\build_colmap.ps1 -Configuration $Configuration" -ForegroundColor White
    exit 1
}

# Verify COLMAP installation
$ColmapBin = Join-Path $ColmapInstall "bin\colmap.exe"
if (-not (Test-Path $ColmapBin)) {
    Write-Host ""
    Write-Host "ERROR: COLMAP executable not found at $ColmapBin" -ForegroundColor Red
    Write-Host "COLMAP installation appears incomplete" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Found COLMAP installation at $ColmapInstall" -ForegroundColor Green

# Check Python installation
Write-Host ""
Write-Host "Checking Python installation..." -ForegroundColor Yellow
try {
    $PythonVersion = python --version 2>&1
    Write-Host "Python version: $PythonVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python not found in PATH" -ForegroundColor Red
    Write-Host "Please install Python 3.9+ and add it to PATH" -ForegroundColor Yellow
    exit 1
}

# Check Python version (need 3.9+)
$PythonVersionMatch = $PythonVersion -match 'Python (\d+)\.(\d+)'
if ($PythonVersionMatch) {
    $Major = [int]$Matches[1]
    $Minor = [int]$Matches[2]
    if ($Major -lt 3 -or ($Major -eq 3 -and $Minor -lt 9)) {
        Write-Host "ERROR: Python 3.9+ required, found Python $Major.$Minor" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "WARNING: Could not parse Python version" -ForegroundColor Yellow
}

# Install build dependencies
Write-Host ""
Write-Host "Installing Python build dependencies..." -ForegroundColor Yellow
python -m pip install --upgrade pip wheel build delvewheel
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install Python dependencies"
}

# Always clean build directory to avoid CMake cache issues
Write-Host ""
Write-Host "Cleaning previous pycolmap build..." -ForegroundColor Yellow

$PycolmapDirs = @(
    (Join-Path $ColmapSource "build"),
    (Join-Path $ColmapSource "dist"),
    (Join-Path $ColmapSource "_skbuild"),
    (Join-Path $ColmapSource "python\pycolmap.egg-info")
)

foreach ($dir in $PycolmapDirs) {
    if (Test-Path $dir) {
        Remove-Item -Recurse -Force $dir
        Write-Host "  Removed: $dir" -ForegroundColor DarkGray
    }
}

# Set environment variables for build
Write-Host ""
Write-Host "Configuring build environment..." -ForegroundColor Yellow

# Point to our COLMAP installation
$VcpkgRoot = Join-Path $ProjectRoot "third_party\vcpkg"
$VcpkgToolchain = Join-Path $VcpkgRoot "scripts\buildsystems\vcpkg.cmake"
$VcpkgInstalled = Join-Path $BuildDir "vcpkg_installed\x64-windows"

$env:CMAKE_PREFIX_PATH = "$ColmapInstall;$VcpkgInstalled"
$env:COLMAP_INSTALL_PATH = $ColmapInstall

# Use vcpkg toolchain so it can find all dependencies properly
# Pass CMake arguments to disable GUI/OpenGL features not needed for Python bindings
# GFLAGS_USE_TARGET_NAMESPACE=ON ensures gflags creates gflags::gflags target that glog expects
$env:CMAKE_ARGS = "-DCMAKE_TOOLCHAIN_FILE=`"$VcpkgToolchain`" -DGUI_ENABLED=OFF -DOPENGL_ENABLED=OFF -DTESTS_ENABLED=OFF -DGFLAGS_USE_TARGET_NAMESPACE=ON"

# Add COLMAP bin and vcpkg bin to PATH for DLL discovery
$VcpkgBin = Join-Path $VcpkgInstalled "bin"
$ColmapBin = Join-Path $ColmapInstall "bin"
$env:PATH = "$ColmapBin;$VcpkgBin;$env:PATH"

Write-Host "  CMAKE_PREFIX_PATH: $env:CMAKE_PREFIX_PATH" -ForegroundColor DarkGray
Write-Host "  COLMAP_INSTALL_PATH: $env:COLMAP_INSTALL_PATH" -ForegroundColor DarkGray
Write-Host "  CMAKE_ARGS: $env:CMAKE_ARGS" -ForegroundColor DarkGray
Write-Host "  PATH (added): $ColmapBin;$VcpkgBin" -ForegroundColor DarkGray

# Navigate to COLMAP source
Push-Location $ColmapSource
try {
    # Build the wheel
    Write-Host ""
    Write-Host "Building pycolmap wheel..." -ForegroundColor Green
    Write-Host "  This may take 10-15 minutes..." -ForegroundColor DarkGray

    # Use python -m build to create wheel
    python -m build --wheel --outdir dist

    if ($LASTEXITCODE -ne 0) {
        throw "Wheel build failed"
    }

    # Find the generated wheel
    $WheelFiles = Get-ChildItem -Path "dist" -Filter "pycolmap-*.whl" | Sort-Object LastWriteTime -Descending
    if ($WheelFiles.Count -eq 0) {
        throw "No wheel file found in dist/"
    }

    $WheelFile = $WheelFiles[0].FullName
    Write-Host ""
    Write-Host "Wheel built successfully: $($WheelFiles[0].Name)" -ForegroundColor Green

    # Bundle DLLs using delvewheel
    Write-Host ""
    Write-Host "Bundling DLLs with delvewheel..." -ForegroundColor Green
    Write-Host "  This will include all required DLLs in the wheel" -ForegroundColor DarkGray

    # Create wheelhouse directory for repaired wheels
    $WheelhouseDir = Join-Path $ColmapSource "wheelhouse"
    if (-not (Test-Path $WheelhouseDir)) {
        New-Item -ItemType Directory -Path $WheelhouseDir | Out-Null
    }

    # Run delvewheel to bundle DLLs
    # --add-path includes both COLMAP and vcpkg bin directories for DLL discovery
    delvewheel repair `
        --add-path "$ColmapBin;$VcpkgBin" `
        --wheel-dir "$WheelhouseDir" `
        "$WheelFile"

    if ($LASTEXITCODE -ne 0) {
        throw "delvewheel failed to bundle DLLs"
    }

    # Find the repaired wheel
    $RepairedWheels = Get-ChildItem -Path $WheelhouseDir -Filter "pycolmap-*.whl" | Sort-Object LastWriteTime -Descending
    if ($RepairedWheels.Count -eq 0) {
        throw "No repaired wheel found in wheelhouse/"
    }

    $RepairedWheel = $RepairedWheels[0]

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "pycolmap wheel build completed successfully!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Wheel file (with bundled DLLs):" -ForegroundColor Cyan
    Write-Host "  $($RepairedWheel.FullName)" -ForegroundColor White
    Write-Host ""
    Write-Host "Wheel size: $([math]::Round($RepairedWheel.Length / 1MB, 2)) MB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To install:" -ForegroundColor Cyan
    Write-Host "  pip install `"$($RepairedWheel.FullName)`"" -ForegroundColor White
    Write-Host ""
    Write-Host "To test:" -ForegroundColor Cyan
    Write-Host "  python -c `"import pycolmap; print(pycolmap.__version__)`"" -ForegroundColor White
    Write-Host "================================================================" -ForegroundColor Green

} finally {
    Pop-Location
}
