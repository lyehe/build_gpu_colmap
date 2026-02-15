# Point Cloud Tools v2.3.0 - COLMAP 3.14

Pre-built Windows/Linux binaries for COLMAP and Python wheels with CUDA 12.8 support.

## Important: NVIDIA Driver 570+ Required

CUDA 12.8 binaries require **NVIDIA Driver 570 or later**. Check with `nvidia-smi`.

## Highlights

- **COLMAP updated to latest** - Includes LightGlue ONNX feature matching and ALIKED support
- **GLOMAP removed from repository** - Global SfM is now built into COLMAP 3.14 (`colmap global_mapper`)
- **Build fixes** - Disabled ONNX runtime to fix install failures, fixed ExternalProject LIST_SEPARATOR handling
- **Python 3.10-3.14 support**

## What's Included

### COLMAP 3.14 dev - Windows x64 CUDA
**File**: `COLMAP-3.14-dev-Windows-x64-CUDA.zip`

Latest COLMAP development version (3.14.0.dev0) for Structure-from-Motion and Multi-View Stereo reconstruction.

- All dependencies bundled (no separate installation needed)
- CUDA GPU acceleration for RTX 20/30/40 series, A100, H100
- Includes GUI and command-line tools
- **Global SfM included** - Use `colmap global_mapper` for fast global SfM (previously GLOMAP)
- **LightGlue ONNX** - State-of-the-art learned feature matching
- **ALIKED** - Another learned feature detector/descriptor

**Quick Start**:
```cmd
# Extract and run
.\COLMAP.bat

# Or command line
.\bin\colmap.exe help

# Global SfM (previously GLOMAP)
.\bin\colmap.exe global_mapper --database_path db.db --image_path images --output_path sparse
```

---

### pycolmap - Python Wheels
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
- **Global SfM included** - Access via `pycolmap.global_mapper()`

**Installation**:
```bash
pip install pycolmap-3.14.0.dev0-cp312-cp312-win_amd64.whl
```

**Quick Test**:
```python
import pycolmap
pycolmap.extract_features(image_path="images/", database_path="database.db")
```

## What's New in v2.3.0

### COLMAP Updates
- **LightGlue ONNX feature matching** - State-of-the-art learned feature matching via ONNX runtime
- **ALIKED support** - Additional learned feature detector/descriptor via ONNX
- Various bug fixes and dependency updates from upstream COLMAP

### Repository Changes
- **GLOMAP removed** - The standalone GLOMAP build has been removed from this repository since global SfM is now integrated into COLMAP 3.14 as `colmap global_mapper`
- **ONNX runtime disabled** - Disabled ONNX runtime in COLMAP builds to fix install failures (ONNX feature matchers still work via built-in support)
- **ExternalProject LIST_SEPARATOR fix** - Fixed CMake list separator handling for paths with semicolons

## System Requirements

**Windows Defender False Positive Notice**:
Windows Defender may flag these binaries as potentially unwanted software (typically `Wacatac.B!ml`). This is a **false positive** common with CUDA-compiled binaries. These files are built from official open-source COLMAP repositories with no modifications. You can:
- Add an exclusion in Windows Security
- Submit as false positive to Microsoft: https://www.microsoft.com/en-us/wdsi/filesubmission
- Verify by building from source yourself using this repository

**Windows Compatibility**:
- **Windows 10/11 (64-bit only)** - Fully tested and supported
- **Windows 7/8/8.1** - May work but not tested
- **32-bit Windows** - Not supported

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

**"PTX compiled with unsupported toolchain" Error**:
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

## Migration from GLOMAP

If you were previously using the standalone GLOMAP binary, simply replace:

```bash
# Old (standalone GLOMAP)
glomap mapper --database_path db.db --image_path images --output_path sparse

# New (COLMAP 3.14+)
colmap global_mapper --database_path db.db --image_path images --output_path sparse
```

## Supported GPU Architectures

Compiled for: RTX 20/30/40 series, A100, H100 (architectures 75, 80, 86, 89, 90, 120)

## License

Each component has its own BSD 3-Clause License:
- [COLMAP](https://github.com/colmap/colmap)
- [Ceres Solver](http://ceres-solver.org/)

## Documentation

- [Build from source](https://github.com/opsiclear/point-cloud-tools)
- [COLMAP Documentation](https://colmap.github.io/)
- [Report issues](https://github.com/opsiclear/point-cloud-tools/issues)

---

**Built with**: Visual Studio 2022, CUDA 12.x, CMake 3.28+, vcpkg
