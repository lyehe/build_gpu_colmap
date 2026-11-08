================================================================================
                    COLMAP GPU Builder - releases/ directory
================================================================================

Official packages are published through GitHub Releases:

  https://github.com/lyehe/build_gpu_colmap/releases

Release v4.3.0 is a development preview based on upstream COLMAP 4.3.0.dev0,
including FlexGlue, with matching pycolmap wheels for Windows and Linux.
Both source submodules are pinned to f0ddf77c3a1f2a1d15c6798e669872d1025fdc53.
This is a custom preview; upstream 4.3.0 has not been released.
Native COLMAP archives are provided for Ubuntu
22.04 and 24.04. CUDA archives include Caspar GPU bundle adjustment; cuDSS and
GUI variants are supplied where applicable. Every build emits provenance
metadata, and the release workflow publishes SHA256SUMS.txt for all assets.

This directory is a staging area for the optional manual packaging flow:

  scripts_windows/create_release_packages.ps1   # creates local .zip/.whl packages
  scripts_windows/create_github_release.ps1     # uploads staged packages

RELEASE_NOTES.md is the body used by the automated release workflow. The normal
release path is to push the v4.3.0 tag; the workflow creates a draft, uploads
all artifacts, checksums them, and publishes a prerelease only after both build
groups pass. It does not replace the latest stable release.

To verify an extracted archive:

  .\bin\colmap.exe version     # Windows
  ./bin/colmap version          # Linux

================================================================================
