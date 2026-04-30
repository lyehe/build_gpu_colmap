================================================================================
                    COLMAP GPU Builder - Release Package
================================================================================

This directory contains packaged builds ready for release.

CURRENT LOCAL PACKAGE
---------------------

COLMAP-4.1.0.dev0-Windows-x64-CUDA-cuDSS.zip
  - COLMAP 4.1.0.dev0
  - Upstream commit 976c0dec from 2026-04-29
  - Windows x64
  - CUDA 12.8 + cuDSS 0.7
  - SHA256 listed in SHA256SUMS.txt

VERIFY
------

After extracting:

  .\bin\colmap.exe version

Expected:

  COLMAP 4.1.0.dev0 (Commit 976c0dec on 2026-04-29 with CUDA)

NOTES
-----

- Use `colmap global_mapper` for global Structure-from-Motion.
- Matching pycolmap 4.1.0.dev0 wheels were not present when this package was
  created. Build them separately with:

  .\scripts_windows\build_pycolmap_wheels.ps1

================================================================================
