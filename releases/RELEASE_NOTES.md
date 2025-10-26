# Point Cloud Tools v1.0.0

Pre-built Windows binaries for COLMAP, GLOMAP, and Python wheels with CUDA support.

## What's Included

### COLMAP 3.13 dev - Windows x64 CUDA (119 MB)
**File**: `COLMAP-3.13-dev-Windows-x64-CUDA.zip`

Latest COLMAP development version (3.13.0.dev0) for Structure-from-Motion and Multi-View Stereo reconstruction.

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
- `pycolmap-3.13.0.dev0-cp310-cp310-win_amd64.whl` (Python 3.10)
- `pycolmap-3.13.0.dev0-cp311-cp311-win_amd64.whl` (Python 3.11)
- `pycolmap-3.13.0.dev0-cp312-cp312-win_amd64.whl` (Python 3.12)

Python bindings for COLMAP with all dependencies bundled.

- No separate COLMAP installation needed
- CUDA support included
- Works on any Windows machine with matching Python version

**Installation**:
```bash
pip install pycolmap-3.13.0.dev0-cp312-cp312-win_amd64.whl
```

**Quick Test**:
```python
import pycolmap
pycolmap.extract_features(image_path="images/", database_path="database.db")
```

## System Requirements

**Windows Compatibility**:
- ✅ **Windows 10/11 (64-bit only)** - Fully tested and supported
- ⚠️ **Windows 7/8/8.1** - May work but not tested
- ❌ **32-bit Windows** - Not supported

**Minimum**:
- 8 GB RAM (16 GB recommended for large datasets)
- [Visual C++ Redistributable 2015-2022](https://aka.ms/vs/17/release/vc_redist.x64.exe) (usually already installed)

**For GPU Acceleration** (optional but recommended):
- NVIDIA GPU with Compute Capability 7.5+ (RTX 20/30/40, A100, H100)
- [CUDA Toolkit 11.0+](https://developer.nvidia.com/cuda-downloads) installed separately
- Latest NVIDIA drivers

**Note**: Binaries will run without CUDA but GPU acceleration will be disabled.

**For pycolmap**:
- Python 3.10, 3.11, or 3.12 (64-bit)
- Wheels are self-contained and work on any compatible Windows machine

## What's New

- Latest COLMAP 3.13 development version with newest features
- GLOMAP with COLMAP 3.11 for compatibility
- Self-contained Python wheels for easy installation
- All packages include CUDA support for GPU acceleration

## Supported GPU Architectures

Compiled for: RTX 20/30/40 series, A100, H100 (architectures 75, 80, 86, 89, 90, 120)

## License

Each component has its own BSD 3-Clause License:
- [COLMAP](https://github.com/colmap/colmap)
- [GLOMAP](https://github.com/colmap/glomap)
- [Ceres Solver](http://ceres-solver.org/)
- [PoseLib](https://github.com/PoseLib/PoseLib)

## Documentation

- [Build from source](https://github.com/lyehe/build_gpu_colmap)
- [COLMAP Documentation](https://colmap.github.io/)
- [Report issues](https://github.com/lyehe/build_gpu_colmap/issues)

---

**Built with**: Visual Studio 2022, CUDA 12.x, CMake 3.28+, vcpkg
