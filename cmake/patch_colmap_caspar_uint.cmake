# Patch COLMAP's generated Caspar CUDA sources for MSVC/NVCC.
# Several generated files use the non-standard uint typedef, which is
# available on Linux but not defined by MSVC's CUDA host compilation path.
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
