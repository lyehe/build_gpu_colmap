# Patch COLMAP's generated Caspar CUDA headers for MSVC/NVCC.
# The generated memops.cuh uses the non-standard uint typedef, which is
# available on Linux but not defined by MSVC's CUDA host compilation path.
#
# Usage: cmake -DCOLMAP_SOURCE_DIR=<path> -P patch_colmap_caspar_uint.cmake

if(NOT DEFINED COLMAP_SOURCE_DIR)
    message(FATAL_ERROR "COLMAP_SOURCE_DIR must be defined")
endif()

foreach(PRECISION IN ITEMS f32 f64)
    set(MEMOPS_FILE "${COLMAP_SOURCE_DIR}/src/thirdparty/Symforce-Caspar/generated/${PRECISION}/memops.cuh")

    if(NOT EXISTS "${MEMOPS_FILE}")
        message(STATUS "Caspar ${PRECISION} memops.cuh not found - skipping uint patch")
        continue()
    endif()

    file(READ "${MEMOPS_FILE}" CONTENT)

    if(CONTENT MATCHES "using uint = unsigned int;" OR
       CONTENT MATCHES "typedef unsigned int uint;")
        message(STATUS "Caspar ${PRECISION} memops.cuh already defines uint")
        continue()
    endif()

    if(NOT CONTENT MATCHES "namespace caspar \\{")
        message(FATAL_ERROR "Could not find 'namespace caspar {' in ${MEMOPS_FILE}")
    endif()

    string(REPLACE
        "namespace caspar {"
        "namespace caspar {\n\nusing uint = unsigned int;"
        CONTENT "${CONTENT}"
    )

    file(WRITE "${MEMOPS_FILE}" "${CONTENT}")
    message(STATUS "Patched ${MEMOPS_FILE} to define uint for Caspar CUDA sources")
endforeach()
