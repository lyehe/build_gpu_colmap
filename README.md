# COLMAP GPU Builder

**Automated build scripts for COLMAP and GLOMAP with full GPU support and optimizations.**

This repository provides a complete, self-contained build environment for COLMAP, GLOMAP, and related computer vision tools, with a focus on **maximum GPU performance** for 3D reconstruction workflows.

## Purpose

This project simplifies building COLMAP and GLOMAP with:
- ✅ **Full CUDA GPU acceleration** - Optimized for modern NVIDIA GPUs (RTX 20/30/40 series, H100)
- ✅ **cuDSS integration** - Optional sparse solver for 2-5x faster bundle adjustment
- ✅ **Automated build process** - One-command builds with dependency management
- ✅ **Python wheel generation** - Build redistributable pycolmap packages
- ✅ **Cross-platform support** - Works on Windows and Linux

Perfect for researchers and developers who need high-performance 3D reconstruction tools without manual dependency configuration.

## What's Included

- **COLMAP 3.13 dev** - Latest Structure-from-Motion and Multi-View Stereo
- **COLMAP 3.13 dev for pycolmap** - Python-optimized build configuration
- **GLOMAP** - Fast global Structure-from-Motion (uses COLMAP 3.11 for compatibility)
- **Ceres Solver** - Nonlinear optimization library with CUDA support
- **PoseLib** - Camera pose estimation library
- Automated vcpkg dependency management
- GPU architecture targeting (RTX 20/30/40, H100, etc.)
- Optional cuDSS sparse solver integration

## Quick Start

### Prerequisites

#### Required Downloads

**Windows:**
- **[Visual Studio 2022](https://visualstudio.microsoft.com/downloads/)** (Community/Professional/Enterprise) with "Desktop development with C++" workload (includes CMake and Ninja) **OR** **[Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)** with "Desktop development with C++" workload (includes Ninja)
- **[Git](https://git-scm.com/download/win)**
- **[Python 3.8+](https://www.python.org/downloads/)** (for pycolmap)

**Linux:**
- GCC 9+, CMake 3.28+, Git, Python 3.8+ (install via package manager)

#### GPU Acceleration (Optional but Recommended)

- **[CUDA Toolkit 11.0+](https://developer.nvidia.com/cuda-downloads)** - Required for GPU-accelerated processing
- **[cuDSS](https://developer.nvidia.com/cudss-downloads)** - Optional sparse solver acceleration (see [installation guide](docs/INSTALL_CUDSS.md))

> **Note**: GPU acceleration significantly improves performance for large-scale 3D reconstruction. CUDA 12.x is recommended for latest GPU support.

Check your environment:
```bash
# Windows
.\scripts_windows\verify_build_environment.ps1

# Linux
./scripts_linux/verify_build_environment.sh
```

### Build

```bash
# Clone repository
git clone <repository-url>
cd colmap-gpu-builder

# Build everything (automatically initializes submodules and bootstraps vcpkg)
.\scripts_windows\build.ps1              # Windows
./scripts_linux/build.sh                  # Linux
```

**Note:** Build scripts automatically:
- Initialize required submodules and bootstrap vcpkg
- Copy all dependency DLLs/libraries (including cuDSS if installed) to installation directories
- Create self-contained builds that run without PATH configuration

Build outputs are in `build/install/`.

### Build Options

```bash
# Windows examples
.\scripts_windows\build.ps1 -Clean                    # Clean rebuild
.\scripts_windows\build.ps1 -NoCuda                   # Build without CUDA
.\scripts_windows\build.ps1 -SkipGlomap               # Build only COLMAP
.\scripts_windows\build_colmap.ps1                    # Build COLMAP only
.\scripts_windows\build_glomap.ps1                    # Build GLOMAP only

# Linux examples
./scripts_linux/build.sh --clean                      # Clean rebuild
./scripts_linux/build.sh --no-cuda                    # Build without CUDA
./scripts_linux/build.sh --no-glomap                  # Build only COLMAP
```

## Building Python Wheels

After building COLMAP, you can create redistributable Python wheels for pycolmap:

### Windows

```powershell
# Build COLMAP-for-pycolmap and wheels for ALL installed Python 3.9+ versions
# (Automatically initializes submodules and builds COLMAP-for-pycolmap)
.\scripts_windows\build_pycolmap_wheels.ps1

# Install wheel for your Python version
pip install third_party\colmap-for-pycolmap\wheelhouse\pycolmap-*.whl
```

### Linux

```bash
# Build COLMAP-for-pycolmap and wheels for ALL installed Python 3.9+ versions
./scripts_linux/build_pycolmap_wheels.sh

# Install wheel for your Python version
pip install third_party/colmap-for-pycolmap/wheelhouse/pycolmap-*.whl
```

**Features:**
- Self-contained wheels with all dependencies bundled
- No need for separate COLMAP installation
- Redistributable to other machines
- Multi-version script automatically detects all Python installations
- Wheels are platform-specific (built for your OS/architecture)

See [BUILD_PYTHON_WHEELS.md](docs/BUILD_PYTHON_WHEELS.md) for detailed documentation.

## Advanced Configuration

### CMake Options

```cmake
-DCUDA_ENABLED=ON/OFF                # Enable CUDA (default: ON)
-DBUILD_COLMAP=ON/OFF                # Build COLMAP (default: ON)
-DBUILD_COLMAP_FOR_PYCOLMAP=ON/OFF   # Build COLMAP for pycolmap (default: OFF)
-DBUILD_GLOMAP=ON/OFF                # Build GLOMAP (default: ON)
-DBUILD_CERES=ON/OFF                 # Build Ceres (default: ON)
-DGFLAGS_USE_TARGET_NAMESPACE=ON     # Fix gflags/glog linking (required)
-DCMAKE_CUDA_ARCHITECTURES           # CUDA arch targets (default: 75;80;86;89;90;120)
-DX_VCPKG_APPLOCAL_DEPS_INSTALL=ON   # Copy DLLs to install directory (auto-set)
```

### Manual Build

```bash
mkdir build && cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=../third_party/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DGFLAGS_USE_TARGET_NAMESPACE=ON
cmake --build . --config Release
```

## COLMAP Version Management

This repository can build **three** COLMAP versions:
- **COLMAP 3.13 dev** (`third_party/colmap`) → `build/install/colmap/` - Latest development version for general use
- **COLMAP 3.13 dev for pycolmap** (`third_party/colmap-for-pycolmap`) → `build/install/colmap-for-pycolmap/` - Latest development version optimized for Python wheels (GUI/tests disabled)
- **COLMAP 3.11** (`third_party/colmap-for-glomap`) → `build/install/colmap-for-glomap/` - Pinned to commit 78f1eefa for GLOMAP compatibility

The build system automatically manages version compatibility and submodule initialization.

## Troubleshooting

### CUDA Not Found
```bash
# Windows
$env:CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.0"

# Linux
export CUDA_HOME=/usr/local/cuda
export PATH=/usr/local/cuda/bin:$PATH
```

### Visual Studio Not Found (Windows)
Launch Developer PowerShell:
```powershell
.\scripts_windows\launch_dev_environment.ps1
```

### vcpkg Conflicts
Ensure no system vcpkg interferes:
```bash
# Windows
$env:VCPKG_ROOT = $null

# Linux
unset VCPKG_ROOT
```

### gflags/glog Linking Errors
If you encounter `cannot open input file 'gflags.lib'` errors, this is already fixed in the build scripts with `-DGFLAGS_USE_TARGET_NAMESPACE=ON`. If using manual CMake, add this flag:
```bash
cmake .. -DCMAKE_TOOLCHAIN_FILE=../third_party/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DGFLAGS_USE_TARGET_NAMESPACE=ON
```

### Speed Up Builds
Enable vcpkg binary caching:
```bash
# Windows
$env:VCPKG_DEFAULT_BINARY_CACHE = "C:\vcpkg-cache"

# Linux
export VCPKG_DEFAULT_BINARY_CACHE=$HOME/vcpkg-cache
```

## Documentation

- [Building Python Wheels](docs/BUILD_PYTHON_WHEELS.md)
- [cuDSS Installation Guide](docs/INSTALL_CUDSS.md)

## Requirements Details

<details>
<summary>Windows</summary>

**Required:**
- **[Visual Studio 2022](https://visualstudio.microsoft.com/downloads/)** with "Desktop development with C++" workload (includes CMake) **OR** **[Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)** with "Desktop development with C++" workload + **[CMake 3.28+](https://cmake.org/download/)** separately
- **[Git](https://git-scm.com/download/win)**
- **[Python 3.8+](https://www.python.org/downloads/)**

**Optional (GPU Acceleration):**
- **[CUDA Toolkit 11.0+](https://developer.nvidia.com/cuda-downloads)** - GPU acceleration for reconstruction
- **[cuDSS](https://developer.nvidia.com/cudss-downloads)** - Sparse solver acceleration (see [installation guide](docs/INSTALL_CUDSS.md))

**Note:** Ninja build system is included with Visual Studio 2022 "Desktop development with C++" workload. If using a custom setup, install separately: `winget install Ninja-build.Ninja`

</details>

<details>
<summary>Linux (Ubuntu/Debian)</summary>

**Required:**
```bash
sudo apt-get update
sudo apt-get install build-essential cmake git python3 python3-dev
```

**Optional (GPU Acceleration):**
```bash
# Install NVIDIA drivers
sudo apt-get install nvidia-driver-535

# Install CUDA Toolkit
sudo apt-get install nvidia-cuda-toolkit
# Or download from: https://developer.nvidia.com/cuda-downloads

# cuDSS (manual installation required)
# Download from: https://developer.nvidia.com/cudss-downloads
# See installation guide: docs/INSTALL_CUDSS.md
```

**Optional (Performance):**
```bash
sudo apt-get install ninja-build
```

</details>

## Project Structure

```
colmap-gpu-builder/
├── build/                       # Build output (gitignored)
│   └── install/                # Executables and libraries
│       ├── colmap/             # COLMAP (latest)
│       ├── colmap-for-pycolmap/# COLMAP for Python wheels
│       ├── colmap-for-glomap/  # COLMAP 3.11
│       ├── glomap/             # GLOMAP
│       ├── ceres/              # Ceres Solver
│       └── poselib/            # PoseLib
├── cmake/                      # CMake helper scripts
├── docs/                       # Documentation
├── overlay-ports/              # vcpkg custom patches
├── scripts_windows/            # Windows build scripts
├── scripts_linux/              # Linux build scripts
├── third_party/                # Git submodules (auto-initialized)
│   ├── vcpkg/                 # Package manager
│   ├── colmap/                # COLMAP (latest)
│   ├── colmap-for-pycolmap/   # COLMAP for pycolmap
│   ├── colmap-for-glomap/     # COLMAP 3.11
│   ├── glomap/                # GLOMAP
│   ├── ceres-solver/          # Ceres Solver
│   └── poselib/               # PoseLib
├── CMakeLists.txt             # Root build config
└── vcpkg.json                 # Dependency manifest
```

## License

Each component has its own license:
- COLMAP: BSD 3-Clause
- GLOMAP: BSD 3-Clause
- Ceres Solver: BSD 3-Clause
- PoseLib: BSD 3-Clause

## References

- [COLMAP Documentation](https://colmap.github.io/)
- [GLOMAP Repository](https://github.com/colmap/glomap)
- [Ceres Solver](http://ceres-solver.org/)
- [vcpkg](https://vcpkg.io/)
