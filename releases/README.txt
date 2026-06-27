================================================================================
                    COLMAP GPU Builder - releases/ directory
================================================================================

Official release packages are published to GitHub Releases:

  https://github.com/lyehe/build_gpu_colmap/releases

The latest release (v4.1.0) provides the official COLMAP 4.1.0 plus matching
pycolmap wheels for Windows and Linux, with CUDA + Caspar GPU bundle adjustment
(and optional cuDSS / GUI variants). Every asset is covered by SHA256SUMS.txt
and ships a build_info.json provenance record.

This directory is a staging area for the optional MANUAL packaging flow:

  scripts_windows/create_release_packages.ps1   # builds local .zip/.whl packages here
  scripts_windows/create_github_release.ps1     # uploads them to a GitHub release

RELEASE_NOTES.md in this directory is published as the GitHub release body by
.github/workflows/release.yml (--notes-file). The automated CI release
(release.yml) generates its own SHA256SUMS.txt as a release asset.

To verify a downloaded COLMAP archive after extracting:

  .\bin\colmap.exe version     # Windows
  ./bin/colmap version         # Linux

================================================================================
