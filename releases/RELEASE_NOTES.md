# COLMAP Build v4.1.0-dev2

Replacement prerelease for the obsolete `v4.1.0-dev1` asset set. This build is
stamped as `4.1.0.dev2` and keeps the full bundled COLMAP and pycolmap matrix,
with Caspar bundle-adjustment support included in the CUDA/Caspar variants.

Use this prerelease when you need the current COLMAP development build with
bundled CUDA runtime packages. Use `v4.0.2` if you need a stable COLMAP release
tag rather than a development snapshot.

## Highlights

- COLMAP and pycolmap are stamped as `4.1.0.dev2`.
- Full package matrix is available: 8 COLMAP archives, 55 pycolmap wheels, and
  `SHA256SUMS.txt`.
- CUDA COLMAP archives include Caspar-enabled bundle-adjustment variants.
- Windows CUDA packages are self-contained with bundled CUDA runtime DLLs.
- Linux bundled pycolmap wheels are available for CUDA `12.8`, `13.0`, and
  `13.1`, including cuDSS variants.
- pycolmap wheels now expose the Caspar bundle-adjustment API:
  `BundleAdjustmentBackend.CASPAR`, `BundleAdjustmentOptions.caspar`, and
  `CasparBundleAdjustmentOptions`.
- The pycolmap CI smoke test now fails if the Caspar Python API is missing.
- Added a deterministic Caspar sample validation script for release binaries.
- PyPI publishing has been removed from this repository; releases publish GitHub
  assets only.

## Changes Since v4.1.0-dev1

- Fixed the pycolmap Caspar binding gap. The previous prerelease contained
  Caspar-enabled native code, but Python only exposed the Ceres backend.
- Added repo-owned patching for the pycolmap submodule so GitHub Actions and
  local wheel builds apply the same Caspar binding fix without dirtying the
  upstream submodule pointer.
- Added Windows and Linux build-script guards that treat the pycolmap Caspar
  patch as idempotent.
- Added CI assertions for:
  - `pycolmap.BundleAdjustmentBackend.CASPAR`
  - string construction from `"CASPAR"`
  - `BundleAdjustmentOptions.caspar`
  - `CasparBundleAdjustmentOptions`
- Added `scripts/validate_caspar_sample.py` to generate a deterministic COLMAP
  text model, run `colmap bundle_adjuster --BundleAdjustment.backend CASPAR`,
  verify output model files, and assert reprojection error improves.

## Package Matrix

### COLMAP Archives

| Platform | Variants |
| --- | --- |
| Ubuntu 22.04 | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar` |
| Windows | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar`, `CUDA-Caspar-GUI`, `CUDA-cuDSS-Caspar-GUI` |

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
Expand-Archive COLMAP-4.1.0.dev2-windows-latest-CUDA-Caspar.zip -DestinationPath C:\Tools\COLMAP
C:\Tools\COLMAP\bin\colmap.exe version
```

Linux:

```bash
unzip COLMAP-4.1.0.dev2-ubuntu-22.04-CUDA-Caspar.zip -d ~/tools/colmap
~/tools/colmap/bin/colmap version
```

### pycolmap

Download the wheel matching your Python version, platform, and CUDA/runtime
needs, then install it directly:

```bash
pip install pycolmap-4.1.0.dev2+cuda-cp312-cp312-win_amd64.whl
```

## Validation

Check the COLMAP binary version:

```powershell
.\bin\colmap.exe version
```

Expected output includes:

```text
COLMAP 4.1.0.dev2
```

Validate the CLI Caspar backend on a deterministic sample:

```bash
python scripts/validate_caspar_sample.py --colmap /path/to/colmap
```

Validate both the CLI Caspar backend and a rebuilt pycolmap wheel:

```bash
python scripts/validate_caspar_sample.py --colmap /path/to/colmap --require-pycolmap
```

Verify pycolmap exposes the Caspar API:

```python
import pycolmap

assert pycolmap.BundleAdjustmentBackend.CASPAR == pycolmap.BundleAdjustmentBackend("CASPAR")
opts = pycolmap.BundleAdjustmentOptions()
opts.backend = pycolmap.BundleAdjustmentBackend.CASPAR
opts.caspar.gpu_index = "0"
```

## Binary Tested

Representative published Windows assets were downloaded from GitHub Releases and
validated on May 15, 2026:

- `COLMAP-4.1.0.dev2-windows-latest-CUDA-Caspar.zip`
- `pycolmap-4.1.0.dev2+cuda-cp311-cp311-win_amd64.whl`

Checksums matched `SHA256SUMS.txt`.

Validated results:

- `colmap.exe version` reported
  `COLMAP 4.1.0.dev2 (Commit 6cfbc04 on 2026-05-10 with CUDA)`.
- CLI Caspar sample improved mean reprojection error from `1.000000px` to
  `0.065280px`.
- pycolmap Caspar sample improved mean reprojection error from `1.000000px` to
  `0.065281px`.
- The pycolmap wheel metadata reported `4.1.0.dev2`; the Python module reported
  COLMAP `4.1.0.dev2`, CUDA enabled, one CUDA device, and
  `BundleAdjustmentBackend.CASPAR` plus `BundleAdjustmentOptions.caspar`.

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
  Ceres bundle-adjustment workloads.
- Caspar bundle adjustment is selected with
  `--BundleAdjustment.backend CASPAR` in the `colmap bundle_adjuster` command
  and through `pycolmap.BundleAdjustmentBackend.CASPAR` in rebuilt wheels.
