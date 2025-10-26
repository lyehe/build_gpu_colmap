# gflags Target Namespace Fix

## Problem

When building pycolmap wheels, the linker fails with:
```
LINK : fatal error LNK1181: cannot open input file 'gflags.lib'
```

This occurs because vcpkg's glog package was built expecting a `gflags::gflags` CMake target, but vcpkg's gflags package creates `gflags_shared` or `gflags_static` targets by default (without the namespace).

## Solution

Set the CMake cache variable `GFLAGS_USE_TARGET_NAMESPACE=ON` when building. This instructs gflags' CMake config to create the namespaced `gflags::gflags` target that glog expects.

## Implementation

The fix has been applied to both build scripts:

### 1. scripts_windows/build_colmap.ps1

Added `-DGFLAGS_USE_TARGET_NAMESPACE=ON` to both cmake commands (lines 105 and 115):

```powershell
cmake .. `
    -DCMAKE_TOOLCHAIN_FILE="$VcpkgToolchain" `
    -DCMAKE_BUILD_TYPE="$Configuration" `
    -DCUDA_ENABLED="$CudaEnabled" `
    -DBUILD_CERES=ON `
    -DBUILD_COLMAP=ON `
    -DBUILD_GLOMAP=OFF `
    -DVCPKG_MANIFEST_FEATURES="cgal" `
    -DGFLAGS_USE_TARGET_NAMESPACE=ON
```

### 2. scripts_windows/build_pycolmap_wheels.ps1

The gflags fix is now handled via the CMake patch system (`cmake/patch_colmap_gflags.cmake`) which sets `GFLAGS_USE_TARGET_NAMESPACE=ON` before COLMAP's FindDependencies is included. The unified wheel building script passes CMake configuration via `--config-settings` to scikit-build-core, ensuring proper dependency resolution.

## Technical Details

### How gflags Config Works

The gflags CMake config file (`gflags-config.cmake`) checks the `GFLAGS_USE_TARGET_NAMESPACE` variable:

```cmake
if (NOT DEFINED GFLAGS_USE_TARGET_NAMESPACE)
  set (GFLAGS_USE_TARGET_NAMESPACE FALSE)
endif ()
if (GFLAGS_USE_TARGET_NAMESPACE)
  include ("${CMAKE_CURRENT_LIST_DIR}/gflags-targets.cmake")
  set (GFLAGS_TARGET_NAMESPACE gflags)
else ()
  include ("${CMAKE_CURRENT_LIST_DIR}/gflags-nonamespace-targets.cmake")
  set (GFLAGS_TARGET_NAMESPACE)
endif ()
```

- When `FALSE` (default): Creates targets `gflags_shared`, `gflags_static`
- When `TRUE`: Creates targets `gflags::gflags`, `gflags::gflags_shared`, `gflags::gflags_static`

### Why glog Expects gflags::gflags

The vcpkg glog package was built with gflags support, and its CMake target file (`glog-targets.cmake`) hard-codes the dependency:

```cmake
set_target_properties(glog::glog PROPERTIES
  INTERFACE_LINK_LIBRARIES "gflags::gflags"
)
```

When gflags doesn't create the `gflags::gflags` target, CMake can't resolve this dependency at configuration time, but the error only manifests at link time when the linker looks for `gflags.lib` in the wrong location.

## Alternative Solutions (Not Recommended)

### Option 1: Modify COLMAP Source (REJECTED)

Modify `third_party/colmap/cmake/FindDependencies.cmake` to create an alias:

```cmake
find_package(gflags CONFIG QUIET)
if(gflags_FOUND AND NOT TARGET gflags::gflags)
  if(TARGET gflags_shared)
    add_library(gflags::gflags ALIAS gflags_shared)
  elseif(TARGET gflags_static)
    add_library(gflags::gflags ALIAS gflags_static)
  endif()
endif()
```

**Why not use this**: Requires modifying third-party source code, making updates harder.

### Option 2: Rebuild vcpkg Packages (NOT PRACTICAL)

Rebuild glog without gflags support, or rebuild both glog and gflags with matching namespace settings.

**Why not use this**: Too complex, defeats the purpose of using vcpkg.

## Verification

After applying this fix, you should see in the CMake configuration output:

```
-- Found Glog
--   Target : glog::glog
```

And the build should complete without linker errors about `gflags.lib`.

## References

- gflags CMake config: `build/vcpkg_installed/x64-windows/share/gflags/gflags-config.cmake`
- glog targets: `build/vcpkg_installed/x64-windows/share/glog/glog-targets.cmake`
