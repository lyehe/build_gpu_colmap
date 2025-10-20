# vcpkg Overlay Ports

This directory contains local port overrides for vcpkg packages that require patches.

## Purpose

Overlay ports allow us to patch vcpkg packages without modifying the vcpkg submodule itself. This keeps the submodule clean and makes it easy to update vcpkg independently.

## Current Patches

### ceres

**Issue:** CUDA feature propagation through dependency chain - When Ceres's suitesparse feature is enabled, it requests suitesparse-cholmod and suitesparse-spqr without CUDA features, preventing SuiteSparse from being built with CUDA support even when the root project explicitly requests it.

**Root Cause:** vcpkg's feature resolution algorithm prioritizes direct dependency specifications over meta-package features. When Ceres directly requests suitesparse-cholmod[matrixops] and suitesparse-spqr (without cuda), this overrides the root project's request for suitesparse[cuda].

**Fix:** Modified Ceres's suitesparse feature to explicitly request CUDA features for SuiteSparse components:
- suitesparse-cholmod: Added "cuda" to features list (now ["matrixops", "cuda"])
- suitesparse-spqr: Added "cuda" to features list

**Modified Files:**
- `ceres/vcpkg.json` - Lines 54-63: Add cuda features to suitesparse dependencies
- `ceres/portfile.cmake` - Copied from baseline (no modifications)
- `ceres/*.patch` - Copied from baseline (no modifications)

**Impact:** This ensures that when Ceres is built with SuiteSparse support, the SuiteSparse libraries will inherit CUDA support if available on the platform (respecting platform support constraints defined in each component).

**Note:** Overlay ports require ALL files from the original port (portfile.cmake, patches, etc.), not just the modified vcpkg.json. The portfile.cmake and patch files are copied from the baseline vcpkg port without modifications.

### suitesparse-spqr and suitesparse-cholmod

**Issue:** vcpkg bug #44797 - CMAKE_CUDA_ARCHITECTURES is empty when building with CUDA support, causing build failures.

**Fix:** Set default CUDA architectures to support modern NVIDIA GPUs:
- 75: Turing (RTX 20xx, GTX 16xx)
- 80: Ampere (A100 data center)
- 86: Ampere (RTX 30xx GeForce)
- 89: Ada Lovelace (RTX 40xx)
- 90: Hopper (H100 data center)
- 120: Blackwell (RTX 50xx)

**Modified Files:**
- `suitesparse-spqr/portfile.cmake` - Lines 27-32: Add CUDA_ARCHITECTURES default
- `suitesparse-cholmod/portfile.cmake` - Lines 35-40: Add CUDA_ARCHITECTURES default

## How It Works

The CMakeLists.txt sets `VCPKG_OVERLAY_PORTS` to point to this directory before calling `project()`. When vcpkg resolves package names, it checks overlay ports first, so our patched versions take priority over the baseline vcpkg registry.

## Updating Patches

If vcpkg is updated and these patches are no longer needed (or need to be updated):

1. Check if the issue is fixed upstream in vcpkg
2. Update the portfile.cmake files in this directory as needed
3. Test the build to ensure it works
4. Update this README with any changes

## References

- vcpkg overlay-ports documentation: https://learn.microsoft.com/en-us/vcpkg/users/examples/overlay-ports-versioning
- vcpkg issue #44797: https://github.com/microsoft/vcpkg/issues/44797
