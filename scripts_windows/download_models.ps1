# Download ALIKED and LightGlue ONNX models for COLMAP
# Models are cached in ~/.cache/colmap/ (same location COLMAP uses)
#
# Usage: .\download_models.ps1 [-CacheDir DIR]

param(
    [string]$CacheDir = "",
    [switch]$Help
)

if ($Help) {
    Write-Host "Download ALIKED and LightGlue ONNX models for COLMAP"
    Write-Host ""
    Write-Host "Usage: .\download_models.ps1 [-CacheDir DIR]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -CacheDir DIR    Cache directory (default: ~/.cache/colmap)"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Host "Models downloaded:"
    Write-Host "  - aliked-n16rot.onnx      ALIKED N16ROT feature extractor"
    Write-Host "  - aliked-n32.onnx         ALIKED N32 feature extractor"
    Write-Host "  - aliked-lightglue.onnx   ALIKED LightGlue feature matcher"
    Write-Host "  - bruteforce-matcher.onnx Brute-force ONNX matcher"
    exit 0
}

# Default cache directory (matches COLMAP's default)
if (-not $CacheDir) {
    $CacheDir = Join-Path $env:USERPROFILE ".cache\colmap"
}

$BaseUrl = "https://github.com/colmap/colmap/releases/download/3.13.0"

# Model definitions
$Models = @(
    @{
        Filename = "aliked-n16rot.onnx"
        SHA256   = "39c423d0a6f03d39ec89d3d1d61853765c2fb6a8b8381376c703e5758778a547"
    },
    @{
        Filename = "aliked-n32.onnx"
        SHA256   = "a077728a02d2de1a775c66df6de8cfeb7c6b51ca57572c64c680131c988c8b3c"
    },
    @{
        Filename = "aliked-lightglue.onnx"
        SHA256   = "b9a5de7204648b18a8cf5dcac819f9d30de1a5961ef03756803c8b86c2dceb8d"
    },
    @{
        Filename = "bruteforce-matcher.onnx"
        SHA256   = "3c1282f96d83f5ffc861a873298d08bbe5219f59af59223f5ceab5c41a182a47"
    }
)

Write-Host "Download COLMAP ONNX Models" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host "Cache directory: $CacheDir"
Write-Host ""

if (-not (Test-Path $CacheDir)) {
    New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
}

$Downloaded = 0
$Skipped = 0
$Failed = 0

foreach ($model in $Models) {
    $Filename = $model.Filename
    $ExpectedHash = $model.SHA256
    $CachedFile = Join-Path $CacheDir "${ExpectedHash}-${Filename}"

    Write-Host -NoNewline "  ${Filename}... "

    # Check if already cached with correct hash
    if (Test-Path $CachedFile) {
        $ActualHash = (Get-FileHash -Path $CachedFile -Algorithm SHA256).Hash.ToLower()
        if ($ActualHash -eq $ExpectedHash) {
            Write-Host "already cached" -ForegroundColor Green
            $Skipped++
            continue
        } else {
            Write-Host "cached file corrupted, re-downloading" -ForegroundColor Yellow
            Remove-Item -Force $CachedFile
        }
    }

    # Download
    Write-Host "downloading..." -ForegroundColor DarkGray
    $Url = "${BaseUrl}/${Filename}"

    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $CachedFile -UseBasicParsing

        # Verify checksum
        $ActualHash = (Get-FileHash -Path $CachedFile -Algorithm SHA256).Hash.ToLower()
        if ($ActualHash -eq $ExpectedHash) {
            $Size = [math]::Round((Get-Item $CachedFile).Length / 1MB, 1)
            Write-Host "  OK (${Size} MB)" -ForegroundColor Green
            $Downloaded++
        } else {
            Write-Host "  FAILED: checksum mismatch" -ForegroundColor Red
            Write-Host "  Expected: $ExpectedHash" -ForegroundColor DarkGray
            Write-Host "  Got:      $ActualHash" -ForegroundColor DarkGray
            Remove-Item -Force $CachedFile
            $Failed++
        }
    } catch {
        Write-Host "  FAILED: $_" -ForegroundColor Red
        if (Test-Path $CachedFile) { Remove-Item -Force $CachedFile }
        $Failed++
    }
}

Write-Host ""
Write-Host "================================================================"
Write-Host -NoNewline "Downloaded: "
Write-Host -NoNewline $Downloaded -ForegroundColor Green
Write-Host -NoNewline "  Cached: "
Write-Host -NoNewline $Skipped -ForegroundColor Cyan
Write-Host -NoNewline "  Failed: "
Write-Host $Failed -ForegroundColor Red

if ($Failed -gt 0) {
    Write-Host "Some downloads failed. Check your internet connection." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All models ready!" -ForegroundColor Green
Write-Host "COLMAP will automatically find them in $CacheDir" -ForegroundColor DarkGray
Write-Host "================================================================"
