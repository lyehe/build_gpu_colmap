#!/usr/bin/env pwsh
# Script to automatically detect and pin COLMAP version for GLOMAP compatibility
# This script reads GLOMAP's expected COLMAP commit and checks out that version in colmap-for-glomap

param(
    [switch]$Force  # Force update even if already at correct version
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$GlomapPath = Join-Path $ProjectRoot "third_party\glomap"
$ColmapForGlomapPath = Join-Path $ProjectRoot "third_party\colmap-for-glomap"
$GlomapDepsFile = Join-Path $GlomapPath "cmake\FindDependencies.cmake"

Write-Host "[*] Syncing COLMAP version for GLOMAP compatibility..." -ForegroundColor Cyan

# Check if GLOMAP exists
if (-not (Test-Path $GlomapPath)) {
    Write-Host "[ERROR] GLOMAP submodule not found at: $GlomapPath" -ForegroundColor Red
    Write-Host "Run: git submodule update --init --recursive" -ForegroundColor Yellow
    exit 1
}

# Check if colmap-for-glomap exists
if (-not (Test-Path $ColmapForGlomapPath)) {
    Write-Host "[ERROR] colmap-for-glomap submodule not found at: $ColmapForGlomapPath" -ForegroundColor Red
    Write-Host "Run: git submodule update --init --recursive" -ForegroundColor Yellow
    exit 1
}

# Check if FindDependencies.cmake exists
if (-not (Test-Path $GlomapDepsFile)) {
    Write-Host "[ERROR] GLOMAP dependencies file not found: $GlomapDepsFile" -ForegroundColor Red
    exit 1
}

# Extract COLMAP commit from GLOMAP's FindDependencies.cmake
Write-Host "[1/4] Reading GLOMAP's expected COLMAP version..." -ForegroundColor Yellow
$GlomapDepsContent = Get-Content $GlomapDepsFile -Raw

if ($GlomapDepsContent -match 'FetchContent_Declare\(COLMAP[^\)]*GIT_TAG\s+([a-f0-9]{40})') {
    $ExpectedColmapCommit = $Matches[1]
    Write-Host "  Expected COLMAP commit: $ExpectedColmapCommit" -ForegroundColor White
} else {
    Write-Host "[ERROR] Could not find COLMAP GIT_TAG in $GlomapDepsFile" -ForegroundColor Red
    exit 1
}

# Get current COLMAP-for-GLOMAP commit
Write-Host "[2/4] Checking current colmap-for-glomap version..." -ForegroundColor Yellow
Push-Location $ColmapForGlomapPath
$CurrentCommit = (git rev-parse HEAD).Trim()
Pop-Location

Write-Host "  Current commit: $CurrentCommit" -ForegroundColor White

# Check if already at correct version
if ($CurrentCommit -eq $ExpectedColmapCommit -and -not $Force) {
    Write-Host "[OK] colmap-for-glomap is already at the correct version!" -ForegroundColor Green
    Write-Host "  Use -Force to update anyway" -ForegroundColor Gray
    exit 0
}

# Update colmap-for-glomap to expected version
Write-Host "[3/4] Updating colmap-for-glomap to expected version..." -ForegroundColor Yellow
Push-Location $ColmapForGlomapPath

try {
    # Fetch latest commits
    Write-Host "  Fetching COLMAP commits..." -ForegroundColor Gray
    git fetch origin | Out-Null

    # Check if commit exists
    $CommitExists = git cat-file -e "$ExpectedColmapCommit^{commit}" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Commit $ExpectedColmapCommit not found in COLMAP repository" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    # Checkout expected commit
    Write-Host "  Checking out commit $ExpectedColmapCommit..." -ForegroundColor Gray

    # Temporarily suppress error action preference for git checkout
    # Git outputs informational messages to stderr which PowerShell treats as errors
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $null = git checkout $ExpectedColmapCommit 2>&1
    $CheckoutExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference

    if ($CheckoutExitCode -eq 0) {
        Write-Host "[OK] Successfully updated colmap-for-glomap" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Failed to checkout commit" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} finally {
    Pop-Location
}

# Verify final state
Write-Host "[4/4] Verifying update..." -ForegroundColor Yellow
Push-Location $ColmapForGlomapPath
$FinalCommit = (git rev-parse HEAD).Trim()
$CommitMessage = (git log -1 --oneline).Trim()
Pop-Location

if ($FinalCommit -eq $ExpectedColmapCommit) {
    Write-Host "[SUCCESS] colmap-for-glomap is now at the correct version!" -ForegroundColor Green
    Write-Host "  Commit: $FinalCommit" -ForegroundColor White
    Write-Host "  Message: $CommitMessage" -ForegroundColor White
    Write-Host ""
    Write-Host "You can now build GLOMAP with: .\scripts_windows\build.ps1" -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Verification failed - final commit doesn't match expected" -ForegroundColor Red
    Write-Host "  Expected: $ExpectedColmapCommit" -ForegroundColor Red
    Write-Host "  Got: $FinalCommit" -ForegroundColor Red
    exit 1
}
