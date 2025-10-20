# Bootstrap script for vcpkg on Windows using PowerShell
# This script initializes vcpkg and optionally installs dependencies

[CmdletBinding()]
param(
    [switch]$InstallDeps,
    [switch]$NoPrompt,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage: .\bootstrap.ps1 [options]

Options:
  -InstallDeps    Automatically install dependencies after bootstrapping
  -NoPrompt       Don't prompt for user input (auto-skip install if not specified)
  -Help           Show this help message

Examples:
  .\bootstrap.ps1                   Bootstrap vcpkg (prompt for dependency install)
  .\bootstrap.ps1 -InstallDeps      Bootstrap and install dependencies automatically
  .\bootstrap.ps1 -NoPrompt         Bootstrap only, skip dependency installation
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$VcpkgRoot = Join-Path $ProjectRoot "third_party\vcpkg"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "vcpkg Bootstrap Script for Windows" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Check if vcpkg submodule exists
$VcpkgGitDir = Join-Path $VcpkgRoot ".git"
if (-not (Test-Path $VcpkgGitDir)) {
    Write-Error "vcpkg submodule not found. Please run: git submodule update --init --recursive"
}

# Update vcpkg.json baseline with current vcpkg commit
Write-Host "Updating vcpkg.json baseline..." -ForegroundColor Yellow
Push-Location $VcpkgRoot
try {
    $VcpkgCommit = git rev-parse HEAD
    if ($LASTEXITCODE -eq 0) {
        $VcpkgJsonPath = Join-Path $ProjectRoot "vcpkg.json"
        if (Test-Path $VcpkgJsonPath) {
            $VcpkgJson = Get-Content $VcpkgJsonPath -Raw | ConvertFrom-Json
            $OldBaseline = $VcpkgJson.'builtin-baseline'

            if ($OldBaseline -ne $VcpkgCommit) {
                Write-Host "  Old baseline: $OldBaseline" -ForegroundColor Gray
                Write-Host "  New baseline: $VcpkgCommit" -ForegroundColor Green

                # Update baseline in JSON
                $VcpkgJson.'builtin-baseline' = $VcpkgCommit
                $VcpkgJson | ConvertTo-Json -Depth 10 | Set-Content $VcpkgJsonPath -Encoding UTF8
                Write-Host "  vcpkg.json baseline updated successfully!" -ForegroundColor Green
            } else {
                Write-Host "  Baseline already up to date: $VcpkgCommit" -ForegroundColor Green
            }
        }
    }
} catch {
    Write-Warning "Failed to update vcpkg baseline: $_"
} finally {
    Pop-Location
}
Write-Host ""

# Check if vcpkg is already bootstrapped
$VcpkgExe = Join-Path $VcpkgRoot "vcpkg.exe"
if (Test-Path $VcpkgExe) {
    Write-Host "vcpkg is already bootstrapped." -ForegroundColor Green
    Write-Host "vcpkg.exe found at: $VcpkgExe"
    Write-Host ""
} else {
    # Bootstrap vcpkg
    Write-Host "Bootstrapping vcpkg..." -ForegroundColor Yellow
    Write-Host "This may take a few minutes..." -ForegroundColor Yellow
    Write-Host ""

    $BootstrapScript = Join-Path $VcpkgRoot "bootstrap-vcpkg.bat"
    & cmd /c $BootstrapScript

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to bootstrap vcpkg"
    }

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "vcpkg bootstrapped successfully!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
}

# Determine if we should install dependencies
$ShouldInstall = $InstallDeps

if (-not $InstallDeps -and -not $NoPrompt) {
    $Response = Read-Host "Would you like to install dependencies now? (y/n)"
    $ShouldInstall = $Response -eq 'y' -or $Response -eq 'Y'
}

if ($ShouldInstall) {
    Write-Host ""
    Write-Host "Installing dependencies via vcpkg manifest..." -ForegroundColor Yellow
    Write-Host "This will install base dependencies defined in vcpkg.json" -ForegroundColor Yellow
    Write-Host ""

    Push-Location $ProjectRoot
    try {
        $VcpkgInstallDir = Join-Path $ProjectRoot "vcpkg_installed"
        & $VcpkgExe install --x-manifest-root=. --x-install-root=$VcpkgInstallDir

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Some dependencies failed to install. You can try again later or install manually."
        } else {
            Write-Host ""
            Write-Host "================================================================" -ForegroundColor Green
            Write-Host "Dependencies installed successfully!" -ForegroundColor Green
            Write-Host "================================================================" -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Bootstrap complete! You can now build the project using:" -ForegroundColor Cyan
Write-Host "  .\scripts_windows\build.ps1 -Configuration Release" -ForegroundColor White
Write-Host ""
