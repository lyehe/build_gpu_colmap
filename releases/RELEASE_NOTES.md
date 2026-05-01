# COLMAP Build v4.1.0-dev0

Development snapshot of COLMAP and pycolmap built from upstream COLMAP
`4.1.0.dev0` at commit `976c0dec` from April 29, 2026.

This release updates the previous `v4.0.2` package set with newer COLMAP,
pycolmap, CUDA build plumbing, and release automation. Use `v4.0.2` if you need
a stable COLMAP release tag rather than a development snapshot.

## Highlights

- COLMAP updated from `4.0.2` to `4.1.0.dev0`.
- pycolmap wheels updated to `4.1.0.dev0` for Python `3.10` through `3.14`.
- Full package matrix is available: 8 COLMAP archives, 55 pycolmap wheels, and
  `SHA256SUMS.txt`.
- Windows and Linux COLMAP packages are versioned in the asset names.
- Windows GUI packages include the Qt SVG dependency required by current COLMAP.
- CUDA build configuration now passes the selected CUDA compiler and toolkit
  root through Ceres, COLMAP, and COLMAP-for-pycolmap.

## Upstream COLMAP Changes Since v4.0.2

- Added `colmap version` for easier binary verification.
- Fixed empty PatchMatch results on Blackwell-class GPUs.
- Improved global mapping:
  - inherited bundle adjustment options in the global mapper
  - added rotation averaging options
  - fixed crashes and bookkeeping issues around global/incremental mapping
- Improved exhaustive matching performance by switching FAISS usage to
  `IndexIVFScalarQuantizer`.
- Improved benchmark tooling with fast mode, live progress, better parallelism,
  per-step logging, and summary rows.
- Improved pycolmap bindings and reliability:
  - added `ReprojectionErrorType` bindings and additional point filter methods
  - fixed ALIKED feature extraction through pycolmap
  - fixed `pyceres.problem` on bundle adjuster factory results
  - added broader pycolmap smoke tests upstream
- Updated upstream dependencies including ONNX Runtime `1.24.4`, PoseLib
  `2.0.5`, and pybind11 `3.0.2`.
- Added and fixed camera/model, MVS, PoissonRecon, EXIF, locale parsing,
  observation graph, and hierarchical mapper behavior from upstream COLMAP.
- GUI updates include Material Symbols icons and viewer camera up-vector display.

## Package Matrix

### COLMAP Archives

| Platform | Variants |
| --- | --- |
| Ubuntu 22.04 | `CPU`, `CUDA`, `CUDA-cuDSS` |
| Windows | `CPU`, `CUDA`, `CUDA-cuDSS`, `CUDA-GUI`, `CUDA-cuDSS-GUI` |

### pycolmap Wheels

- Python versions: `3.10`, `3.11`, `3.12`, `3.13`, `3.14`.
- Platforms: Windows `win_amd64` and Linux `manylinux_2_35_x86_64`.
- CPU wheels for both Windows and Linux.
- CUDA wheels for Windows and Linux.
- Windows CUDA + cuDSS wheels.
- Linux bundled CUDA runtime wheels for CUDA `12.8`, `13.0`, and `13.1`,
  including cuDSS variants.

## Installation

### COLMAP

Windows:

```powershell
Expand-Archive COLMAP-4.1.0.dev0-windows-latest-CUDA-GUI.zip -DestinationPath C:\Tools\COLMAP
C:\Tools\COLMAP\bin\colmap.exe gui
```

Linux:

```bash
unzip COLMAP-4.1.0.dev0-ubuntu-22.04-CUDA.zip -d ~/tools/colmap
~/tools/colmap/bin/colmap version
```

### pycolmap

Download the wheel matching your Python version, platform, and CUDA/runtime
needs, then install it directly:

```bash
pip install pycolmap-4.1.0.dev0+cuda-cp312-cp312-win_amd64.whl
```

## Runtime Notes

- CPU packages do not require an NVIDIA GPU.
- CUDA packages require an NVIDIA driver compatible with the CUDA runtime in the
  selected asset.
- Windows CUDA COLMAP packages bundle the required CUDA runtime DLLs.
- Linux COLMAP CUDA archives expect compatible NVIDIA runtime support on the
  host system.
- Linux `pycolmap` wheels with `.bundled` in the filename include CUDA runtime
  libraries inside the wheel.
- `CUDA-cuDSS` variants include cuDSS sparse solver support for supported
  bundle adjustment workloads.

## Build And Release Changes

- Restored push-triggered auto builds for COLMAP and pycolmap workflow changes.
- Added versioned COLMAP artifact names based on `colmap version`.
- Improved Windows CUDA DLL discovery and bundling across CUDA install paths.
- Fixed pycolmap workflow dependency resolution for upstream pybind11 `3.0.2`.
- Added Qt SVG to the Qt6 GUI dependency set.
- Fixed Qt deployment handling so a benign `windeployqt` warning does not fail
  the job after the required `qwindows.dll` platform plugin is verified.
- Regenerated checksums for all release assets.

## Verification

Check the COLMAP binary version:

```powershell
.\bin\colmap.exe version
```

Expected version:

```text
COLMAP 4.1.0.dev0 (Commit 976c0dec on 2026-04-29 with CUDA)
```

All release assets are covered by `SHA256SUMS.txt`.
