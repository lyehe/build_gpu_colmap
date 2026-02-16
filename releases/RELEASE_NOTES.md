# COLMAP Build v3.14.0-dev1

Pre-built Windows/Linux COLMAP binaries and pycolmap Python wheels with CUDA 12.8 support.

## Important: NVIDIA Driver 570+ Required

CUDA 12.8 binaries require **NVIDIA Driver 570 or later**. Check with `nvidia-smi`.

## Highlights

- **ONNX support enabled** — LightGlue and ALIKED learned feature matching/detection
- **COLMAP updated to latest** (`a6f539d4`) — pycolmap.match_from_pairs, improved mapper/triangulator bindings
- **Global SfM built-in** — Use `colmap global_mapper` (previously standalone GLOMAP)
- **Cross-platform** — 8 COLMAP packages + 25 pycolmap wheels (Windows & Linux, CPU/CUDA/cuDSS)
- **Python 3.10–3.14** support

## What's Included

### COLMAP Packages (8 variants)

| Package | Platform | GPU | GUI |
|---------|----------|-----|-----|
| `COLMAP-windows-latest-CPU` | Windows | — | — |
| `COLMAP-windows-latest-CUDA` | Windows | CUDA 12.8 | — |
| `COLMAP-windows-latest-CUDA-GUI` | Windows | CUDA 12.8 | Qt GUI |
| `COLMAP-windows-latest-CUDA-cuDSS` | Windows | CUDA 12.8 + cuDSS | — |
| `COLMAP-windows-latest-CUDA-cuDSS-GUI` | Windows | CUDA 12.8 + cuDSS | Qt GUI |
| `COLMAP-ubuntu-22.04-CPU` | Linux | — | — |
| `COLMAP-ubuntu-22.04-CUDA` | Linux | CUDA 12.8 | — |
| `COLMAP-ubuntu-22.04-CUDA-cuDSS` | Linux | CUDA 12.8 + cuDSS | — |

### pycolmap Wheels (25 variants)

Python 3.10–3.14 for Windows and Linux, in CPU / CUDA / CUDA+cuDSS variants.

```bash
pip install pycolmap-3.14.0.dev0+cuda-cp312-cp312-win_amd64.whl
```

| Variant suffix | Description |
|----------------|-------------|
| `+cpu` | CPU-only (no NVIDIA GPU required) |
| `+cuda` | CUDA 12.8 GPU acceleration |
| `+cuda.cudss` | CUDA 12.8 + cuDSS sparse solver (fastest bundle adjustment) |

## Quick Start

**COLMAP (Windows):**
```powershell
Expand-Archive COLMAP-windows-latest-CUDA.zip -DestinationPath C:\Tools\COLMAP
C:\Tools\COLMAP\bin\colmap.exe gui
```

**COLMAP (Linux):**
```bash
unzip COLMAP-ubuntu-22.04-CUDA.zip -d ~/tools/colmap
~/tools/colmap/bin/colmap gui
```

**Global SfM (previously GLOMAP):**
```bash
colmap global_mapper --database_path db.db --image_path images --output_path sparse
```

**pycolmap:**
```python
import pycolmap
pycolmap.extract_features(image_path="images/", database_path="database.db")
```

## COLMAP Changes (since v2.3.0 / v3.14.0-dev0)

### New
- **ONNX support enabled** — LightGlue ONNX feature matching and ALIKED support now included in builds
- **`pycolmap.match_from_pairs`** ([#4056](https://github.com/colmap/colmap/pull/4056)) — Custom pair matching on GPU
- **Improved incremental mapper/triangulator bindings** ([#4101](https://github.com/colmap/colmap/pull/4101))

### Improvements
- Avoid unnecessary copies ([#4103](https://github.com/colmap/colmap/pull/4103))
- Use native menu bar on Mac ([#4102](https://github.com/colmap/colmap/pull/4102))

### Build System
- Fixed ONNX install on Windows via `patch_colmap_onnx_install.cmake` (upstream bug: `share/` directory only exists on non-Windows but install rule was unconditional)
- Updated both COLMAP submodules to latest (`a6f539d4`)

## System Requirements

**Minimum:**
- 8 GB RAM (16 GB recommended for large datasets)
- [Visual C++ Redistributable 2015-2022](https://aka.ms/vs/17/release/vc_redist.x64.exe) (Windows, usually already installed)

**For GPU Acceleration:**
- NVIDIA GPU with Compute Capability 7.5+ (RTX 20/30/40, A100, H100)
- NVIDIA Driver 570+ required for CUDA 12.8
- Architectures: 75, 80, 86, 89, 90, 120

**For pycolmap:**
- Python 3.10, 3.11, 3.12, 3.13, or 3.14 (64-bit)

**Windows Defender:** May flag CUDA binaries as false positives (`Wacatac.B!ml`). Add an exclusion or [submit to Microsoft](https://www.microsoft.com/en-us/wdsi/filesubmission).

## Migration from GLOMAP

```bash
# Old (standalone GLOMAP)
glomap mapper --database_path db.db --image_path images --output_path sparse

# New (COLMAP 3.14+)
colmap global_mapper --database_path db.db --image_path images --output_path sparse
```

## License

BSD 3-Clause — [COLMAP](https://github.com/colmap/colmap) · [Ceres Solver](http://ceres-solver.org/)

---

**Built with**: Visual Studio 2022, CUDA 12.8, CMake 3.28+, vcpkg
