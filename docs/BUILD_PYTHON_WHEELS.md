# Building Python Wheels

This document explains how to build redistributable Python wheels for pycolmap with all dependencies bundled.

## Overview

The wheel building scripts create self-contained `.whl` files that include all required DLLs (Windows) or shared libraries (Linux). This allows pycolmap to be installed on machines without a separate COLMAP installation.

## Prerequisites

**Windows:**
- Python 3.9+ with pip
- COLMAP already built (via `build_colmap.ps1`)
- Visual Studio Build Tools (for native extensions)

**Linux:**
- Python 3.9+ with pip and development headers
- COLMAP already built (via `build_colmap.sh`)
- GCC compiler and build tools

## Quick Start

### Windows

```powershell
# 1. Build COLMAP
.\scripts_windows\build_colmap.ps1

# 2. Build pycolmap wheels (auto-detects all Python 3.9+ versions)
.\scripts_windows\build_pycolmap_wheels.ps1

# 3. Install the wheel for your Python version
pip install third_party\colmap-for-pycolmap\wheelhouse\pycolmap-*.whl

# 4. Test installation
python -c "import pycolmap; print(pycolmap.__version__)"
```

### Linux

```bash
# 1. Build COLMAP
./scripts_linux/build_colmap.sh

# 2. Build pycolmap wheel
./scripts_linux/build_pycolmap_wheel.sh

# 3. Install the wheel
pip install third_party/colmap/wheelhouse/pycolmap-*.whl

# 4. Test installation
python3 -c "import pycolmap; print(pycolmap.__version__)"
```

## Build Process Details

### Windows - Using delvewheel

The Windows script uses [delvewheel](https://github.com/adang1345/delvewheel) to bundle DLLs:

1. **Build Phase:**
   - Configures pycolmap build with `CMAKE_PREFIX_PATH` pointing to COLMAP installation
   - Uses `python -m build` to create initial wheel
   - Wheel contains pycolmap bindings but references external DLLs

2. **Bundling Phase:**
   - `delvewheel repair` analyzes DLL dependencies
   - Copies all required DLLs into the wheel
   - Creates `.libs/` directory inside the wheel
   - Modifies imports to load from bundled DLLs

3. **Output:**
   - Original wheel: `dist/pycolmap-*.whl` (~2-5 MB)
   - Bundled wheel: `wheelhouse/pycolmap-*.whl` (~50-100 MB)

**Bundled Dependencies:**
- COLMAP DLLs (colmap.dll, colmap_cuda.dll, etc.)
- vcpkg dependencies (glog, gflags, FreeImage, etc.)
- CUDA runtime DLLs (if CUDA enabled)
- cuDSS DLLs (if cuDSS installed)
- Visual C++ runtime

### Linux - Using auditwheel

The Linux scripts use [auditwheel](https://github.com/pypa/auditwheel) to bundle shared libraries:

1. **Build Phase:**
   - Sets `CMAKE_PREFIX_PATH` and `LD_LIBRARY_PATH`
   - Builds wheel with `python -m build`
   - Wheel references system libraries via RPATH

2. **Bundling Phase:**
   - `auditwheel repair` analyzes .so dependencies
   - Copies libraries not provided by manylinux platform
   - Creates `.libs/` directory in wheel
   - Sets proper RPATH for bundled libraries

3. **Platform Tags:**
   - Tries `manylinux_2_31_x86_64` first (modern distros, glibc 2.31+)
   - Falls back to `manylinux2014_x86_64` (broader compatibility, glibc 2.17+)

**Bundled Dependencies:**
- COLMAP libraries (libcolmap.so, libcolmap_cuda.so, etc.)
- vcpkg dependencies (libglog, libgflags, etc.)
- CUDA libraries (if not system-provided)
- cuDSS libraries (if installed)

## Options

### Windows Script Options

```powershell
.\scripts_windows\build_pycolmap_wheels.ps1 [options]

Options:
  -Configuration Debug|Release   Build configuration (default: Release)
  -NoCuda                        Build without CUDA support
  -Clean                         Clean previous build artifacts
  -Help                          Show help message

Note: This script auto-detects and builds wheels for ALL installed Python 3.9+ versions.
```

### Linux Script Options

**Single-version script:**
```bash
./scripts_linux/build_pycolmap_wheel.sh [options]

Options:
  Debug|Release      Build configuration (default: Release)
  --no-cuda          Build without CUDA support
  --clean            Clean previous build artifacts
  --help, -h         Show help message
```

**Multi-version script (recommended):**
```bash
./scripts_linux/build_pycolmap_wheels.sh [options]

Options:
  Debug|Release      Build configuration (default: Release)
  --no-cuda          Build without CUDA support
  --clean            Clean previous build artifacts
  --help, -h         Show help message

Note: Auto-detects and builds wheels for ALL installed Python 3.9+ versions.
Searches python3.9, python3.10, python3.11, python3.12, etc.
```

## Common Issues

### "COLMAP not found"

**Cause:** COLMAP hasn't been built yet.

**Solution:**
```powershell
# Windows
.\scripts_windows\build_colmap.ps1

# Linux
./scripts_linux/build_colmap.sh
```

### "Python not found" or "Python version too old"

**Cause:** Python 3.9+ not installed or not in PATH.

**Solution:**
```powershell
# Windows
winget install Python.Python.3.12

# Linux (Ubuntu)
sudo apt-get install python3.12 python3.12-dev
```

### Wheel build succeeds but import fails

**Cause:** DLL/library bundling failed or incomplete.

**Symptoms:**
```
ImportError: DLL load failed while importing pycolmap
ModuleNotFoundError: No module named '_pycolmap'
```

**Solution:**

**Windows:**
```powershell
# Check delvewheel is installed
pip show delvewheel

# Rebuild with verbose output
.\scripts_windows\build_pycolmap_wheels.ps1 -Clean
```

**Linux:**
```bash
# Check auditwheel is installed
pip show auditwheel

# Verify wheel dependencies
auditwheel show third_party/colmap/wheelhouse/pycolmap-*.whl

# Rebuild
./scripts_linux/build_pycolmap_wheel.sh --clean
```

### Large wheel size (>200 MB)

**Cause:** Debug symbols included or unnecessary dependencies bundled.

**Solution:**
```powershell
# Use Release build (smaller binaries)
.\scripts_windows\build_pycolmap_wheels.ps1 -Configuration Release
```

For Linux, debug symbols are stripped by default during wheel repair.

## Distribution

The generated wheels are **platform-specific** and can be distributed:

**Windows:**
- `pycolmap-3.13.0.dev0-cp312-cp312-win_amd64.whl`
  - Works on Windows 10/11 x64
  - Python 3.12 specific
  - ~50-100 MB with CUDA

**Linux:**
- `pycolmap-3.13.0.dev0-cp312-cp312-manylinux_2_31_x86_64.whl`
  - Works on modern Linux (Ubuntu 22.04+, RHEL 9+)
  - Python 3.12 specific
  - ~50-80 MB

**To share:**
```bash
# Upload to file server, S3, etc.
# Users install with:
pip install pycolmap-3.13.0.dev0-cp312-cp312-*.whl
```

## Advanced: Building for Multiple Python Versions

The Windows script automatically builds wheels for all installed Python versions by default.

### Windows - Multi-Version Build (Default Behavior)

```powershell
# Build COLMAP first
.\scripts_windows\build_colmap.ps1

# Build wheels for ALL installed Python versions (3.9+)
.\scripts_windows\build_pycolmap_wheels.ps1

# Build without CUDA for all versions
.\scripts_windows\build_pycolmap_wheels.ps1 -NoCuda

# Clean build for all versions
.\scripts_windows\build_pycolmap_wheels.ps1 -Clean
```

**Features:**
- Automatically detects all Python 3.9+ installations
- Searches py launcher, PATH, and common directories
- Builds wheel for each version sequentially with progress reporting
- Shows success/failure summary for each version
- All wheels output to `third_party\colmap-for-pycolmap\wheelhouse\`

**Install multiple Python versions:**
```powershell
winget install Python.Python.3.10
winget install Python.Python.3.11
winget install Python.Python.3.12
winget install Python.Python.3.13
```

### Linux - Multi-Version Build

**Option 1: New unified script (recommended)**
```bash
# Build COLMAP first
./scripts_linux/build_colmap.sh

# Build wheels for ALL installed Python versions (3.9+)
./scripts_linux/build_pycolmap_wheels.sh

# Build without CUDA for all versions
./scripts_linux/build_pycolmap_wheels.sh --no-cuda

# Clean build for all versions
./scripts_linux/build_pycolmap_wheels.sh --clean
```

**Features:**
- Auto-detects all Python 3.9+ installations
- Uses colmap-for-pycolmap with optimized settings (GUI/tests disabled)
- scikit-build-core integration with proper CMake configuration
- auditwheel bundling for manylinux compatibility
- Builds wheel for each version sequentially
- Shows success/failure summary for each version
- All wheels output to `third_party/colmap-for-pycolmap/wheelhouse/`

**Option 2: Legacy wrapper script (still available)**
```bash
# Build wheels for all detected versions
./scripts_linux/build_pycolmap_wheels_all.sh
```

**Install multiple Python versions (Ubuntu):**
```bash
sudo apt-get install python3.9 python3.9-dev
sudo apt-get install python3.10 python3.10-dev
sudo apt-get install python3.11 python3.11-dev
sudo apt-get install python3.12 python3.12-dev
```

### Manual Single-Version Build

If you need to build for a specific Python version only (Windows):

```powershell
# Ensure only the desired Python version is in PATH
# The script will detect and use the first Python 3.9+ it finds

# Option 1: Temporarily modify PATH
$env:PATH = "C:\Python310;$env:PATH"
.\scripts_windows\build_pycolmap_wheels.ps1

# Option 2: Install required Python versions selectively
# The script automatically builds for all detected versions
```

```bash
# Linux - Use version-specific python commands
python3.10 -m pip install build auditwheel
# Temporarily add Python 3.10 to PATH, then run:
./scripts_linux/build_pycolmap_wheel.sh

# Repeat for other versions
python3.12 -m pip install build auditwheel
./scripts_linux/build_pycolmap_wheel.sh
```

## Technical Details

### Wheel Contents

A bundled wheel contains:

```
pycolmap-3.13.0.dev0-cp312-cp312-win_amd64.whl
├── pycolmap/                 # Python package
│   ├── __init__.py
│   ├── _pycolmap.*.pyd       # C++ extension (Windows)
│   └── ...
├── pycolmap.libs/            # Bundled DLLs (Windows)
│   ├── colmap.dll
│   ├── glog.dll
│   ├── cudart64_*.dll
│   └── ...
└── pycolmap-3.13.0.dev0.dist-info/
    ├── METADATA
    ├── WHEEL
    └── ...
```

### Import Mechanism

When `import pycolmap` executes:

1. Python finds the package in site-packages
2. `__init__.py` imports `_pycolmap` (C++ extension)
3. `_pycolmap.pyd`/`.so` loads
4. Operating system resolves DLL/library dependencies:
   - **Windows:** Looks in `pycolmap.libs/` first (via DLL redirection)
   - **Linux:** Follows RPATH to `pycolmap.libs/`
5. All bundled libraries load successfully
6. pycolmap module initializes

## References

- [delvewheel documentation](https://github.com/adang1345/delvewheel)
- [auditwheel documentation](https://github.com/pypa/auditwheel)
- [PEP 427 - The Wheel Binary Package Format](https://www.python.org/dev/peps/pep-0427/)
- [manylinux specification](https://github.com/pypa/manylinux)
- [COLMAP Python bindings](https://github.com/colmap/colmap/tree/main/python)
