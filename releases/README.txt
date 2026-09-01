================================================================================
                    COLMAP GPU Builder - releases/ directory
================================================================================

Official packages are published through GitHub Releases:

  https://github.com/lyehe/build_gpu_colmap/releases

Build revision v4.2.0-3 packages upstream COLMAP 4.2.0 and matching pycolmap
wheels for Windows and Linux. Native COLMAP archives are provided for Ubuntu
22.04 and 24.04. CUDA archives include Caspar GPU bundle adjustment; cuDSS and
GUI variants are supplied where applicable. Every build emits provenance
metadata, and the release workflow publishes SHA256SUMS.txt for all assets.

This directory is a staging area for the optional manual packaging flow:

  scripts_windows/create_release_packages.ps1   # creates local .zip/.whl packages
  scripts_windows/create_github_release.ps1     # uploads staged packages

RELEASE_NOTES.md is the body used by the automated release workflow. The normal
release path is to push the v4.2.0-3 tag; the workflow creates a draft, uploads
all artifacts, checksums them, and publishes only after both build groups pass.

To verify an extracted archive:

  .\bin\colmap.exe version     # Windows
  ./bin/colmap version          # Linux

================================================================================
