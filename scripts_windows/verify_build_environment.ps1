# Build Environment Verification Script for Windows
# This script checks all required build tools and dependencies
# Usage: .\verify_build_environment.ps1 [-CheckCuda]

[CmdletBinding()]
param(
    [switch]$CheckCuda = $true,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage: .\verify_build_environment.ps1 [options]

This script verifies that all required build tools and dependencies are available.

Options:
  -CheckCuda      Check for CUDA toolkit (default: true)
  -Help           Show this help message

Examples:
  .\verify_build_environment.ps1              Verify all tools including CUDA
  .\verify_build_environment.ps1 -CheckCuda:`$false  Skip CUDA verification
"@
    exit 0
}

$ErrorActionPreference = 'Continue'
$WarningPreference = 'Continue'

# Track overall status
$AllChecksPassed = $true
$Warnings = @()
$FailedChecks = @()

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Build Environment Verification for Windows" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Helper function to check command availability
function Test-Command {
    param([string]$Command)
    try {
        if (Get-Command $Command -ErrorAction SilentlyContinue) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Helper function to print status
function Write-Status {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Version = "",
        [string]$ErrorMessage = "",
        [string]$Solution = ""
    )

    $StatusSymbol = if ($Passed) { "[OK]" } else { "[FAIL]" }
    $StatusColor = if ($Passed) { "Green" } else { "Red" }

    Write-Host ("{0,-30}" -f $Name) -NoNewline
    Write-Host $StatusSymbol -ForegroundColor $StatusColor -NoNewline

    if ($Version -ne "") {
        Write-Host " - $Version" -ForegroundColor Gray
    } else {
        Write-Host ""
    }

    if (-not $Passed) {
        Write-Host "  ERROR: $ErrorMessage" -ForegroundColor Red
        Write-Host "  SOLUTION: $Solution" -ForegroundColor Yellow
        Write-Host ""
        $script:AllChecksPassed = $false
        $script:FailedChecks += $Name
    }
}

# Check 1: PowerShell Version
Write-Host "[1/9] Checking PowerShell..." -ForegroundColor Yellow
$PSVersion = $PSVersionTable.PSVersion
if ($PSVersion.Major -ge 5) {
    Write-Status "PowerShell" $true "v$($PSVersion.Major).$($PSVersion.Minor)"
} else {
    Write-Status "PowerShell" $false "v$($PSVersion.Major).$($PSVersion.Minor)" `
        "PowerShell 5.0 or later is required" `
        "Update PowerShell: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows"
}

# Check 2: Visual Studio / MSVC
Write-Host "[2/9] Checking Visual Studio Build Tools..." -ForegroundColor Yellow

# Check if we're in a Visual Studio Developer Command Prompt
$InVSDevShell = $false
if ($env:VSINSTALLDIR -or $env:VisualStudioVersion) {
    $InVSDevShell = $true
}

# Try to find cl.exe (MSVC compiler)
$ClExe = Test-Command "cl"

if ($ClExe) {
    try {
        $ClVersion = & cl 2>&1 | Select-String "Version" | Select-Object -First 1
        Write-Status "MSVC Compiler (cl.exe)" $true $ClVersion.ToString().Trim()
    } catch {
        Write-Status "MSVC Compiler (cl.exe)" $true "Found"
    }

    if (-not $InVSDevShell) {
        $Warnings += "Not running in Visual Studio Developer Command Prompt"
        Write-Host "  WARNING: You are not in a Visual Studio Developer Command Prompt" -ForegroundColor Yellow
        Write-Host "  RECOMMENDATION: Run scripts from 'Developer Command Prompt for VS' or 'Developer PowerShell for VS'" -ForegroundColor Cyan
        Write-Host ""
    }
} else {
    # Try to find Visual Studio installation and offer to launch Developer PowerShell
    $VSWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $VSDevShellFound = $false
    $VSDevShellScript = $null
    $VSType = "None"
    $VSProductName = $null

    if (Test-Path $VSWherePath) {
        try {
            # Try to find full Visual Studio IDE first
            $VSIDEPath = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.Community,Microsoft.VisualStudio.Product.Professional,Microsoft.VisualStudio.Product.Enterprise -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null

            # Then try Build Tools
            $VSBuildToolsPath = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.BuildTools -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null

            # Use whichever is found (prefer IDE if both exist)
            $VSInstallPath = $null
            if ($VSIDEPath) {
                $VSInstallPath = $VSIDEPath
                $VSType = "IDE"
                $VSProductName = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.Community,Microsoft.VisualStudio.Product.Professional,Microsoft.VisualStudio.Product.Enterprise -property displayName 2>$null
            } elseif ($VSBuildToolsPath) {
                $VSInstallPath = $VSBuildToolsPath
                $VSType = "BuildTools"
                $VSProductName = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.BuildTools -property displayName 2>$null
            }

            if ($VSInstallPath) {
                # Try to find the Developer PowerShell module
                $VSDevShellScript = Join-Path $VSInstallPath "Common7\Tools\Launch-VsDevShell.ps1"
                if (Test-Path $VSDevShellScript) {
                    $VSDevShellFound = $true
                }
            }
        } catch {
            # Silently continue if vswhere fails
        }
    }

    Write-Status "MSVC Compiler (cl.exe)" $false "" `
        "Visual Studio Build Tools not found or not in PATH" `
        @"
Install Visual Studio 2019 or later with 'Desktop development with C++' workload
OR install 'Build Tools for Visual Studio': https://visualstudio.microsoft.com/downloads/

After installation, run this script from:
  - 'Developer Command Prompt for VS 2022' (or your VS version)
  - 'Developer PowerShell for VS 2022'

To find it: Start Menu -> Visual Studio 2022 -> Developer Command Prompt/PowerShell
"@

    # Show which VS product was found
    if ($VSDevShellFound) {
        Write-Host ""
        Write-Host "  DETECTED: $VSProductName ($VSType) is installed but not active" -ForegroundColor Cyan
    }

    # Offer to launch Developer PowerShell if found
    if ($VSDevShellFound) {
        Write-Host ""
        Write-Host "  SHORTCUT DETECTED: Visual Studio Developer Environment found!" -ForegroundColor Green
        $Response = Read-Host "  Would you like to launch Developer PowerShell now and re-run verification? (y/n)"

        if ($Response -eq 'y' -or $Response -eq 'Y') {
            Write-Host ""
            Write-Host "  Launching Developer PowerShell..." -ForegroundColor Cyan
            Write-Host ""

            # Create a script to run in the new shell
            $TempScript = Join-Path $env:TEMP "launch_devshell_verify.ps1"
            $CurrentScript = $MyInvocation.MyCommand.Path

            @"
# Import Visual Studio Developer Environment
& '$VSDevShellScript' -Arch amd64 -HostArch amd64

# Change to project directory
Set-Location '$ProjectRoot'

# Re-run verification script
& '$CurrentScript' $(if (-not $CheckCuda) { '-CheckCuda:`$false' } else { '' })

# Wait for user input before closing
Write-Host ''
Write-Host 'Press any key to exit...' -ForegroundColor Cyan
`$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
"@ | Out-File -FilePath $TempScript -Encoding UTF8

            # Launch new PowerShell window with the script
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$TempScript`""

            Write-Host "  Developer PowerShell launched in a new window." -ForegroundColor Green
            Write-Host "  This window will now close." -ForegroundColor Gray
            Start-Sleep -Seconds 2
            exit 0
        }
    }
}

# Check 3: CMake
Write-Host "[3/9] Checking CMake..." -ForegroundColor Yellow
if (Test-Command "cmake") {
    try {
        $CMakeVersion = (cmake --version | Select-Object -First 1) -replace 'cmake version ', ''
        $CMakeVersionParsed = [version]($CMakeVersion -split '-')[0]

        if ($CMakeVersionParsed -ge [version]"3.28") {
            Write-Status "CMake" $true "v$CMakeVersion"
        } else {
            Write-Status "CMake" $false "v$CMakeVersion (too old)" `
                "CMake 3.28 or later is required (found $CMakeVersion)" `
                "Download from: https://cmake.org/download/"
        }
    } catch {
        Write-Status "CMake" $true "Found (version check failed)"
    }
} else {
    Write-Status "CMake" $false "" `
        "CMake not found in PATH" `
        "Download and install CMake 3.28+ from: https://cmake.org/download/ (select 'Add to PATH during installation')"
}

# Check 4: Git
Write-Host "[4/9] Checking Git..." -ForegroundColor Yellow
if (Test-Command "git") {
    try {
        $GitVersion = (git --version) -replace 'git version ', ''
        Write-Status "Git" $true "v$GitVersion"
    } catch {
        Write-Status "Git" $true "Found (version check failed)"
    }
} else {
    Write-Status "Git" $false "" `
        "Git not found in PATH" `
        "Download and install Git from: https://git-scm.com/download/win"
}

# Check 5: Python
Write-Host "[5/9] Checking Python..." -ForegroundColor Yellow
if (Test-Command "python") {
    try {
        $PythonVersion = (python --version 2>&1) -replace 'Python ', ''
        $PythonVersionParsed = [version]($PythonVersion -split ' ')[0]

        if ($PythonVersionParsed -ge [version]"3.8") {
            Write-Status "Python" $true "v$PythonVersion"
        } else {
            Write-Status "Python" $false "v$PythonVersion (too old)" `
                "Python 3.8 or later is required for PyCeres (found $PythonVersion)" `
                "Download from: https://www.python.org/downloads/ (select 'Add to PATH' during installation)"
        }
    } catch {
        Write-Status "Python" $true "Found (version check failed)"
    }
} else {
    Write-Status "Python" $false "" `
        "Python not found in PATH (required for PyCeres)" `
        "Download and install Python 3.8+ from: https://www.python.org/downloads/ (select 'Add to PATH during installation')"
}

# Check 6: CUDA Toolkit (if requested)
if ($CheckCuda) {
    Write-Host "[6/9] Checking CUDA Toolkit..." -ForegroundColor Yellow

    $CudaPath = $env:CUDA_PATH
    $NvccFound = Test-Command "nvcc"

    if ($NvccFound) {
        try {
            $NvccOutput = nvcc --version 2>&1 | Select-String "release"
            $CudaVersion = ($NvccOutput -split "release ")[1] -split "," | Select-Object -First 1
            Write-Status "CUDA Toolkit (nvcc)" $true "v$CudaVersion"
        } catch {
            Write-Status "CUDA Toolkit (nvcc)" $true "Found (version check failed)"
        }
    } else {
        Write-Status "CUDA Toolkit (nvcc)" $false "" `
            "CUDA Toolkit not found or nvcc not in PATH" `
            @"
Download and install CUDA Toolkit 11.0+ from: https://developer.nvidia.com/cuda-downloads

After installation:
  1. Verify CUDA_PATH environment variable is set (usually C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\vXX.X)
  2. Ensure CUDA bin directory is in PATH
  3. Restart your terminal/PowerShell session

To build without CUDA, use: -NoCuda flag with build scripts
"@
    }

    # Check CUDA_PATH environment variable
    if ($CudaPath) {
        Write-Status "CUDA_PATH Environment" $true $CudaPath
    } else {
        if ($NvccFound) {
            $Warnings += "CUDA_PATH not set (but nvcc found in PATH)"
            Write-Host "  WARNING: CUDA_PATH environment variable is not set" -ForegroundColor Yellow
            Write-Host ""
        }
    }

    # Check for cuDSS (CUDA Direct Sparse Solver) - optional but useful for COLMAP
    $CudssFound = $false
    $CudssLocation = ""

    # Check standard cuDSS installation directory first
    if (Test-Path "${env:ProgramFiles}\NVIDIA cuDSS") {
        $CudssVersions = Get-ChildItem "${env:ProgramFiles}\NVIDIA cuDSS" -Directory | Sort-Object Name -Descending
        if ($CudssVersions) {
            $LatestCudss = $CudssVersions[0]
            $CudssInclude = Join-Path $LatestCudss.FullName "include\cudss.h"

            # Check for lib file - it might be in lib/ or lib/12/ (for CUDA 12) or lib/13/ (for CUDA 13)
            $CudssLibLocations = @(
                (Join-Path $LatestCudss.FullName "lib\cudss.lib"),
                (Join-Path $LatestCudss.FullName "lib\12\cudss.lib"),
                (Join-Path $LatestCudss.FullName "lib\13\cudss.lib")
            )

            $CudssLibFound = $false
            foreach ($LibPath in $CudssLibLocations) {
                if (Test-Path $LibPath) {
                    $CudssLibFound = $true
                    break
                }
            }

            if ((Test-Path $CudssInclude) -and $CudssLibFound) {
                $CudssFound = $true
                $CudssLocation = "Standalone installation ($($LatestCudss.Name))"
            }
        }
    }

    # Check CUDSS_DIR environment variable (for manual extractions)
    if (-not $CudssFound -and $env:CUDSS_DIR) {
        $CudssInclude = Join-Path $env:CUDSS_DIR "include\cudss.h"

        $CudssLibLocations = @(
            (Join-Path $env:CUDSS_DIR "lib\cudss.lib"),
            (Join-Path $env:CUDSS_DIR "lib\12\cudss.lib"),
            (Join-Path $env:CUDSS_DIR "lib\13\cudss.lib")
        )

        $CudssLibFound = $false
        foreach ($LibPath in $CudssLibLocations) {
            if (Test-Path $LibPath) {
                $CudssLibFound = $true
                break
            }
        }

        if ((Test-Path $CudssInclude) -and $CudssLibFound) {
            $CudssFound = $true
            $CudssLocation = "User-defined location (CUDSS_DIR)"
        }
    }

    # Check CUDA toolkit directory as fallback (for manual installs into CUDA dir)
    if (-not $CudssFound -and $CudaPath) {
        $CudssInclude = Join-Path $CudaPath "include\cudss.h"
        $CudssLib = Join-Path $CudaPath "lib\x64\cudss.lib"

        if ((Test-Path $CudssInclude) -and (Test-Path $CudssLib)) {
            $CudssFound = $true
            $CudssLocation = "Integrated with CUDA Toolkit"
        }
    }

    if ($CudssFound) {
        Write-Status "cuDSS (CUDA Sparse Solver)" $true $CudssLocation
    } else {
        Write-Host "cuDSS (CUDA Sparse Solver)    [NOT FOUND]" -ForegroundColor Yellow
        Write-Host "  NOTE: cuDSS is optional but provides significant performance improvements for sparse solvers" -ForegroundColor Cyan
        Write-Host "  INSTALL: Download installer from https://developer.nvidia.com/cudss-downloads" -ForegroundColor Cyan
        Write-Host "           (Installer will place files in: C:\Program Files\NVIDIA cuDSS\)" -ForegroundColor Cyan
        Write-Host ""
    }
} else {
    Write-Host "[6/9] Skipping CUDA check (disabled)" -ForegroundColor Gray
}

# Check 7: Ninja (optional but recommended)
Write-Host "[7/9] Checking Ninja Build System (optional)..." -ForegroundColor Yellow
if (Test-Command "ninja") {
    try {
        $NinjaVersion = (ninja --version)
        Write-Status "Ninja" $true "v$NinjaVersion"
    } catch {
        Write-Status "Ninja" $true "Found"
    }
} else {
    Write-Host "Ninja                         [NOT FOUND]" -ForegroundColor Yellow
    Write-Host "  NOTE: Ninja is optional but recommended for faster builds" -ForegroundColor Cyan
    Write-Host "  INSTALL: Download from https://github.com/ninja-build/ninja/releases or install via: choco install ninja" -ForegroundColor Cyan
    Write-Host ""
}

# Check 8: vcpkg (check if submodule exists)
Write-Host "[8/9] Checking vcpkg submodule..." -ForegroundColor Yellow
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$VcpkgPath = Join-Path $ProjectRoot "third_party\vcpkg"
$VcpkgExe = Join-Path $VcpkgPath "vcpkg.exe"

if (Test-Path $VcpkgPath) {
    if (Test-Path $VcpkgExe) {
        Write-Status "vcpkg" $true "Bootstrapped"
    } else {
        Write-Host "vcpkg                         [NOT BOOTSTRAPPED]" -ForegroundColor Yellow
        Write-Host "  NOTE: vcpkg submodule exists but is not bootstrapped" -ForegroundColor Cyan
        Write-Host "  RUN: .\scripts_windows\bootstrap.ps1" -ForegroundColor Cyan
        Write-Host ""
    }
} else {
    Write-Host "vcpkg                         [NOT INITIALIZED]" -ForegroundColor Yellow
    Write-Host "  NOTE: vcpkg submodule not initialized" -ForegroundColor Cyan
    Write-Host "  RUN: git submodule update --init --recursive" -ForegroundColor Cyan
    Write-Host ""
}

# Check 9: Disk Space
Write-Host "[9/9] Checking available disk space..." -ForegroundColor Yellow
try {
    $Drive = (Get-Location).Drive
    $FreeSpaceGB = [math]::Round((Get-PSDrive $Drive.Name).Free / 1GB, 2)

    if ($FreeSpaceGB -gt 50) {
        Write-Status "Disk Space" $true "$FreeSpaceGB GB available"
    } elseif ($FreeSpaceGB -gt 20) {
        Write-Status "Disk Space" $true "$FreeSpaceGB GB available (warning: may be insufficient)"
        $Warnings += "Low disk space ($FreeSpaceGB GB) - build may require 30-50 GB"
    } else {
        Write-Status "Disk Space" $false "$FreeSpaceGB GB available" `
            "Insufficient disk space for build (at least 30-50 GB recommended)" `
            "Free up disk space on drive $($Drive.Name):"
    }
} catch {
    Write-Host "Disk Space                    [CHECK FAILED]" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

if ($AllChecksPassed) {
    Write-Host ""
    Write-Host "All critical checks passed!" -ForegroundColor Green
    if ($Warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Warnings ($($Warnings.Count)):" -ForegroundColor Yellow
        foreach ($Warning in $Warnings) {
            Write-Host "  - $Warning" -ForegroundColor Yellow
        }
    }
    Write-Host ""
    Write-Host "You can proceed with building:" -ForegroundColor Cyan
    Write-Host "  .\scripts_windows\build.ps1 -Configuration Release" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host ""
    Write-Host "Some checks failed. Please fix the errors above before building." -ForegroundColor Red
    Write-Host ""
    Write-Host "Failed checks ($($FailedChecks.Count)):" -ForegroundColor Red
    foreach ($Check in $FailedChecks) {
        Write-Host "  - $Check" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "After fixing issues, run this script again to verify." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
