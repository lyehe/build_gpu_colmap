# Complete setup script for a new Point Cloud Tools repository
# This script initializes all submodules, bootstraps vcpkg, and prepares the environment
# Usage: .\setup_new_repo.ps1 [-InstallDeps] [-NoCuda]

[CmdletBinding()]
param(
    [switch]$InstallDeps,
    [switch]$NoCuda,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage: .\setup_new_repo.ps1 [options]

This script performs a complete setup for a new repository clone:
1. Initializes and updates all git submodules
2. Bootstraps vcpkg
3. Optionally installs dependencies

Options:
  -InstallDeps    Automatically install vcpkg dependencies
  -NoCuda         Configure for build without CUDA support
  -Help           Show this help message

Examples:
  .\setup_new_repo.ps1                     Setup with prompts
  .\setup_new_repo.ps1 -InstallDeps        Setup and install dependencies
  .\setup_new_repo.ps1 -InstallDeps -NoCuda  Setup without CUDA
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Point Cloud Tools - New Repository Setup" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Initialize git submodules
Write-Host "[1/3] Initializing git submodules..." -ForegroundColor Yellow
Write-Host "This may take several minutes depending on your internet connection..." -ForegroundColor Gray
Write-Host ""

Push-Location $ProjectRoot
try {
    # Check if we're in a git repository
    $gitCheck = git rev-parse --git-dir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not a git repository. Please clone the repository first."
    }

    # Initialize and update all submodules recursively
    git submodule update --init --recursive --progress

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to initialize submodules"
    }

    Write-Host ""
    Write-Host "Submodules initialized successfully!" -ForegroundColor Green
    Write-Host ""

    # Show submodule status
    Write-Host "Submodule status:" -ForegroundColor Cyan
    git submodule status
    Write-Host ""

} finally {
    Pop-Location
}

# Step 2: Bootstrap vcpkg
Write-Host "[2/3] Bootstrapping vcpkg..." -ForegroundColor Yellow
Write-Host ""

$VcpkgRoot = Join-Path $ProjectRoot "third_party\vcpkg"
$VcpkgExe = Join-Path $VcpkgRoot "vcpkg.exe"

if (Test-Path $VcpkgExe) {
    Write-Host "vcpkg is already bootstrapped." -ForegroundColor Green
} else {
    $BootstrapScript = Join-Path $VcpkgRoot "bootstrap-vcpkg.bat"

    if (-not (Test-Path $BootstrapScript)) {
        Write-Error "vcpkg bootstrap script not found. Submodules may not be initialized correctly."
    }

    Write-Host "Running vcpkg bootstrap..." -ForegroundColor Gray
    & cmd /c $BootstrapScript

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to bootstrap vcpkg"
    }

    Write-Host ""
    Write-Host "vcpkg bootstrapped successfully!" -ForegroundColor Green
}

Write-Host ""

# Step 3: Install dependencies (optional)
Write-Host "[3/3] Installing dependencies..." -ForegroundColor Yellow

$ShouldInstall = $InstallDeps

if (-not $InstallDeps) {
    $Response = Read-Host "Would you like to install vcpkg dependencies now? (y/n)"
    $ShouldInstall = $Response -eq 'y' -or $Response -eq 'Y'
}

if ($ShouldInstall) {
    Write-Host ""
    Write-Host "Installing base dependencies from vcpkg.json..." -ForegroundColor Gray
    Write-Host "This will take a while on first run (15-30 minutes)..." -ForegroundColor Gray
    Write-Host ""

    Push-Location $ProjectRoot
    try {
        $VcpkgInstallDir = Join-Path $ProjectRoot "vcpkg_installed"

        # Install base dependencies
        & $VcpkgExe install --x-manifest-root=. --x-install-root=$VcpkgInstallDir

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Some dependencies failed to install. You can try again later."
        } else {
            Write-Host ""
            Write-Host "Dependencies installed successfully!" -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "Skipping dependency installation." -ForegroundColor Gray
    Write-Host "You can install dependencies later by running:" -ForegroundColor Cyan
    Write-Host "  .\scripts_windows\bootstrap.ps1 -InstallDeps" -ForegroundColor White
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "Repository Setup Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

# Print next steps
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host ""

if ($NoCuda) {
    Write-Host "To build the project (without CUDA):" -ForegroundColor Yellow
    Write-Host "  .\scripts_windows\build.ps1 -Configuration Release -NoCuda" -ForegroundColor White
} else {
    Write-Host "To build the project:" -ForegroundColor Yellow
    Write-Host "  .\scripts_windows\build.ps1 -Configuration Release" -ForegroundColor White
}

Write-Host ""
Write-Host "To update submodules in the future:" -ForegroundColor Yellow
Write-Host "  .\scripts_windows\update_submodules.ps1 -All" -ForegroundColor White
Write-Host ""
Write-Host "For more information, see README.md" -ForegroundColor Cyan
Write-Host ""
