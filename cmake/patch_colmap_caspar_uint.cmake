# Patch COLMAP's generated Caspar sources for MSVC/NVCC.
# Several generated files use the non-standard uint typedef, which is
# available on Linux but not defined by MSVC's CUDA host compilation path.
# Generated solver.cc also uses std::to_string without including <string>,
# which MSVC does not expose through the current transitive includes.
#
# Usage: cmake -DCOLMAP_SOURCE_DIR=<path> -P patch_colmap_caspar_uint.cmake

if(NOT DEFINED COLMAP_SOURCE_DIR)
    message(FATAL_ERROR "COLMAP_SOURCE_DIR must be defined")
endif()

set(CASPAR_GENERATED_DIR "${COLMAP_SOURCE_DIR}/src/thirdparty/Symforce-Caspar/generated")

set(UINT_COMPAT_BLOCK [=[
#if defined(_MSC_VER) && !defined(CASPAR_UINT_COMPAT_DEFINED)
#define CASPAR_UINT_COMPAT_DEFINED
using uint = unsigned int;
#endif

]=])

foreach(PRECISION IN ITEMS f32 f64)
    set(PRECISION_DIR "${CASPAR_GENERATED_DIR}/${PRECISION}")

    if(NOT EXISTS "${PRECISION_DIR}")
        message(STATUS "Caspar ${PRECISION} generated directory not found - skipping uint patch")
        continue()
    endif()

    file(GLOB CASPAR_GENERATED_FILES
        "${PRECISION_DIR}/*.cu"
        "${PRECISION_DIR}/*.cuh"
        "${PRECISION_DIR}/*.h"
    )

    foreach(TARGET_FILE IN LISTS CASPAR_GENERATED_FILES)
        file(READ "${TARGET_FILE}" CONTENT)

        if(CONTENT MATCHES "CASPAR_UINT_COMPAT_DEFINED")
            message(STATUS "Caspar uint compatibility already patched in ${TARGET_FILE}")
            continue()
        endif()

        if(NOT CONTENT MATCHES "(^|[^A-Za-z0-9_])uint([^A-Za-z0-9_]|$)")
            continue()
        endif()

        string(FIND "${CONTENT}" "\nnamespace " NAMESPACE_POS)
        if(NAMESPACE_POS EQUAL -1)
            message(FATAL_ERROR "Could not find namespace insertion point in ${TARGET_FILE}")
        endif()

        math(EXPR INSERT_POS "${NAMESPACE_POS} + 1")
        string(SUBSTRING "${CONTENT}" 0 ${INSERT_POS} CONTENT_PREFIX)
        string(SUBSTRING "${CONTENT}" ${INSERT_POS} -1 CONTENT_SUFFIX)
        set(CONTENT "${CONTENT_PREFIX}${UINT_COMPAT_BLOCK}${CONTENT_SUFFIX}")

        file(WRITE "${TARGET_FILE}" "${CONTENT}")
        message(STATUS "Patched ${TARGET_FILE} to define uint for Caspar CUDA sources")
    endforeach()
endforeach()

foreach(PRECISION IN ITEMS f32 f64)
    set(SOLVER_FILE "${CASPAR_GENERATED_DIR}/${PRECISION}/solver.cc")

    if(NOT EXISTS "${SOLVER_FILE}")
        message(STATUS "Caspar ${PRECISION} solver.cc not found - skipping <string> patch")
        continue()
    endif()

    file(READ "${SOLVER_FILE}" CONTENT)

    if(NOT CONTENT MATCHES "std::to_string")
        continue()
    endif()

    if(CONTENT MATCHES "#include <string>")
        message(STATUS "Caspar ${PRECISION} solver.cc already includes <string>")
        continue()
    endif()

    if(NOT CONTENT MATCHES "#include <stdexcept>")
        message(FATAL_ERROR "Could not find '#include <stdexcept>' in ${SOLVER_FILE}")
    endif()

    string(REPLACE
        "#include <stdexcept>"
        "#include <stdexcept>\n#include <string>"
        CONTENT "${CONTENT}"
    )

    file(WRITE "${SOLVER_FILE}" "${CONTENT}")
    message(STATUS "Patched ${SOLVER_FILE} to include <string> for std::to_string")
endforeach()

# Fix MSVC CRT redefinition errors (C2011/C2953) when nvcc compiles Caspar CUDA
# sources. Upstream's msvc_compact.h (added in COLMAP #4402) is force-included
# via /FI into every Caspar TU and does `#include <string>`. Pulling <string>
# (and the MSVC CRT it drags in) into nvcc's host/cudafe pass double-defines the
# CRT under MSVC 14.44 / Windows SDK 10.0.26100, breaking every Windows CUDA
# Caspar build. Guard the <string> include to host compilation only so .cu files
# (nvcc, __CUDACC__ defined) skip it; host .cc files (e.g. solver.cc) keep it,
# and solver.cc also gets <string> from the patch above.
set(MSVC_COMPACT_FILE "${COLMAP_SOURCE_DIR}/src/thirdparty/Symforce-Caspar/msvc_compact.h")
if(EXISTS "${MSVC_COMPACT_FILE}")
    file(READ "${MSVC_COMPACT_FILE}" MC_CONTENT)
    if(MC_CONTENT MATCHES "!defined\\(__CUDACC__\\)")
        message(STATUS "msvc_compact.h <string> already guarded against CUDA")
    elseif(MC_CONTENT MATCHES "#ifdef __cplusplus")
        string(REPLACE
            "#ifdef __cplusplus"
            "#if defined(__cplusplus) && !defined(__CUDACC__)"
            MC_CONTENT "${MC_CONTENT}")
        file(WRITE "${MSVC_COMPACT_FILE}" "${MC_CONTENT}")
        message(STATUS "Patched msvc_compact.h to skip <string> force-include under CUDA/nvcc")
    else()
        message(WARNING "msvc_compact.h present but no '#ifdef __cplusplus' guard found to patch")
    endif()
endif()
