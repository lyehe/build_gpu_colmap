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

### suitesparse-spqr and suitesparse-cholmod (removed)

The former overlays for vcpkg bug #44797 (CUDA architecture override) were
removed when the vcpkg baseline was bumped: upstream vcpkg now ships the same
`001-dont-override-cuda-architectures.patch` in its own suitesparse-cholmod
and suitesparse-spqr ports, so the baseline ports are used directly.

A `gmp` overlay existed briefly (2026-08-20/21) to replace an MSYS2 autoconf
package that had been rotated out of the MSYS2 repositories; it was likewise
removed when the baseline bump picked up upstream's corrected pin.

### openblas

**Issue:** OpenBLAS is compiled for the CPU of whichever machine happens to run the build, which caused two distinct problems on shared CI runners:

1. **Intermittent build failures.** Linux pycolmap jobs failed at `vcpkg install` with:
   ```
   error: inlining failed in call to 'always_inline'
          '_mm512_castps512_ps128': target specific option mismatch
   ```
   Identical configurations passed or failed depending only on which runner they landed on.

2. **Non-portable artifacts.** Wheels built on an AVX-512 runner can execute AVX-512 instructions on a user's older CPU and die with `SIGILL`. This shipped silently — nothing fails at build time when the flags happen to line up.

**Root Cause:** On a native build the port runs OpenBLAS's `getarch`, which probes the build host's CPU and writes `HAVE_AVX512VL` / `HAVE_AVX512BF16` into `config.h`. `kernel/simd/intrin.h` includes `intrin_avx512.h` based solely on those defines:

```c
#if defined(HAVE_AVX512VL) || defined(HAVE_AVX512BF16)
#include "intrin_avx512.h"
```

but no matching `-mavx512*` flag is added for the generic kernels. GCC declares every `_mm512_*` intrinsic as `target("avx512f")` + `always_inline`, and inlining one into a caller lacking that target option is a hard error rather than a fallback. Confirmed against the failing job log: `-mavx512` appears zero times in the entire build.

**Fix:** Force `TARGET`, which makes `getarch` run with `-DFORCE_<TARGET>` instead of probing, so `config.h` is byte-identical on every runner. Both platforms are pinned, but they get different baselines because runtime dispatch is only available on one of them:

| Platform | `TARGET` | Dispatch | Rationale |
| --- | --- | --- | --- |
| Linux | `PRESCOTT` | `DYNAMIC_ARCH` builds every kernel variant and selects on the user's CPU at runtime | The pinned baseline only floors common/driver code, so no kernel performance is lost |
| Windows | `NEHALEM` (SSE4.2, 2008+) | none available | `dynamic-arch` is `"supports": "!windows | mingw"` and cannot be enabled under MSVC, since OpenBLAS's dispatch kernels rely on GCC-style assembly |

Windows therefore trades peak dense-kernel throughput for a deterministic, portable binary. That trade is cheap in this project: COLMAP and Ceres perform most vectorised linear algebra through Eigen, whose SIMD selection is independent of OpenBLAS's `TARGET`; OpenBLAS here mainly backs LAPACK for SuiteSparse/Ceres. Raise the Windows baseline to `HASWELL` (AVX2, 2013+) if an AVX2 floor is acceptable for your users and faster dense kernels are wanted — it is a one-line change in the portfile.

**Modified Files:**
- `openblas/portfile.cmake` - Adds `-DTARGET=PRESCOTT` (non-Windows x64) and `-DTARGET=NEHALEM` (Windows x64)
- `openblas/vcpkg.json` - `port-version: 2` (forces an ABI change so stale binary-cache entries are not reused)
- `../vcpkg.json` - Requests `openblas[dynamic-arch]` gated to `!windows`

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
