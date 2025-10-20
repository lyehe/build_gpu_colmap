# Build pycolmap wheels for all installed Python versions
# Usage: .\build_pycolmap_wheels_all.ps1 [-Configuration Debug|Release] [-NoCuda]

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

This script automatically detects all Python 3.9+ installations and builds
a wheel for each version.

Usage: .\build_pycolmap_wheels_all.ps1 [options]

Options:
  -Configuration <Debug|Release>  Build configuration (default: Release)
  -NoCuda                         Build without CUDA support
  -Clean                          Clean build before each version
  -Help                           Show this help message

Detection:
  The script searches for Python installations in:
  - py launcher (py -3.9, py -3.10, etc.)
  - PATH environment variable
  - Common installation directories

Requirements:
  - COLMAP already built (run build_colmap.ps1 first)
  - Multiple Python versions installed (3.9, 3.10, 3.11, 3.12, 3.13+)

Output:
  All wheels in: third_party\colmap\wheelhouse\
  - pycolmap-*-cp39-*.whl
  - pycolmap-*-cp310-*.whl
  - pycolmap-*-cp311-*.whl
  - pycolmap-*-cp312-*.whl
  - etc.

Examples:
  .\build_pycolmap_wheels_all.ps1
  .\build_pycolmap_wheels_all.ps1 -NoCuda
  .\build_pycolmap_wheels_all.ps1 -Clean
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SingleWheelScript = Join-Path $ScriptDir "build_pycolmap_wheel.ps1"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Build pycolmap Wheels for All Python Versions" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Configuration: $Configuration" -ForegroundColor White
Write-Host "CUDA: $(if ($NoCuda) { 'Disabled' } else { 'Enabled' })" -ForegroundColor White
Write-Host "================================================================" -ForegroundColor Cyan

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
        # Build wheel using the single-version script
        $BuildArgs = @{
            Configuration = $Configuration
        }
        if ($NoCuda) { $BuildArgs['NoCuda'] = $true }
        if ($Clean) { $BuildArgs['Clean'] = $true }

        & $SingleWheelScript @BuildArgs

        if ($LASTEXITCODE -eq 0) {
            $SuccessfulBuilds += "Python $($ver.Full)"
            Write-Host ""
            Write-Host "SUCCESS: Wheel built for Python $($ver.Full)" -ForegroundColor Green
        } else {
            $FailedBuilds += "Python $($ver.Full)"
            Write-Host ""
            Write-Host "FAILED: Wheel build failed for Python $($ver.Full)" -ForegroundColor Red
        }
    } catch {
        $FailedBuilds += "Python $($ver.Full)"
        Write-Host ""
        Write-Host "ERROR: Exception during build for Python $($ver.Full)" -ForegroundColor Red
        Write-Host "  $_" -ForegroundColor Red
    } finally {
        # Restore original PATH
        $env:PATH = $OriginalPath
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
Write-Host "All wheels are in: third_party\colmap\wheelhouse\" -ForegroundColor Cyan

$WheelhouseDir = Join-Path $ScriptDir "..\third_party\colmap\wheelhouse"
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
