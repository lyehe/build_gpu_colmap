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

# Drop the Caspar msvc_compact.h /FI force-includes entirely (both C/C++ and CUDA).
# COLMAP force-includes an external msvc_compact.h into every Caspar TU via /FI just
# to inject `uint` (used by the generated .cu/.cuh/.h) and `<string>` (used by host
# solver.cc, which does NOT use uint). That force-include is the fragile point on
# Windows: msvc_compact.h must be openable the instant cl.exe starts each TU, and it
# intermittently loses to Windows Defender ("fatal error C1083: Cannot open
# msvc_compact.h"). The per-file patches above already inject `uint` into the
# .cu/.cuh/.h and `<string>` into solver.cc, so the generated sources are
# self-contained -- the force-include is pure redundancy. Removing it (msvc_compact.h
# is never referenced) also avoids the nvcc/cudafe CRT double-definition
# (C2011/C2953) the CUDA /FI caused.
set(THIRDPARTY_CMAKE "${COLMAP_SOURCE_DIR}/src/thirdparty/CMakeLists.txt")
if(EXISTS "${THIRDPARTY_CMAKE}")
    file(READ "${THIRDPARTY_CMAKE}" TP_CONTENT)
    if(TP_CONTENT MATCHES "/FI\"[^\n]*_MSVC_COMPACT_HEADER")
        string(REGEX REPLACE
            "[^\n]*/FI\"[^\n]*_MSVC_COMPACT_HEADER[^\n]*\n"
            ""
            TP_CONTENT "${TP_CONTENT}")
        file(WRITE "${THIRDPARTY_CMAKE}" "${TP_CONTENT}")
        message(STATUS "Removed Caspar msvc_compact.h /FI force-includes; generated sources self-patched (uint + <string>)")
    else()
        message(STATUS "Caspar msvc_compact.h /FI force-include not present - skipping")
    endif()
endif()
