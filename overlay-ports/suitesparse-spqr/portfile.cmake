vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO DrTimothyAldenDavis/SuiteSparse
    REF v7.8.3
    SHA512 fc0fd0aaf55a6712a3b8ca23bf7536a31d52033e090370ebbf291f05d0e073c7dcfd991a80b037f54663f524804582b87af86522c2e4435091527f0d3c189244
    HEAD_REF dev
    PATCHES
        001-dont-override-cuda-architectures.patch
)

set(PACKAGE_NAME SPQR)

configure_file(
    "${CURRENT_INSTALLED_DIR}/share/suitesparse/SuiteSparseBLAS.cmake"
    "${SOURCE_PATH}/SuiteSparse_config/cmake_modules/SuiteSparseBLAS.cmake"
    COPYONLY
)

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "static" BUILD_STATIC_LIBS)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        cuda  SPQR_USE_CUDA
        cuda  SUITESPARSE_USE_CUDA
)

# Fix for empty CUDA_ARCHITECTURES - use common architectures supported by CUDA 12+
# Avoids architecture 120 (Blackwell) which requires CUDA 13+
if("cuda" IN_LIST FEATURES)
    if(NOT CUDA_ARCHITECTURES)
        set(CUDA_ARCHITECTURES "75;80;86;89;90")  # Turing, Ampere, Ada Lovelace, Hopper
    endif()
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/${PACKAGE_NAME}"
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        -DBUILD_STATIC_LIBS=${BUILD_STATIC_LIBS}
        -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES}
        -DSUITESPARSE_USE_STRICT=ON
        -DSUITESPARSE_USE_FORTRAN=OFF
        -DSUITESPARSE_DEMOS=OFF
        ${FEATURE_OPTIONS}
)

vcpkg_cmake_install()

if("cuda" IN_LIST FEATURES)
    if(EXISTS "${CURRENT_PACKAGES_DIR}/lib/cmake/SuiteSparse_GPURuntime")
        vcpkg_cmake_config_fixup(
            PACKAGE_NAME SuiteSparse_GPURuntime
            CONFIG_PATH lib/cmake/SuiteSparse_GPURuntime
            DO_NOT_DELETE_PARENT_CONFIG_PATH
        )
    endif()
    if(EXISTS "${CURRENT_PACKAGES_DIR}/lib/cmake/GPUQREngine")
        vcpkg_cmake_config_fixup(
            PACKAGE_NAME GPUQREngine
            CONFIG_PATH lib/cmake/GPUQREngine
            DO_NOT_DELETE_PARENT_CONFIG_PATH
        )
    endif()
endif()
vcpkg_cmake_config_fixup(
    PACKAGE_NAME ${PACKAGE_NAME}
    CONFIG_PATH lib/cmake/${PACKAGE_NAME}
)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

# When CUDA is enabled, SPQR requires GPUQREngine and SuiteSparse_GPURuntime at link time
# Modify the SPQR CMake config to automatically find and link these dependencies
if("cuda" IN_LIST FEATURES)
    set(SPQR_CONFIG_FILE "${CURRENT_PACKAGES_DIR}/share/${PACKAGE_NAME}/${PACKAGE_NAME}Config.cmake")
    if(EXISTS "${SPQR_CONFIG_FILE}")
        file(READ "${SPQR_CONFIG_FILE}" SPQR_CONFIG_CONTENT)

        # Check if already patched
        if(NOT SPQR_CONFIG_CONTENT MATCHES "GPUQREngine")
            # Add GPU dependency discovery after the existing content
            string(APPEND SPQR_CONFIG_CONTENT "
# CUDA GPU support - SPQR GPU kernels require GPUQREngine and SuiteSparse_GPURuntime
# These libraries provide the Workspace class and GPU QR factorization kernels
find_package(SuiteSparse_GPURuntime CONFIG QUIET)
find_package(GPUQREngine CONFIG QUIET)

# Add GPU libraries to SPQR target if available
if(TARGET SPQR::SPQR)
    if(TARGET SuiteSparse_GPURuntime::SuiteSparse_GPURuntime)
        set_property(TARGET SPQR::SPQR APPEND PROPERTY
            INTERFACE_LINK_LIBRARIES SuiteSparse_GPURuntime::SuiteSparse_GPURuntime)
    endif()
    if(TARGET GPUQREngine::GPUQREngine)
        set_property(TARGET SPQR::SPQR APPEND PROPERTY
            INTERFACE_LINK_LIBRARIES GPUQREngine::GPUQREngine)
    endif()
endif()
")
            file(WRITE "${SPQR_CONFIG_FILE}" "${SPQR_CONFIG_CONTENT}")
            message(STATUS "Patched SPQRConfig.cmake to include GPU runtime dependencies")
        endif()
    endif()
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/${PACKAGE_NAME}/Doc/License.txt")
