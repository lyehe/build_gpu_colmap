# GLOMAP CI Debug Log

## Summary
Tracking debug efforts for GLOMAP CI build failures.

---

## Attempt 1: Initial Fixes (Commit 3441086b)
**Date:** 2026-01-18

### Changes:
- `patch_colmap_flann.cmake`: Replace FindFLANN.cmake with vcpkg-compatible version
- `overlay-ports/suitesparse-spqr`: Add GPU runtime dependencies to SPQRConfig.cmake
- `.github/workflows/build-glomap.yml`: Change CUDA to 'local' method

### Results: FAILED
- Linux CPU: Still `-lflann` error
- Linux CUDA: Still GPUQREngine undefined symbols
- Windows CUDA13: Still missing headers

---

## Attempt 2: Swap Dependency Order (Commit 32b6072d)
**Date:** 2026-01-19

### Changes:
- Created `patch_colmap_config.cmake`: Swap include order in colmap-config.cmake.in
- Added `flann_DIR` to build scripts

### Results: FAILED
- Same errors persisted
- Root cause: Order swap doesn't fix export serialization issue

---

## Attempt 3: Extract Full Library Path (Commit 9759643a)
**Date:** 2026-01-19

### Changes:
- `patch_colmap_flann.cmake` v2: Extract IMPORTED_LOCATION from vcpkg target
- Use full path `/path/to/libflann_cpp_s.a` instead of target name
- Removed `suitesparse[cuda]` from vcpkg.json

### Results: PARTIALLY FAILED
- **FIXED**: GPUQREngine undefined symbols (SuiteSparse CUDA removal worked)
- **FAILED**: FLANN still shows `-lflann` in linker command

### Root Cause Analysis:
The patch correctly extracts and sets the library path during COLMAP build:
```
-- Library path: /home/.../libflann_cpp_s.a
```

But when COLMAP exports targets via `install(EXPORT ...)`, the `flann` target reference gets serialized as `-lflann` in `colmap-targets.cmake`. This is what GLOMAP consumes.

**Key insight**: The issue is NOT in FindFLANN.cmake during COLMAP build. It's in how CMake exports the target for downstream consumption.

---

## Current Status

### Working:
- Windows CPU builds pass
- SuiteSparse CUDA removal eliminated GPUQREngine errors

### Still Failing:
- All Linux: `-lflann` linker error
- Linux CUDA12.8: Additional disk space issue
- Windows CUDA: `cuda_fp16.h` extern "C" linkage errors (CUDA toolkit bug)

### Next Steps to Try:
1. Patch COLMAP's generated `colmap-targets.cmake` after install to replace `flann` reference
2. Or: Make GLOMAP find FLANN independently before loading COLMAP
3. Or: Patch COLMAP source to use `${FLANN_LIBRARIES}` variable instead of `flann` target

---

## What Doesn't Work

| Approach | Why It Failed |
|----------|---------------|
| Replace FindFLANN.cmake with vcpkg target | Target name gets serialized as `-lflann` in export |
| Swap dependency load order | Doesn't affect export serialization |
| Extract IMPORTED_LOCATION to full path | CMake export still produces `-lflann` |
| SuiteSparse GPU patching | GPUQREngine libs not built by vcpkg |

## Key Learnings
1. CMake's `install(EXPORT)` doesn't preserve INTERFACE IMPORTED targets' link libraries as paths
2. vcpkg's FLANN exports as `flann::flann_cpp_s`, not `flann`
3. COLMAP expects a target named `flann` and exports it in `colmap-targets.cmake`
4. The `-lflann` comes from the exported cmake files, not from FindFLANN.cmake at build time

---

## Attempt 4: Patch COLMAP CMakeLists to use FLANN_LIBRARIES variable (Pending)
**Date:** 2026-01-19

### Changes:
- Created `patch_colmap_flann_link.cmake`: Replace `flann` target with `${FLANN_LIBRARIES}` variable
- Added patch to CMakeLists.txt ExternalProject PATCH_COMMAND

### Theory:
Using a CMake variable instead of a target avoids the export serialization issue.
The `${FLANN_LIBRARIES}` variable contains the full library path set by FindFLANN.cmake.

### Results: PARTIAL SUCCESS
- **FIXED**: The `-lflann` error is gone
- **NEW ERROR**: METIS/GKlib linking order issue

### New Error:
```
/usr/bin/ld: libmetis.a(ometis.c.o): undefined reference to `gk_CPUSeconds'
/usr/bin/ld: libmetis.a(ometis.c.o): undefined reference to `gk_malloc'
/usr/bin/ld: libmetis.a(ometis.c.o): undefined reference to `gk_sigtrap'
```

### Root Cause:
1. METIS depends on GKlib
2. Linker command has `libmetis.a` appearing twice
3. First occurrence: `libmetis.a libGKlib.a` (correct)
4. Second occurrence (from SuiteSparse/CHOLMOD): `libmetis.a libcholmod.a` (missing GKlib)
5. The second occurrence causes undefined reference errors

---

## Attempt 5: Fix METIS/GKlib linking - CMAKE_EXE_LINKER_FLAGS
**Date:** 2026-01-19

### Solution attempted:
Add `-lGKlib` to CMAKE_EXE_LINKER_FLAGS

### Result: FAILED
- The flag was added but at the BEGINNING of the linker command
- CMake puts CMAKE_EXE_LINKER_FLAGS before object files
- GKlib symbols not resolved because METIS comes after in link order

---

## Attempt 6: Patch GLOMAP to add GKlib to target_link_libraries
**Date:** 2026-01-19

### Solution:
Created `cmake/patch_glomap_gklib.cmake` that adds GKlib to glomap_main

### Result: FAILED
- GKlib was added but still in wrong position
- CMake adds libraries in order they're specified, but transitive deps still come after
- GKlib needs to be linked BEFORE METIS in the resolve order

---

## Attempt 7: Use --whole-archive for GKlib - SUCCESS!
**Date:** 2026-01-19

### Solution:
Modified patch to use `--whole-archive`:
```cmake
target_link_libraries(glomap_main -Wl,--whole-archive ${GKLIB_LIBRARY} -Wl,--no-whole-archive)
```

### Results: SUCCESS!
- **Linux CPU: PASSED**
- **Linux CUDA13.1: PASSED**
- Linux CUDA13.0: Build passed, artifact upload conflict (workflow issue)
- Linux CUDA12.8: Disk space exhaustion (CI runner issue)

### Additional Fixes:
1. Added CUDA version to artifact names to avoid conflicts
2. Added disk cleanup step for Linux to free ~25GB before build

---

---

## Attempt 8: CUDA 13.x Thrust C++17 Compatibility
**Date:** 2026-01-19

### Issue:
Windows CUDA 13.x builds fail with:
```
Thrust requires at least C++17. Define CCCL_IGNORE_DEPRECATED_CPP_DIALECT to suppress this message.
```

### Root Cause Analysis:
1. CUDA 13.x's Thrust library requires C++17 minimum
2. COLMAP-for-GLOMAP has `CMAKE_CUDA_STANDARD 14` hardcoded
3. GLOMAP doesn't explicitly set `CMAKE_CUDA_STANDARD`
4. The Thrust deprecation warning becomes a fatal error

### Solution:
Add `-DCCCL_IGNORE_DEPRECATED_CPP_DIALECT` to CMAKE_CUDA_FLAGS for CUDA 13.x builds.

### Changes:
1. `CMakeLists.txt`: Add CUDA13_THRUST_FLAGS variable after CUDA version detection
2. `CMakeLists.txt`: Pass CMAKE_CUDA_FLAGS to all ExternalProject calls (Ceres, COLMAP, COLMAP-for-GLOMAP)
3. `scripts_windows/build_glomap.ps1`: Detect CUDA version and add flag for GLOMAP build
4. `scripts_linux/build_glomap.sh`: Detect CUDA version and add flag for GLOMAP build

### Results: PENDING
- Waiting for CI run to complete

---

## Summary

| Fix | Status | Description |
|-----|--------|-------------|
| FLANN_LIBRARIES variable | SUCCESS | Replace target with full path |
| GKlib --whole-archive | SUCCESS | Force include all GKlib symbols |
| Artifact naming | Fixed | Include CUDA version in name |
| Disk space cleanup | Fixed | Remove .NET, Android SDK, etc. |
| CUDA 13.x Thrust C++17 | PENDING | Add CCCL_IGNORE_DEPRECATED_CPP_DIALECT flag |

---

---

## Attempt 9: Windows FLANN DLL vs Import Library Issue
**Date:** 2026-01-19

### Issue:
Windows builds fail with:
```
flann_cpp.dll : fatal error LNK1107: invalid or corrupt file: cannot read at 0x2F0
```

### Root Cause Analysis:
1. The FindFLANN.cmake patch extracts library path from vcpkg targets
2. On Windows shared libs, `IMPORTED_LOCATION` returns the DLL path (`.dll`)
3. But the linker needs the import library (`.lib`), not the DLL
4. The DLL was being passed to the linker, causing LNK1107 error

### Solution:
Update `patch_colmap_flann.cmake` to:
1. On Windows, prefer `IMPORTED_IMPLIB` over `IMPORTED_LOCATION`
2. Add fallback: convert `bin/foo.dll` to `lib/foo.lib` path

### Results: PENDING
- Waiting for CI run to complete

---

## Current CI Status

### Passing:
- Linux CPU
- Linux CUDA12.8
- Linux CUDA13.0
- Linux CUDA13.1

### Failing:
- Windows: FLANN DLL linking issue (fix in progress)
