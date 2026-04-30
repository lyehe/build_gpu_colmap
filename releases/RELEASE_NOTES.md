# COLMAP Build v4.1.0-dev0

Pre-built Windows COLMAP binary with CUDA 12.8 and cuDSS support.

## Build

- COLMAP `4.1.0.dev0`
- Upstream commit `976c0dec` from April 29, 2026
- CUDA Toolkit `12.8.93`
- cuDSS `0.7`
- Package: `COLMAP-4.1.0.dev0-Windows-x64-CUDA-cuDSS.zip`

## Verification

```powershell
.\bin\colmap.exe version
```

Expected:

```text
COLMAP 4.1.0.dev0 (Commit 976c0dec on 2026-04-29 with CUDA)
```

SHA256 checksums are in `SHA256SUMS.txt`.

## Notes

- `colmap global_mapper` is the replacement for the standalone GLOMAP workflow.
- This local package includes the Windows COLMAP CUDA/cuDSS build. Matching pycolmap `4.1.0.dev0` wheels were not present in `third_party\colmap-for-pycolmap\wheelhouse` and were not added to this package set.
