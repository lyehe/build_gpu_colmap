# COLMAP Build v4.1.0

GPU-accelerated builds of the official **COLMAP 4.1.0** release for Windows and
Linux, plus matching pycolmap wheels. The CUDA archives include **Caspar GPU
bundle adjustment**.

This is a stable release: the COLMAP source is byte-identical to the upstream
`4.1.0` tag (commit `fa8e3b3f`) and stamped as `4.1.0`. Every artifact carries a
`build_info.json` provenance record (commit, toolchain, CUDA/cuDSS versions,
feature flags).

## What's new in COLMAP 4.1.0

- **Spherical camera support** — new `EQUIRECTANGULAR` (360° panorama) camera
  model, plus a `panorama_sfm` pipeline with global mapping.
- **Caspar GPU bundle adjustment** — selectable backend for large-scale BA.
- Additional wide-FOV / omnidirectional camera models: `FISHEYE`,
  `SIMPLE_FISHEYE`, `EUCM`, `DIVISION`, `RAD_TAN_THIN_PRISM_FISHEYE`.
- Two-focal `p4pf` estimation (separate `fx`/`fy`).
- pycolmap exposes the Caspar API: `BundleAdjustmentBackend.CASPAR`,
  `BundleAdjustmentOptions.caspar`, and `CasparBundleAdjustmentOptions`.

See the upstream COLMAP 4.1.0 changelog for the complete list.

## Package matrix

### COLMAP archives (8)

| Platform | Variants |
| --- | --- |
| Ubuntu 22.04 | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar` |
| Windows | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar`, `CUDA-Caspar-GUI`, `CUDA-cuDSS-Caspar-GUI` |

### pycolmap wheels (55)

- Python `3.10`, `3.11`, `3.12`, `3.13`, `3.14`.
- Windows `win_amd64` and Linux `manylinux_2_35_x86_64`.
- CPU and CUDA wheels for both platforms; Windows CUDA + cuDSS wheels.
- Linux bundled-CUDA-runtime wheels for CUDA `12.8`, `13.0`, and `13.1`,
  including cuDSS variants.

Every artifact ships a `*.build_info.json` provenance sidecar, and a
`SHA256SUMS.txt` covers the full asset set.

## Installation

### COLMAP

Windows:

```powershell
Expand-Archive COLMAP-4.1.0-windows-2022-CUDA-Caspar.zip -DestinationPath C:\Tools\COLMAP
C:\Tools\COLMAP\bin\colmap.exe version
```

Linux:

```bash
unzip COLMAP-4.1.0-ubuntu-22.04-CUDA-Caspar.zip -d ~/tools/colmap
~/tools/colmap/bin/colmap version
```

### pycolmap

Download the wheel matching your Python version, platform, and CUDA/runtime
needs, then install it directly:

```bash
pip install pycolmap-4.1.0+cuda-cp312-cp312-win_amd64.whl
```

## Caspar bundle adjustment

Caspar GPU bundle adjustment is selected with `--BundleAdjustment.backend CASPAR`
in the `colmap bundle_adjuster` command, and through
`pycolmap.BundleAdjustmentBackend.CASPAR` in the CUDA wheels:

```python
import pycolmap

assert pycolmap.BundleAdjustmentBackend.CASPAR == pycolmap.BundleAdjustmentBackend("CASPAR")
opts = pycolmap.BundleAdjustmentOptions()
opts.backend = pycolmap.BundleAdjustmentBackend.CASPAR
opts.caspar.gpu_index = "0"
```

A deterministic validation script is included in the repository:

```bash
python scripts/validate_caspar_sample.py --colmap /path/to/colmap --require-pycolmap
```

It generates a COLMAP text model, runs `colmap bundle_adjuster
--BundleAdjustment.backend CASPAR`, and asserts that reprojection error improves.

## Runtime notes

- CPU packages do not require an NVIDIA GPU.
- CUDA packages require an NVIDIA driver compatible with the CUDA runtime in the
  selected asset.
- Windows CUDA COLMAP packages bundle the required CUDA runtime DLLs.
- Linux COLMAP CUDA archives expect compatible NVIDIA runtime support on the host.
- Linux `pycolmap` wheels with `.bundled` in the filename include CUDA runtime
  libraries inside the wheel.
- `CUDA-cuDSS` variants add cuDSS sparse-solver support for Ceres bundle
  adjustment.
