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

## Attempt 7: Use --whole-archive for GKlib (Pending)
**Date:** 2026-01-19

### Solution:
Modified patch to use `--whole-archive`:
```cmake
target_link_libraries(glomap_main -Wl,--whole-archive ${GKLIB_LIBRARY} -Wl,--no-whole-archive)
```

`--whole-archive` forces the linker to include ALL symbols from GKlib,
not just those referenced at that point. This bypasses the link order issue.

### Status: PENDING - commit and test
