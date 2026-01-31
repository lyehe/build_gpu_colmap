# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Point Cloud Tools** - Self-contained build environment for COLMAP, GLOMAP, and related computer vision tools with CUDA support. This project uses vcpkg for dependency management and CMake's ExternalProject module to orchestrate builds of multiple interdependent computer vision libraries.

### Key Components
- **COLMAP 3.14 dev** - Structure-from-Motion and Multi-View Stereo (latest development, general use)
- **COLMAP 3.14 dev for pycolmap** (colmap-for-pycolmap) - Latest development version configured specifically for Python wheel building
- **COLMAP 3.11** (colmap-for-glomap) - Pinned to commit 78f1eefa specifically for GLOMAP compatibility
- **GLOMAP** - Fast global Structure-from-Motion
- **Ceres Solver** - Nonlinear optimization library (base dependency for all)
- **PoseLib** - Camera pose estimation (dependency for GLOMAP)

## Common Build Commands

### Initial Setup
```powershell
# Windows - Verify build environment
.\scripts_windows\verify_build_environment.ps1
```

```bash
# Linux
./scripts_linux/verify_build_environment.sh
```

**Note:** All build scripts automatically initialize required submodules and bootstrap vcpkg if not already done. You can start building immediately after cloning the repository.

### Building

```powershell
# Windows - Build everything (COLMAP + GLOMAP)
# Automatically initializes submodules and bootstraps vcpkg
.\scripts_windows\build.ps1 -Configuration Release

# Build only COLMAP (latest)
.\scripts_windows\build_colmap.ps1

# Build only GLOMAP (includes Ceres, PoseLib, COLMAP 3.11)
.\scripts_windows\build_glomap.ps1

# Build without CUDA
.\scripts_windows\build.ps1 -NoCuda

# Clean rebuild
.\scripts_windows\build.ps1 -Clean
```

```bash
# Linux
./scripts_linux/build.sh --config Release
./scripts_linux/build_colmap.sh
./scripts_linux/build_glomap.sh
./scripts_linux/build.sh --no-cuda
./scripts_linux/build.sh --clean
```

### Python Wheels

**Option 1: Use regular COLMAP (default)**
```powershell
# Windows - Build wheels for ALL installed Python 3.9+ versions
.\scripts_windows\build_colmap.ps1
.\scripts_windows\build_pycolmap_wheels.ps1
```

```bash
# Linux - All versions (recommended)
./scripts_linux/build_colmap.sh
./scripts_linux/build_pycolmap_wheels.sh

# Linux - Single version (alternative)
./scripts_linux/build_pycolmap_wheel.sh
```

**Option 2: Use COLMAP-for-pycolmap (optimized configuration)**
```bash
# Build COLMAP with pycolmap-specific configuration
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=../third_party/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DBUILD_COLMAP=OFF \
  -DBUILD_COLMAP_FOR_PYCOLMAP=ON \
  -DBUILD_GLOMAP=OFF \
  -DCUDA_ENABLED=ON
cmake --build . --config Release

# Then use the install from build/install/colmap-for-pycolmap/
```

## Architecture & Build System

### Multiple COLMAP Version Strategy
This project can build **three separate COLMAP versions**:

1. **COLMAP 3.14 dev** (`third_party/colmap`) → `build/install/colmap/`
   - For general use
   - Tracks latest COLMAP main branch (version 3.14.0.dev0)
   - Full features enabled

2. **COLMAP 3.14 dev for pycolmap** (`third_party/colmap-for-pycolmap`) → `build/install/colmap-for-pycolmap/`
   - For building Python wheels with specific configurations
   - Tracks latest COLMAP main branch (version 3.14.0.dev0)
   - Built with GUI/tests disabled, optimized for Python bindings
   - Optional build (set `-DBUILD_COLMAP_FOR_PYCOLMAP=ON`)

3. **COLMAP 3.11** (`third_party/colmap-for-glomap`) → `build/install/colmap-for-glomap/`
   - Pinned to commit 78f1eefa (tagged as 3.10-137-g78f1eefa, "Changelog for upcoming 3.11 release")
   - Specifically for GLOMAP compatibility (GLOMAP requires this exact version)
   - Built with GUI/CGAL/tests disabled

**Why?** Different use cases require different COLMAP configurations and versions for optimal compatibility and performance.

### Build Dependency Chain

The CMakeLists.txt uses `ExternalProject_Add()` to enforce strict build order:

```
Ceres Solver (base dependency)
    ├── COLMAP 3.14 dev ─────────────→ build/install/colmap/
    ├── COLMAP 3.14 dev for pycolmap (optional) → build/install/colmap-for-pycolmap/
    ├── COLMAP 3.11 ─────────────────→ build/install/colmap-for-glomap/
    └── PoseLib ─────────────────────→ build/install/poselib/
            └── GLOMAP ──────────────→ build/install/glomap/
```

**Critical Details:**
- Ceres is built first with `ExternalProject_Add()` and installed to `build/install/ceres/`
- Subsequent projects use `-DCMAKE_PREFIX_PATH=${BASE_INSTALL_DIR}/ceres` to find Ceres
- All projects share the same `vcpkg_installed` directory for dependencies
- GLOMAP is built last as a separate CMake invocation (see `CMakeLists.txt:404-411`)

### vcpkg Integration

**Local vcpkg** (not system vcpkg):
- Submodule at `third_party/vcpkg/`
- Bootstrapped via `scripts_windows/bootstrap.ps1` or `scripts_linux/bootstrap.sh`
- Toolchain file: `third_party/vcpkg/scripts/buildsystems/vcpkg.cmake`
- Manifest mode: Dependencies defined in `vcpkg.json`
- Overlay ports in `overlay-ports/` for custom patches (e.g., SuiteSparse CUDA support)

**vcpkg Features:**
- `cuda` feature enabled when `CUDA_ENABLED=ON` (default)
- Manifest features set BEFORE `project()` in CMakeLists.txt (line 14-17)

### CUDA Configuration

**CUDA Detection Flow** (CMakeLists.txt lines 34-240):
1. Detects CUDA Toolkit via `find_package(CUDAToolkit)`
2. Sets architectures: `75;80;86;89;90;120` (RTX 20/30/40 series, H100)
3. Searches for cuDSS (optional sparse solver library):
   - Windows: `C:\Program Files\NVIDIA cuDSS\v*/`
   - Linux: `/usr/local/cuda/`, `/opt/nvidia/cudss/`, `$CUDSS_ROOT`
4. Exports cuDSS paths to subprojects via `CMAKE_PREFIX_PATH` and environment variables

**cuDSS Detection:**
- Version-specific lib directory: `lib/12/cudss.lib` for CUDA 12.x
- Auto-detects CUDA major version and searches for matching cuDSS libs
- Falls back gracefully if not found (2-5x performance loss for sparse solvers)

### Build Output Structure

```
build/
├── install/                    # All installation outputs
│   ├── ceres/                 # Ceres Solver
│   ├── colmap/                # COLMAP (latest) - general use
│   ├── colmap-for-pycolmap/   # COLMAP - for Python wheels (optional)
│   ├── colmap-for-glomap/     # COLMAP 3.11 - for GLOMAP
│   ├── poselib/               # PoseLib
│   └── glomap/                # GLOMAP
├── vcpkg_installed/           # Shared vcpkg dependencies
├── ceres/                     # Ceres build directory
├── colmap/                    # COLMAP build directory
├── colmap-pycolmap/           # COLMAP-for-pycolmap build directory (optional)
├── colmap-g/                  # COLMAP-for-GLOMAP build directory
├── poselib/                   # PoseLib build directory
└── glomap/                    # GLOMAP build directory
```

## Important CMake Flags

### For Manual Builds
```bash
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=../third_party/vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DVCPKG_OVERLAY_PORTS=../overlay-ports \
  -DGFLAGS_USE_TARGET_NAMESPACE=ON \  # Required to fix gflags/glog linking
  -DCUDA_ENABLED=ON \
  -DCMAKE_CUDA_ARCHITECTURES="75;80;86;89;90;120" \
  -DBUILD_COLMAP=ON \
  -DBUILD_COLMAP_FOR_PYCOLMAP=OFF \
  -DBUILD_GLOMAP=ON \
  -DBUILD_CERES=ON
```

**Critical Flag:**
- `-DGFLAGS_USE_TARGET_NAMESPACE=ON` - **Required** to avoid `cannot open input file 'gflags.lib'` errors
  - See docs/GFLAGS_FIX.md for technical details
  - This is automatically set by all build scripts

### Per-Component Options

**Ceres:**
- Uses `USE_CUDA=default` (not `CUDA_ENABLED`)
- Auto-detects cuDSS via `cudss_DIR`
- Patched for CUDA architecture 120 via `cmake/patch_ceres_arch.cmake`

**COLMAP:**
- `CUDA_ENABLED=ON/OFF`
- `GUI_ENABLED=OFF` for colmap-for-pycolmap and colmap-for-glomap
- `CGAL_ENABLED=OFF` for colmap-for-glomap
- `TESTS_ENABLED=OFF` for colmap-for-pycolmap and colmap-for-glomap
- Uses Ceres via `CMAKE_PREFIX_PATH`

**GLOMAP:**
- Requires PoseLib and COLMAP 3.11
- Built as separate CMake invocation after dependencies install
- See build scripts for GLOMAP orchestration

## Known Issues & Fixes

### gflags/glog Linking Errors
**Symptom:** `LINK : fatal error LNK1181: cannot open input file 'gflags.lib'`

**Fix:** Already applied in all build scripts via `-DGFLAGS_USE_TARGET_NAMESPACE=ON`

**Root Cause:** vcpkg's gflags uses target namespace `gflags::gflags`, but COLMAP/GLOMAP expect `gflags`. The flag enables a compatibility mode.

### vcpkg Conflicts
**Symptom:** System vcpkg interfering with local vcpkg

**Fix:**
```powershell
# Windows
$env:VCPKG_ROOT = $null
$env:VCPKG_INSTALLATION_ROOT = $null

# Linux
unset VCPKG_ROOT
unset VCPKG_INSTALLATION_ROOT
```

Build scripts automatically warn if system vcpkg env vars are set.

### cuDSS Runtime on Windows
**Symptom:** `cudss.dll not found` at runtime

**Fix:** Add cuDSS bin directory to PATH:
```powershell
$env:PATH = "C:\Program Files\NVIDIA cuDSS\v0.3.0\bin;$env:PATH"
```

Or copy DLL to executable directory. See docs/INSTALL_CUDSS.md

## Development Workflow

### Automatic Submodule Initialization
All build scripts (`build.ps1`, `build_colmap.ps1`, `build_glomap.ps1`) automatically:
1. Check if required submodules are initialized (by checking for `.git` directory)
2. Run `git submodule update --init --recursive <path>` for any missing submodules
3. Bootstrap vcpkg if `vcpkg.exe` doesn't exist

This means users can:
- Clone the repo and immediately run a build script without manual initialization
- Build scripts are self-contained and handle their own dependencies
- No need to remember which submodules are needed for which build

**Submodule Requirements:**
- `build_colmap.ps1`: vcpkg, ceres-solver, colmap
- `build_glomap.ps1`: vcpkg, ceres-solver, poselib, colmap-for-glomap, glomap
- `build.ps1`: Initializes submodules based on `-SkipColmap` and `-SkipGlomap` flags
- For colmap-for-pycolmap: manually initialize with `git submodule update --init --recursive third_party/colmap-for-pycolmap`

### Modifying Build Scripts
- **Windows scripts:** `scripts_windows/*.ps1`
- **Linux scripts:** `scripts_linux/*.sh`
- Keep parity between Windows/Linux versions
- Always test both Debug and Release configurations
- Ensure submodule initialization logic is maintained in new build scripts

### Adding vcpkg Dependencies
1. Edit `vcpkg.json` to add dependency
2. If CUDA-specific, add to `features.cuda.dependencies`
3. Test with `-Clean` flag to ensure fresh build works

### Patching Dependencies
Use `overlay-ports/` for vcpkg port modifications:
- Example: `overlay-ports/suitesparse/portfile.cmake` adds CUDA support
- Overlays are automatically applied via `VCPKG_OVERLAY_PORTS` CMake variable

### Testing Builds
```powershell
# Full clean rebuild (Windows)
.\scripts_windows\build.ps1 -Clean -Configuration Release

# Test without CUDA
.\scripts_windows\build.ps1 -NoCuda

# Test individual components
.\scripts_windows\build_colmap.ps1 -Clean
.\scripts_windows\build_glomap.ps1 -Clean
```

### Updating Submodules
```bash
# Update all submodules to latest commits
git submodule update --remote --recursive

# Update specific submodule
cd third_party/colmap
git checkout main
git pull
cd ../..
git add third_party/colmap
git commit -m "Update COLMAP to latest"
```

**Warning:** Updating COLMAP for GLOMAP may break compatibility. Check `docs/GLOMAP_COLMAP_VERSION.md` first.

### Creating Release Packages

The project includes scripts to package and release builds:

**Step 1: Build Components**
```powershell
# Build COLMAP 3.14 dev
.\scripts_windows\build_colmap.ps1

# Build GLOMAP (includes COLMAP 3.11)
.\scripts_windows\build_glomap.ps1

# Build pycolmap wheels (optional)
.\scripts_windows\build_pycolmap_wheels.ps1
```

**Step 2: Create Release Packages**
```powershell
# Package everything into zip files
.\scripts_windows\create_release_packages.ps1
```

This creates in `releases/`:
- `COLMAP-3.13-dev-Windows-x64-CUDA.zip` - COLMAP 3.14 dev from `build/install/colmap/`
- `GLOMAP-Windows-x64-CUDA.zip` - GLOMAP (self-contained with COLMAP 3.11) from `build/install/glomap/`
- Copies `pycolmap-*.whl` files from `third_party/colmap-for-pycolmap/wheelhouse/`

**Step 3: Create GitHub Release**
```powershell
# Authenticate with GitHub CLI (first time only)
gh auth login

# Create and upload release
.\scripts_windows\create_github_release.ps1
```

**Release Strategy:**
- **COLMAP 3.14 dev** - Latest development version for general use
- **GLOMAP** - Self-contained with COLMAP 3.11 bundled for compatibility
- **pycolmap wheels** - Built from COLMAP 3.14 dev, one wheel per Python version

Users don't need both COLMAP packages - each is self-contained:
- Use COLMAP 3.14 dev for latest features
- Use GLOMAP for fast global SfM (includes its own COLMAP 3.11)

## Documentation Reference

- **BUILD_ANALYSIS.md** - Detailed build system architecture analysis
- **BUILD_PYTHON_WHEELS.md** - PyColmap wheel building guide
- **GLOMAP_COLMAP_VERSION.md** - COLMAP version compatibility for GLOMAP
- **GFLAGS_FIX.md** - Technical details on gflags namespace fix
- **INSTALL_CUDSS.md** - cuDSS installation guide
- **CUDSS_DETECTION.md** - How cuDSS detection works in CMake

## Environment Requirements

### Windows
- Visual Studio 2022 or Build Tools with "Desktop development with C++" workload
- CMake 3.28+
- Git
- Python 3.8+ (for pycolmap)
- CUDA Toolkit 11.0+ (optional, for GPU acceleration)
- cuDSS (optional, provides 2-5x sparse solver speedup)

**Run from:** Developer Command Prompt for VS 2022 or Developer PowerShell for VS 2022

### Linux
- GCC 9+ or Clang 10+
- CMake 3.28+
- Git
- Python 3.8+ (for pycolmap)
- CUDA Toolkit 11.0+ (optional)
- Standard build tools: `build-essential`

## Performance Optimization

**Binary Caching:**
```powershell
# Windows
$env:VCPKG_DEFAULT_BINARY_CACHE = "C:\vcpkg-cache"

# Linux
export VCPKG_DEFAULT_BINARY_CACHE=$HOME/vcpkg-cache
```

Saves significant time on rebuilds by caching vcpkg package builds.

**Parallel Builds:**
- Build scripts automatically use `--parallel` for CMake builds
- Windows: MSBuild parallelism
- Linux: Make/Ninja with `-j$(nproc)`
