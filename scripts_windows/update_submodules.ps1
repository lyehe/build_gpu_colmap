# Update all git submodules to their latest versions
# Usage: .\update_submodules.ps1 [-All] [-Vcpkg] [-Colmap] [-Glomap] [-Ceres] [-Pyceres] [-Poselib]

[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Vcpkg,
    [switch]$Colmap,
    [switch]$Glomap,
    [switch]$Ceres,
    [switch]$Pyceres,
    [switch]$Poselib,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage: .\update_submodules.ps1 [options]

Options:
  -All            Update all submodules (default if no options specified)
  -Vcpkg          Update only vcpkg
  -Colmap         Update only COLMAP
  -Glomap         Update only GLOMAP
  -Ceres          Update only Ceres Solver
  -Pyceres        Update only PyCeres
  -Poselib        Update only PoseLib
  -Help           Show this help message

Examples:
  .\update_submodules.ps1                          Update all submodules
  .\update_submodules.ps1 -Colmap -Glomap          Update only COLMAP and GLOMAP
  .\update_submodules.ps1 -Vcpkg                   Update only vcpkg
"@
    exit 0
}

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Git Submodules Update Script" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

Push-Location $ProjectRoot
try {
    # If no specific submodule is specified, update all
    if (-not ($Vcpkg -or $Colmap -or $Glomap -or $Ceres -or $Pyceres -or $Poselib)) {
        $All = $true
    }

    if ($All) {
        Write-Host "Updating all submodules..." -ForegroundColor Yellow
        Write-Host ""
        git submodule update --remote --merge

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to update submodules"
        }

        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host "All submodules updated successfully!" -ForegroundColor Green
        Write-Host "================================================================" -ForegroundColor Green
    } else {
        # Update individual submodules
        $submodules = @(
            @{Flag=$Vcpkg; Name="vcpkg"; Path="third_party/vcpkg"; Branch="master"},
            @{Flag=$Colmap; Name="COLMAP"; Path="third_party/colmap"; Branch="main"},
            @{Flag=$Glomap; Name="GLOMAP"; Path="third_party/glomap"; Branch="main"},
            @{Flag=$Ceres; Name="Ceres Solver"; Path="third_party/ceres-solver"; Branch="master"},
            @{Flag=$Pyceres; Name="PyCeres"; Path="third_party/pyceres"; Branch="main"},
            @{Flag=$Poselib; Name="PoseLib"; Path="third_party/poselib"; Branch="master"}
        )

        foreach ($submodule in $submodules) {
            if ($submodule.Flag) {
                Write-Host "Updating $($submodule.Name)..." -ForegroundColor Yellow
                Push-Location $submodule.Path
                try {
                    git checkout $submodule.Branch
                    git pull
                } finally {
                    Pop-Location
                }
                git add $submodule.Path
                Write-Host "$($submodule.Name) updated" -ForegroundColor Green
                Write-Host ""
            }
        }

        Write-Host "================================================================" -ForegroundColor Green
        Write-Host "Selected submodules updated successfully!" -ForegroundColor Green
        Write-Host "================================================================" -ForegroundColor Green
    }

    # Show current status
    Write-Host ""
    Write-Host "Current submodule status:" -ForegroundColor Cyan
    git submodule status

    Write-Host ""
    Write-Host "To commit these changes, run:" -ForegroundColor Yellow
    Write-Host '  git commit -m "Update submodules"' -ForegroundColor White
    Write-Host ""

} finally {
    Pop-Location
}
