# cuDSS Manual Installation Script
# Run as Administrator

param(
    [Parameter(Mandatory=$true)]
    [string]$CudssExtractPath  # Path to extracted cuDSS archive
)

$ErrorActionPreference = 'Stop'

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "cuDSS Manual Installation Script" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Detect CUDA installation
$CudaPath = $env:CUDA_PATH
if (-not $CudaPath) {
    $CudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
}

Write-Host "CUDA Path: $CudaPath" -ForegroundColor White
Write-Host "cuDSS Extract Path: $CudssExtractPath" -ForegroundColor White
Write-Host ""

# Verify paths exist
if (-not (Test-Path $CudssExtractPath)) {
    Write-Error "cuDSS extract path not found: $CudssExtractPath"
}

if (-not (Test-Path $CudaPath)) {
    Write-Error "CUDA installation not found: $CudaPath"
}

# Determine CUDA major version
$CudaMajorVersion = "12"  # For CUDA 12.x

Write-Host "Step 1: Copying header files..." -ForegroundColor Yellow
$IncludeSrc = Join-Path $CudssExtractPath "include"
$IncludeDst = Join-Path $CudaPath "include"

if (Test-Path $IncludeSrc) {
    Copy-Item "$IncludeSrc\*" $IncludeDst -Force -Recurse
    Write-Host "[OK] Headers copied" -ForegroundColor Green
} else {
    Write-Error "Include directory not found: $IncludeSrc"
}

Write-Host ""
Write-Host "Step 2: Copying library files..." -ForegroundColor Yellow
$LibSrc = Join-Path $CudssExtractPath "lib\$CudaMajorVersion"
$LibDst = Join-Path $CudaPath "lib\x64"

if (Test-Path $LibSrc) {
    Copy-Item "$LibSrc\*" $LibDst -Force -Recurse
    Write-Host "[OK] Libraries copied" -ForegroundColor Green
} else {
    Write-Error "Library directory not found: $LibSrc"
}

Write-Host ""
Write-Host "Step 3: Copying DLL files..." -ForegroundColor Yellow
$BinSrc = Join-Path $CudssExtractPath "bin"
$BinDst = Join-Path $CudaPath "bin"

if (Test-Path $BinSrc) {
    Copy-Item "$BinSrc\*" $BinDst -Force -Recurse
    Write-Host "[OK] DLLs copied" -ForegroundColor Green
} else {
    Write-Warning "Bin directory not found: $BinSrc (may not be included in archive)"
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "cuDSS installation complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Verification:" -ForegroundColor Cyan
Write-Host "  cudss.h: " -NoNewline
if (Test-Path (Join-Path $IncludeDst "cudss.h")) {
    Write-Host "[OK]" -ForegroundColor Green
} else {
    Write-Host "[MISSING]" -ForegroundColor Red
}

Write-Host "  cudss.lib: " -NoNewline
if (Test-Path (Join-Path $LibDst "cudss.lib")) {
    Write-Host "[OK]" -ForegroundColor Green
} else {
    Write-Host "[MISSING]" -ForegroundColor Red
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Close and reopen PowerShell/terminals to refresh environment" -ForegroundColor White
Write-Host "2. Rebuild project: .\scripts_windows\build.ps1 -Clean -Configuration Release" -ForegroundColor White
