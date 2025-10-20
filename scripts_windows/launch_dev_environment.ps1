# Helper script to launch Visual Studio Developer PowerShell
# Usage: .\launch_dev_environment.ps1 [-Command "script.ps1"]

[CmdletBinding()]
param(
    [string]$Command = "",
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage: .\launch_dev_environment.ps1 [options]

This script launches a new Visual Studio Developer PowerShell environment.

Options:
  -Command <script>   Optional script or command to run in the dev environment
  -Help               Show this help message

Examples:
  .\launch_dev_environment.ps1
  .\launch_dev_environment.ps1 -Command ".\scripts_windows\build.ps1"
  .\launch_dev_environment.ps1 -Command ".\scripts_windows\verify_build_environment.ps1"
"@
    exit 0
}

$ErrorActionPreference = 'Stop'

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Visual Studio Developer Environment Launcher" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Find Visual Studio installation using vswhere
$VSWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Test-Path $VSWherePath)) {
    Write-Host "ERROR: vswhere.exe not found. Visual Studio may not be installed." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install Visual Studio 2019 or later from:" -ForegroundColor Yellow
    Write-Host "  https://visualstudio.microsoft.com/downloads/" -ForegroundColor White
    Write-Host ""
    Write-Host "Make sure to install the 'Desktop development with C++' workload." -ForegroundColor Yellow
    exit 1
}

Write-Host "Locating Visual Studio installation..." -ForegroundColor Yellow

try {
    # Try to find full Visual Studio IDE first
    $VSIDEPath = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.Community,Microsoft.VisualStudio.Product.Professional,Microsoft.VisualStudio.Product.Enterprise -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null

    # Then try Build Tools
    $VSBuildToolsPath = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.BuildTools -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null

    # Use whichever is found (prefer IDE if both exist)
    if ($VSIDEPath) {
        $VSInstallPath = $VSIDEPath
        $VSType = "IDE"
    } elseif ($VSBuildToolsPath) {
        $VSInstallPath = $VSBuildToolsPath
        $VSType = "BuildTools"
    } else {
        # Last resort: search all products
        $VSInstallPath = & $VSWherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        $VSType = "Unknown"
    }

    if (-not $VSInstallPath) {
        Write-Host "ERROR: No Visual Studio or Build Tools installation found with C++ support." -ForegroundColor Red
        Write-Host ""
        Write-Host "You need ONE of the following:" -ForegroundColor Yellow
        Write-Host "  1. Visual Studio 2019/2022 (Community/Professional/Enterprise)" -ForegroundColor White
        Write-Host "     Download from: https://visualstudio.microsoft.com/downloads/" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  2. Visual Studio Build Tools 2019/2022" -ForegroundColor White
        Write-Host "     Download from: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "During installation, make sure to select:" -ForegroundColor Yellow
        Write-Host "  - 'Desktop development with C++' workload" -ForegroundColor White
        Write-Host "  - MSVC v142/v143 compiler" -ForegroundColor White
        Write-Host "  - Windows SDK" -ForegroundColor White
        Write-Host ""
        exit 1
    }

    # Get product details
    $VSVersion = $null
    $VSProductName = $null

    if ($VSType -eq "IDE") {
        $VSVersion = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.Community,Microsoft.VisualStudio.Product.Professional,Microsoft.VisualStudio.Product.Enterprise -property catalog_productDisplayVersion 2>$null
        $VSProductName = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.Community,Microsoft.VisualStudio.Product.Professional,Microsoft.VisualStudio.Product.Enterprise -property displayName 2>$null
    } elseif ($VSType -eq "BuildTools") {
        $VSVersion = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.BuildTools -property catalog_productDisplayVersion 2>$null
        $VSProductName = & $VSWherePath -latest -products Microsoft.VisualStudio.Product.BuildTools -property displayName 2>$null
    } else {
        $VSVersion = & $VSWherePath -latest -products * -property catalog_productDisplayVersion 2>$null
        $VSProductName = & $VSWherePath -latest -products * -property displayName 2>$null
    }

    if (-not $VSProductName) {
        $VSProductName = "Visual Studio"
    }

    Write-Host "Found: $VSProductName $VSVersion" -ForegroundColor Green
    Write-Host "Type: $VSType" -ForegroundColor Gray
    Write-Host "Path: $VSInstallPath" -ForegroundColor Gray
    Write-Host ""

    # Find the Developer PowerShell module
    $VSDevShellScript = Join-Path $VSInstallPath "Common7\Tools\Launch-VsDevShell.ps1"

    if (-not (Test-Path $VSDevShellScript)) {
        Write-Host "ERROR: Developer environment script not found." -ForegroundColor Red
        Write-Host "Expected location: $VSDevShellScript" -ForegroundColor Gray
        Write-Host ""
        Write-Host "This may indicate an incomplete Visual Studio installation." -ForegroundColor Yellow
        Write-Host "Try repairing or reinstalling Visual Studio with the 'Desktop development with C++' workload." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Launching Developer PowerShell..." -ForegroundColor Cyan
    Write-Host ""

    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ProjectRoot = Split-Path -Parent $ScriptDir

    # Create a script to run in the new shell
    $TempScript = Join-Path $env:TEMP "launch_devshell_$(Get-Random).ps1"

    $ScriptContent = @"
# Set window title
`$Host.UI.RawUI.WindowTitle = 'Visual Studio Developer PowerShell'

# Import Visual Studio Developer Environment
Write-Host 'Initializing Visual Studio Developer Environment...' -ForegroundColor Cyan
& '$VSDevShellScript' -Arch amd64 -HostArch amd64

# Change to project directory
Set-Location '$ProjectRoot'

Write-Host ''
Write-Host '================================================================' -ForegroundColor Green
Write-Host 'Visual Studio Developer PowerShell Ready!' -ForegroundColor Green
Write-Host '================================================================' -ForegroundColor Green
Write-Host ''
Write-Host 'Project Directory: $ProjectRoot' -ForegroundColor Cyan
Write-Host 'MSVC Compiler: ' -NoNewline -ForegroundColor Cyan
`$clPath = (Get-Command cl.exe -ErrorAction SilentlyContinue).Source
if (`$clPath) {
    Write-Host 'Available' -ForegroundColor Green
} else {
    Write-Host 'Not Found' -ForegroundColor Red
}
Write-Host ''
Write-Host 'Useful Commands:' -ForegroundColor Yellow
Write-Host '  .\scripts_windows\verify_build_environment.ps1  - Verify build tools' -ForegroundColor White
Write-Host '  .\scripts_windows\build.ps1                     - Build the project' -ForegroundColor White
Write-Host '  .\scripts_windows\bootstrap.ps1                 - Bootstrap vcpkg' -ForegroundColor White
Write-Host ''
"@

    if ($Command -ne "") {
        $ScriptContent += @"

Write-Host 'Executing command: $Command' -ForegroundColor Cyan
Write-Host ''
& $Command

Write-Host ''
Write-Host 'Press any key to exit...' -ForegroundColor Cyan
`$null = `$Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
"@
    }

    $ScriptContent | Out-File -FilePath $TempScript -Encoding UTF8

    # Launch new PowerShell window with the script
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoExit -File `"$TempScript`""

    Write-Host "Developer PowerShell launched in a new window!" -ForegroundColor Green
    Write-Host ""

    if ($Command -eq "") {
        Write-Host "The new window is ready for development." -ForegroundColor Gray
        Write-Host "You can now run build scripts with MSVC compiler available." -ForegroundColor Gray
    } else {
        Write-Host "Running command: $Command" -ForegroundColor Gray
    }

    Write-Host ""

} catch {
    Write-Host "ERROR: Failed to launch Developer PowerShell" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
