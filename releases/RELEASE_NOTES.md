# Point Cloud Tools v2.2.0 - COLMAP 3.14

Pre-built Windows/Linux binaries for COLMAP, GLOMAP, and Python wheels with CUDA 12.8 support.

## ⚠️ Important: NVIDIA Driver 570+ Required

CUDA 12.8 binaries require **NVIDIA Driver 570 or later**. Check with `nvidia-smi`.

## 🎉 Highlights

- **GLOMAP merged into COLMAP** - Global SfM functionality is now part of COLMAP 3.14
- **New fisheye (equidistant) camera model**
- **Python 3.10-3.14 support**

## What's Included

### COLMAP 3.14 dev - Windows x64 CUDA (119 MB)
**File**: `COLMAP-3.14-dev-Windows-x64-CUDA.zip`

Latest COLMAP development version (3.14.0.dev0) for Structure-from-Motion and Multi-View Stereo reconstruction.

- All dependencies bundled (no separate installation needed)
- CUDA GPU acceleration for RTX 20/30/40 series, A100, H100
- Includes GUI and command-line tools

**Quick Start**:
```cmd
# Extract and run
.\COLMAP.bat

# Or command line
.\bin\colmap.exe help
```

---

### GLOMAP - Windows x64 CUDA (667 KB)
**File**: `GLOMAP-Windows-x64-CUDA.zip`

Fast global Structure-from-Motion tool.

- Self-contained with all dependencies (COLMAP 3.11, Ceres, PoseLib)
- No additional installation required
- GPU-accelerated processing

**Quick Start**:
```cmd
.\bin\glomap.exe mapper --help
```

---

### pycolmap - Python Wheels (570 MB each)
**Files**:
- `pycolmap-3.14.0.dev0-cp310-cp310-win_amd64.whl` (Python 3.10)
- `pycolmap-3.14.0.dev0-cp311-cp311-win_amd64.whl` (Python 3.11)
- `pycolmap-3.14.0.dev0-cp312-cp312-win_amd64.whl` (Python 3.12)
- `pycolmap-3.14.0.dev0-cp313-cp313-win_amd64.whl` (Python 3.13)
- `pycolmap-3.14.0.dev0-cp314-cp314-win_amd64.whl` (Python 3.14)

Python bindings for COLMAP with all dependencies bundled.

- No separate COLMAP installation needed
- CUDA support included
- Works on any Windows machine with matching Python version

**Installation**:
```bash
pip install pycolmap-3.14.0.dev0-cp312-cp312-win_amd64.whl
```

**Quick Test**:
```python
import pycolmap
pycolmap.extract_features(image_path="images/", database_path="database.db")
```

## System Requirements

**⚠️ Windows Defender False Positive Notice**:
Windows Defender may flag these binaries as potentially unwanted software (typically `Wacatac.B!ml`). This is a **false positive** common with CUDA-compiled binaries. These files are built from official open-source COLMAP/GLOMAP repositories with no modifications. You can:
- Add an exclusion in Windows Security
- Submit as false positive to Microsoft: https://www.microsoft.com/en-us/wdsi/filesubmission
- Verify by building from source yourself using this repository

**Windows Compatibility**:
- ✅ **Windows 10/11 (64-bit only)** - Fully tested and supported
- ⚠️ **Windows 7/8/8.1** - May work but not tested
- ❌ **32-bit Windows** - Not supported

**Minimum**:
- 8 GB RAM (16 GB recommended for large datasets)
- [Visual C++ Redistributable 2015-2022](https://aka.ms/vs/17/release/vc_redist.x64.exe) (usually already installed)

**For GPU Acceleration** (optional but recommended):
- NVIDIA GPU with Compute Capability 7.5+ (RTX 20/30/40, A100, H100)
- **NVIDIA Driver 570.26+ required** (for CUDA 12.8 binaries)
  - Windows: Driver 570.65+
  - Linux: Driver 570.26+
- Check your driver version: `nvidia-smi`

**Note**: Binaries will run without CUDA but GPU acceleration will be disabled.

**⚠️ "PTX compiled with unsupported toolchain" Error**:
If you see this error during GPU feature extraction, your NVIDIA driver is too old.
```
CUDA error: the provided PTX was compiled with an unsupported toolchain
```
**Fix**: Update your NVIDIA driver to version 570 or later:
- Windows: Download from [NVIDIA Drivers](https://www.nvidia.com/Download/index.aspx)
- Linux: `sudo apt install nvidia-driver-570` (Ubuntu/Debian)

**For pycolmap**:
- Python 3.10, 3.11, 3.12, 3.13, or 3.14 (64-bit)
- Wheels are self-contained and work on any compatible Windows machine

## What's New in COLMAP 3.14

- **GLOMAP merged into COLMAP** - Run global SfM directly: `colmap global_mapper`
- **New fisheye (equidistant) camera model** - Better support for wide-angle lenses
- **Bundle adjustment refactoring** - Improved optimization performance
- **PLY mesh reading support** - Import mesh files directly
- Standalone GLOMAP package still available (uses COLMAP 3.11 for compatibility)

## Supported GPU Architectures

Compiled for: RTX 20/30/40 series, A100, H100 (architectures 75, 80, 86, 89, 90, 120)

## License

Each component has its own BSD 3-Clause License:
- [COLMAP](https://github.com/colmap/colmap)
- [GLOMAP](https://github.com/colmap/glomap)
- [Ceres Solver](http://ceres-solver.org/)
- [PoseLib](https://github.com/PoseLib/PoseLib)

## Documentation

- [Build from source](https://github.com/YOUR-USERNAME/colmap-gpu-builder)
- [COLMAP Documentation](https://colmap.github.io/)
- [Report issues](https://github.com/YOUR-USERNAME/colmap-gpu-builder/issues)

---

**Built with**: Visual Studio 2022, CUDA 12.x, CMake 3.28+, vcpkg
