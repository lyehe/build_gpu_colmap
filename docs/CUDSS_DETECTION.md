# cuDSS Detection and Integration

This document explains how cuDSS (CUDA Direct Sparse Solver) is detected and integrated throughout the build system.

## Overview

cuDSS provides 2-5x performance improvements for sparse bundle adjustment in COLMAP/GLOMAP. The build system automatically detects cuDSS if installed and configures the build to use it.

## Detection Locations

The build system checks for cuDSS in multiple locations to maximize compatibility:

### Windows Detection

cuDSS is searched in the following order:

1. **Standalone Installation** (Recommended):
   - `C:\Program Files\NVIDIA cuDSS\v*\`
   - Detects latest version automatically
   - Checks for `include\cudss.h` and `lib\{12,13}\cudss.lib` (version-specific)

2. **CUDA Toolkit Integration**:
   - `%CUDA_PATH%\include\cudss.h`
   - `%CUDA_PATH%\lib\x64\cudss.lib`

### Linux Detection

cuDSS is searched in the following order:

1. **Environment Variable** (if set):
   - `$CUDSS_ROOT/include/cudss.h`
   - `$CUDSS_ROOT/lib64/libcudss.so` or `$CUDSS_ROOT/lib/libcudss.so`

2. **Standard CUDA Installation**:
   - `/usr/local/cuda/include/cudss.h`
   - `/usr/local/cuda/lib64/libcudss.so`
   - Also checks version-specific paths: `/usr/local/cuda-12.0/`, etc.

3. **Alternative Locations**:
   - `/opt/nvidia/cudss/`
   - `/opt/cudss/`

## CUDA Version Matching

The build system automatically matches cuDSS to your CUDA version:

- **CUDA 12.x** → Uses `lib/12/cudss.lib` (Windows) or checks CUDA 12 installation
- **CUDA 13.x** → Uses `lib/13/cudss.lib` (Windows) or checks CUDA 13 installation
- **CUDA 11.x** → Uses `lib/11/cudss.lib` (Windows) or checks CUDA 11 installation

If cuDSS is found but doesn't match your CUDA version, CMake will warn you with:
```
WARNING: cuDSS found at ... but does not have CUDA 12 support
Available cuDSS versions: [list of available versions]
```

## Integration Components

### 1. CMakeLists.txt (Root)

**Location**: `C:\Users\opsiclear\Projects\point_cloud_tools\CMakeLists.txt`

**What it does**:
- Detects cuDSS installation location
- Validates CUDA version compatibility
- Sets CMake variables for subprojects (COLMAP/GLOMAP)
- Adds cuDSS to `CMAKE_PREFIX_PATH`
- Sets `CUDSS_ROOT` environment variable
- Exports `CUDSS_INCLUDE_DIR`, `CUDSS_LIBRARY_DIR`, `CUDSS_LIBRARY`
- Configures `cudss_DIR` for `find_package(cudss)`

**Output Messages**:
```
-- cuDSS: FOUND
--   cuDSS Location: C:/Program Files/NVIDIA cuDSS/v0.7
--   cuDSS Include: C:/Program Files/NVIDIA cuDSS/v0.7/include
--   cuDSS Library: C:/Program Files/NVIDIA cuDSS/v0.7/lib/12/cudss.lib
--   cuDSS Bin (DLLs): C:/Program Files/NVIDIA cuDSS/v0.7/bin
```

### 2. Windows Verification Script

**Location**: `scripts_windows\verify_build_environment.ps1`

**What it does**:
- Checks if cuDSS is installed
- Reports cuDSS version and location
- Provides installation instructions if not found

**Output**:
```
cuDSS (CUDA Sparse Solver)    [OK] - Standalone installation (v0.7)
```

### 3. Windows Build Script

**Location**: `scripts_windows\build.ps1`

**What it does**:
- Warns if system vcpkg variables conflict
- Passes cuDSS configuration to CMake automatically

**No manual cuDSS configuration needed** - CMake handles everything.

### 4. Linux Verification Script

**Location**: `scripts_linux\verify_build_environment.sh`

**What it does**:
- Checks multiple cuDSS installation locations
- Reports cuDSS location if found
- Provides installation instructions if not found

**Output**:
```
cuDSS (CUDA Sparse Solver)    [OK] - Found at /usr/local/cuda
```

### 5. Linux Build Script

**Location**: `scripts_linux\build.sh`

**What it does**:
- Detects cuDSS installation
- Adds cuDSS to `LD_LIBRARY_PATH` for runtime
- Sets `CUDSS_ROOT` environment variable
- Provides feedback on cuDSS status

**Output**:
```
cuDSS detected at: /usr/local/cuda
Added /usr/local/cuda/lib64 to LD_LIBRARY_PATH
```

## How COLMAP/GLOMAP Find cuDSS

COLMAP and GLOMAP use CMake's `find_package(cudss)` or manual detection. Our build system provides:

1. **CMAKE_PREFIX_PATH**: Contains cuDSS installation directory
2. **cudss_DIR**: Points to cuDSS CMake config files
3. **CUDSS_ROOT**: Environment variable for manual detection
4. **CUDSS_INCLUDE_DIR / CUDSS_LIBRARY**: Explicit paths if needed

When COLMAP/GLOMAP configure, they will automatically detect and use cuDSS if available.

## Runtime Configuration

### Windows

cuDSS DLLs must be in PATH at runtime. The build system reminds you:
```
NOTE: Ensure C:\Program Files\NVIDIA cuDSS\v0.7\bin is in your PATH at runtime
```

To add permanently:
```powershell
# Add to system PATH via System Properties -> Environment Variables
# OR add to current session:
$env:PATH += ";C:\Program Files\NVIDIA cuDSS\v0.7\bin"
```

### Linux

cuDSS libraries must be in LD_LIBRARY_PATH at runtime. The build script automatically sets this during build.

For runtime, add to `~/.bashrc`:
```bash
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

## Verification Commands

### Check if cuDSS is Detected

**Windows**:
```powershell
# Run verification
.\scripts_windows\verify_build_environment.ps1

# Or check during build
.\scripts_windows\build.ps1 -Clean -Configuration Release
# Look for: "cuDSS: FOUND" in CMake output
```

**Linux**:
```bash
# Run verification
./scripts_linux/verify_build_environment.sh

# Or check during build
./scripts_linux/build.sh --clean Release
# Look for: "cuDSS: FOUND" in CMake output
```

### Manual Check

**Windows**:
```powershell
# Check installation exists
Test-Path "C:\Program Files\NVIDIA cuDSS"

# Check specific version
Test-Path "C:\Program Files\NVIDIA cuDSS\v0.7\include\cudss.h"
Test-Path "C:\Program Files\NVIDIA cuDSS\v0.7\lib\12\cudss.lib"
```

**Linux**:
```bash
# Check installation exists
ls /usr/local/cuda/include/cudss.h
ls /usr/local/cuda/lib64/libcudss.so

# Or check environment
echo $CUDSS_ROOT
```

## Troubleshooting

### cuDSS Not Found

If cuDSS is installed but not detected:

1. **Check installation location** matches expected paths above
2. **Verify CUDA version compatibility** - cuDSS version must match CUDA major version
3. **Set CUDSS_ROOT** environment variable to installation path
4. **Re-run CMake** with clean build: `--clean` flag

### Version Mismatch

If you see warnings about CUDA version mismatch:

```
WARNING: cuDSS found at ... but does not have CUDA 12 support
```

**Solution**: Download and install cuDSS version that supports your CUDA version from:
https://developer.nvidia.com/cudss-downloads

### Runtime DLL/SO Not Found

**Windows**:
```
Error: cudss64_0.dll not found
```
**Solution**: Add cuDSS bin directory to PATH:
```powershell
$env:PATH += ";C:\Program Files\NVIDIA cuDSS\v0.7\bin"
```

**Linux**:
```
Error: libcudss.so.0: cannot open shared object file
```
**Solution**: Add cuDSS lib to LD_LIBRARY_PATH:
```bash
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

## Installation Guide

See [docs/INSTALL_CUDSS.md](INSTALL_CUDSS.md) for detailed installation instructions.

## Summary

The cuDSS integration is **fully automatic**:

1. ✅ Detection works across multiple installation methods
2. ✅ CUDA version matching is automatic
3. ✅ CMake variables are set automatically
4. ✅ Verification scripts check all locations
5. ✅ Build scripts configure environment automatically
6. ✅ COLMAP/GLOMAP will find and use cuDSS automatically

**No manual configuration needed** - just install cuDSS and build!
