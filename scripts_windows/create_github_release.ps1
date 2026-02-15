# GitHub Release Creation Script
# This script creates a GitHub release and uploads all assets from releases/ directory

$ErrorActionPreference = "Stop"

# Configuration
$RELEASE_TAG = "v1.0.0"
$RELEASE_TITLE = "Point Cloud Tools v1.0.0 - Windows CUDA Build"
$GH_CLI = "C:\Program Files\GitHub CLI\gh.exe"

# Setup paths
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$RELEASES_DIR = Join-Path $PROJECT_ROOT "releases"
$RELEASE_NOTES_FILE = Join-Path $RELEASES_DIR "RELEASE_NOTES.md"

# Change to releases directory
if (-not (Test-Path $RELEASES_DIR)) {
    Write-Host "ERROR: Releases directory not found: $RELEASES_DIR" -ForegroundColor Red
    Write-Host "Please run: .\scripts_windows\create_release_packages.ps1 first" -ForegroundColor Yellow
    exit 1
}

Set-Location $RELEASES_DIR

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "GitHub Release Creator" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if gh is installed
if (-not (Test-Path $GH_CLI)) {
    Write-Host "ERROR: GitHub CLI not found at: $GH_CLI" -ForegroundColor Red
    Write-Host "Please install GitHub CLI: winget install GitHub.cli" -ForegroundColor Yellow
    exit 1
}

# Check authentication
Write-Host "Checking GitHub authentication..." -ForegroundColor Yellow
& $GH_CLI auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Not authenticated with GitHub" -ForegroundColor Red
    Write-Host "Please run: gh auth login" -ForegroundColor Yellow
    exit 1
}
Write-Host "Authenticated" -ForegroundColor Green
Write-Host ""

# List files to be released
Write-Host "Files to be released:" -ForegroundColor Yellow
Get-ChildItem -File | Where-Object { $_.Extension -in @('.zip', '.whl') } | ForEach-Object {
    $size = if ($_.Length -gt 1GB) {
        "{0:N2} GB" -f ($_.Length / 1GB)
    } elseif ($_.Length -gt 1MB) {
        "{0:N2} MB" -f ($_.Length / 1MB)
    } else {
        "{0:N2} KB" -f ($_.Length / 1KB)
    }
    Write-Host "  - $($_.Name) ($size)" -ForegroundColor White
}
Write-Host ""

# Confirm with user
$confirmation = Read-Host "Create/overwrite release $RELEASE_TAG? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Release creation cancelled." -ForegroundColor Yellow
    exit 0
}

# Check if release already exists and delete it
Write-Host ""
Write-Host "Checking for existing release..." -ForegroundColor Yellow
& $GH_CLI release view $RELEASE_TAG --repo "lyehe/build_gpu_colmap" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Found existing release. Deleting..." -ForegroundColor Yellow
    & $GH_CLI release delete $RELEASE_TAG --repo "lyehe/build_gpu_colmap" --yes
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Existing release deleted" -ForegroundColor Green
    } else {
        Write-Host "WARNING: Failed to delete existing release" -ForegroundColor Yellow
    }
}

# Create release
Write-Host ""
Write-Host "Creating GitHub release..." -ForegroundColor Yellow
Write-Host "  Tag: $RELEASE_TAG" -ForegroundColor White
Write-Host "  Title: $RELEASE_TITLE" -ForegroundColor White
Write-Host ""

try {
    # Check if RELEASE_NOTES.md exists
    if (-not (Test-Path $RELEASE_NOTES_FILE)) {
        Write-Host "ERROR: Release notes file not found: $RELEASE_NOTES_FILE" -ForegroundColor Red
        exit 1
    }

    # Build list of assets to upload
    $assets = @()

    # Add COLMAP zip if it exists
    $colmapZip = "COLMAP-3.14-dev-Windows-x64-CUDA.zip"
    if (Test-Path $colmapZip) {
        $assets += $colmapZip
    }

    # Add pycolmap wheels
    Get-ChildItem -Filter "pycolmap-*.whl" | ForEach-Object {
        $assets += $_.Name
    }

    if ($assets.Count -eq 0) {
        Write-Host "ERROR: No release assets found" -ForegroundColor Red
        exit 1
    }

    # Create the release with notes from file
    & $GH_CLI release create $RELEASE_TAG `
        --title "$RELEASE_TITLE" `
        --notes-file "$RELEASE_NOTES_FILE" `
        --repo "lyehe/build_gpu_colmap" `
        @assets

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host "Release created successfully!" -ForegroundColor Green
        Write-Host "=====================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "View release at:" -ForegroundColor Cyan
        Write-Host "https://github.com/lyehe/build_gpu_colmap/releases/tag/$RELEASE_TAG" -ForegroundColor White
        Write-Host ""
    } else {
        throw "gh release create failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host ""
    Write-Host "ERROR: Failed to create release" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "You can also create the release manually:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://github.com/lyehe/build_gpu_colmap/releases/new" -ForegroundColor White
    Write-Host "2. Tag: $RELEASE_TAG" -ForegroundColor White
    Write-Host "3. Title: $RELEASE_TITLE" -ForegroundColor White
    Write-Host "4. Copy content from $RELEASE_NOTES_FILE" -ForegroundColor White
    Write-Host "5. Upload the .zip and .whl files from releases/ directory" -ForegroundColor White
    exit 1
}

# Return to original directory
Set-Location $PROJECT_ROOT
