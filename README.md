# Point Cloud Tools

Self-contained build environment for COLMAP, GLOMAP, and related computer vision tools with CUDA support.

## Features

- **COLMAP** (latest) - Structure-from-Motion and Multi-View Stereo
- **GLOMAP** - Fast global Structure-from-Motion
- **Ceres Solver** - Nonlinear optimization library
- **PoseLib** - Camera pose estimation
- Automated dependency management via vcpkg
- CUDA support with optimizations for modern GPUs (RTX 20/30/40 series, H100)
- Cross-platform (Windows/Linux)

## Quick Start

### Prerequisites

- **Windows**: Visual Studio 2022 or Build Tools, CMake 3.28+, Git, Python 3.8+
- **Linux**: GCC 9+, CMake 3.28+, Git, Python 3.8+
- **GPU (optional)**: CUDA Toolkit 11.0+ for GPU acceleration

Check your environment:
```bash
# Windows
.\scripts_windows\verify_build_environment.ps1

# Linux
./scripts_linux/verify_build_environment.sh
```

### Build

```bash
# Clone and initialize
git clone <repository-url>
cd point_cloud_tools
.\scripts_windows\initialize_repository.ps1  # Windows
./scripts_linux/initialize_repository.sh     # Linux

# Build everything
.\scripts_windows\build.ps1              # Windows
./scripts_linux/build.sh                  # Linux
```

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

### Single Python Version

```powershell
# Windows - Build for current Python version
.\scripts_windows\build_colmap.ps1
.\scripts_windows\build_pycolmap_wheel.ps1
pip install third_party\colmap\wheelhouse\pycolmap-*.whl
```

```bash
# Linux - Build for current Python version
./scripts_linux/build_colmap.sh
./scripts_linux/build_pycolmap_wheel.sh
pip install third_party/colmap/wheelhouse/pycolmap-*.whl
```

### Multiple Python Versions (Recommended)

```powershell
# Windows - Build for ALL installed Python 3.9+ versions
.\scripts_windows\build_colmap.ps1
.\scripts_windows\build_pycolmap_wheels_all.ps1
```

```bash
# Linux - Build for ALL installed Python 3.9+ versions
./scripts_linux/build_colmap.sh
./scripts_linux/build_pycolmap_wheels_all.sh
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
-DCUDA_ENABLED=ON/OFF              # Enable CUDA (default: ON)
-DBUILD_COLMAP=ON/OFF              # Build COLMAP (default: ON)
-DBUILD_GLOMAP=ON/OFF              # Build GLOMAP (default: ON)
-DBUILD_CERES=ON/OFF               # Build Ceres (default: ON)
-DGFLAGS_USE_TARGET_NAMESPACE=ON   # Fix gflags/glog linking (required)
-DCMAKE_CUDA_ARCHITECTURES         # CUDA arch targets (default: 75;80;86;89;90;120)
```

### Manual Build

```bash
mkdir build && cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=../third_party/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DGFLAGS_USE_TARGET_NAMESPACE=ON
cmake --build . --config Release
```

## COLMAP Version Management

This repository builds **two** COLMAP versions:
- **Latest COLMAP** (`third_party/colmap`) - For general use
- **COLMAP 3.11** (`third_party/colmap-for-glomap`) - Pinned for GLOMAP compatibility

The build system automatically manages version compatibility.

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

See [docs/GFLAGS_FIX.md](docs/GFLAGS_FIX.md) for technical details.

### Speed Up Builds
Enable vcpkg binary caching:
```bash
# Windows
$env:VCPKG_DEFAULT_BINARY_CACHE = "C:\vcpkg-cache"

# Linux
export VCPKG_DEFAULT_BINARY_CACHE=$HOME/vcpkg-cache
```

## Documentation

- [Build System Analysis](docs/BUILD_ANALYSIS.md)
- [Building Python Wheels](docs/BUILD_PYTHON_WHEELS.md)
- [COLMAP Version Compatibility](docs/GLOMAP_COLMAP_VERSION.md)
- [gflags Target Namespace Fix](docs/GFLAGS_FIX.md)
- [cuDSS Installation Guide](docs/INSTALL_CUDSS.md)
- [cuDSS Detection](docs/CUDSS_DETECTION.md)

## Requirements Details

<details>
<summary>Windows</summary>

**Required:**
- Visual Studio 2022 or Build Tools with "Desktop development with C++" workload
- CMake 3.28+ ([download](https://cmake.org/download/))
- Git ([download](https://git-scm.com/download/win))
- Python 3.8+ ([download](https://www.python.org/downloads/))

**Optional:**
- CUDA Toolkit 11.0+ ([download](https://developer.nvidia.com/cuda-downloads))
- cuDSS for sparse solver acceleration ([download](https://developer.nvidia.com/cudss-downloads))
- Ninja build system: `winget install Ninja-build.Ninja`

</details>

<details>
<summary>Linux (Ubuntu/Debian)</summary>

**Required:**
```bash
sudo apt-get update
sudo apt-get install build-essential cmake git python3 python3-dev
```

**Optional (CUDA):**
```bash
# Install NVIDIA drivers
sudo apt-get install nvidia-driver-535

# Install CUDA Toolkit
sudo apt-get install nvidia-cuda-toolkit
# Or download from: https://developer.nvidia.com/cuda-downloads
```

**Optional (Performance):**
```bash
sudo apt-get install ninja-build
```

</details>

## Project Structure

```
point_cloud_tools/
├── build/                    # Build output (gitignored)
├── cmake/                    # CMake helper scripts
├── docs/                     # Documentation
├── overlay-ports/            # vcpkg custom patches
├── scripts_windows/          # Windows build scripts
├── scripts_linux/            # Linux build scripts
├── third_party/              # Git submodules
│   ├── vcpkg/               # Package manager
│   ├── colmap/              # COLMAP (latest)
│   ├── colmap-for-glomap/   # COLMAP 3.11
│   ├── glomap/              # GLOMAP
│   ├── ceres-solver/        # Ceres Solver
│   └── poselib/             # PoseLib
├── CMakeLists.txt           # Root build config
└── vcpkg.json               # Dependency manifest
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
