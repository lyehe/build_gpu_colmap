cmake_minimum_required(VERSION 3.28)

# Set vcpkg toolchain file and overlay ports BEFORE project()
# The toolchain file is loaded during project() call, so these must be set first
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_SOURCE_DIR}/third_party/vcpkg/scripts/buildsystems/vcpkg.cmake" CACHE STRING "Vcpkg toolchain file")

# Force vcpkg to use local modified ports (overlay-ports)
# This allows us to patch SuiteSparse CUDA support without modifying the vcpkg submodule
set(VCPKG_OVERLAY_PORTS "${CMAKE_SOURCE_DIR}/overlay-ports" CACHE STRING "Overlay ports for local modifications")

# Enable vcpkg manifest features
# Note: VCPKG_MANIFEST_FEATURES must be set BEFORE project() to take effect
# The CUDA_ENABLED option is evaluated here to determine which vcpkg features to enable
option(CUDA_ENABLED "Enable CUDA support" ON)
if(CUDA_ENABLED)
    list(APPEND VCPKG_MANIFEST_FEATURES "cuda")
endif()

project(PointCloudTools)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Include ExternalProject module for building dependencies
include(ExternalProject)

# Options for build modules
option(BUILD_COLMAP "Build COLMAP" ON)
option(BUILD_COLMAP_FOR_PYCOLMAP "Build COLMAP for pycolmap (Python wheels)" OFF)
option(BUILD_GLOMAP "Build GLOMAP" ON)
option(BUILD_CERES "Build Ceres Solver" ON)

# CUDA configuration
if(CUDA_ENABLED)
    enable_language(CUDA)
    find_package(CUDAToolkit REQUIRED)
    # Set CUDA architectures - use FORCE to override any cached values
    # Supports Turing (75), Ampere (80, 86), Ada Lovelace (89), Hopper (90)
    # NOTE: Architecture 120 (Blackwell) requires CUDA 13+ and is excluded for CUDA 12.x compatibility
    set(CMAKE_CUDA_ARCHITECTURES "75;80;86;89;90" CACHE STRING "CUDA architectures" FORCE)

    # Determine CUDA major version for cuDSS compatibility
    # cuDSS libraries are organized by CUDA major version (11, 12, 13, etc.)
    if(CUDAToolkit_VERSION VERSION_GREATER_EQUAL "13.0")
        set(CUDSS_CUDA_VERSION "13")
    elseif(CUDAToolkit_VERSION VERSION_GREATER_EQUAL "12.0")
        set(CUDSS_CUDA_VERSION "12")
    elseif(CUDAToolkit_VERSION VERSION_GREATER_EQUAL "11.0")
        set(CUDSS_CUDA_VERSION "11")
    else()
        message(WARNING "CUDA version ${CUDAToolkit_VERSION} is older than 11.0 - cuDSS requires CUDA 11.0+")
    endif()

    # CUDA 13.x CCCL headers require C++17 (nested namespace syntax like "namespace cuda::std")
    # 1. CMAKE_CUDA_STANDARD=17 enables C++17 for NVCC device code
    # 2. CCCL_IGNORE_DEPRECATED_CPP_DIALECT suppresses the Thrust deprecation warning
    if(CUDAToolkit_VERSION VERSION_GREATER_EQUAL "13.0")
        set(CUDA13_CUDA_STANDARD "17")
        set(CUDA13_THRUST_FLAGS "-DCCCL_IGNORE_DEPRECATED_CPP_DIALECT")
        message(STATUS "CUDA 13+ detected: Setting CMAKE_CUDA_STANDARD=17 and adding Thrust C++ dialect suppression flag")
    else()
        set(CUDA13_CUDA_STANDARD "")
        set(CUDA13_THRUST_FLAGS "")
    endif()

    # Force consistent CUDA runtime linkage to avoid static/dynamic conflicts on Windows
    # Without this, some components may link cudart_static.lib while others use cudart.lib
    # causing duplicate symbol errors (LNK2005)
    set(CMAKE_CUDA_RUNTIME_LIBRARY "Shared")
    message(STATUS "Setting CMAKE_CUDA_RUNTIME_LIBRARY=Shared for consistent CUDA runtime linkage")

    message(STATUS "CUDA Toolkit Version: ${CUDAToolkit_VERSION}")
    message(STATUS "Looking for cuDSS for CUDA ${CUDSS_CUDA_VERSION}")

    # Try to find cuDSS installation
    set(CUDSS_FOUND FALSE)
    set(CUDSS_INSTALL_PATH "")

    # Check standard cuDSS installation locations
    if(WIN32)
        # Windows: Check Program Files for cuDSS installation
        # Check both Program Files and Program Files (x86)
        # Note: ProgramW6432 points to 64-bit Program Files on 64-bit Windows
        set(CUDSS_SEARCH_PATHS
            "$ENV{ProgramW6432}/NVIDIA cuDSS"
            "$ENV{ProgramFiles}/NVIDIA cuDSS"
            "C:/Program Files/NVIDIA cuDSS"
        )

        set(CUDSS_VERSIONS "")
        foreach(SEARCH_PATH IN LISTS CUDSS_SEARCH_PATHS)
            file(TO_CMAKE_PATH "${SEARCH_PATH}" SEARCH_PATH_NORM)
            message(STATUS "Searching for cuDSS in: ${SEARCH_PATH_NORM}")
            file(GLOB FOUND_VERSIONS "${SEARCH_PATH_NORM}/v*")
            if(FOUND_VERSIONS)
                list(APPEND CUDSS_VERSIONS ${FOUND_VERSIONS})
            endif()
        endforeach()

        message(STATUS "Found cuDSS versions: ${CUDSS_VERSIONS}")
        if(CUDSS_VERSIONS)
            list(SORT CUDSS_VERSIONS)
            list(REVERSE CUDSS_VERSIONS)  # Get latest version
            list(GET CUDSS_VERSIONS 0 CUDSS_INSTALL_PATH)
            message(STATUS "Selected cuDSS path: ${CUDSS_INSTALL_PATH}")

            # Check if required files exist
            if(EXISTS "${CUDSS_INSTALL_PATH}/include/cudss.h")
                message(STATUS "Found cudss.h in ${CUDSS_INSTALL_PATH}/include")
                # Check for lib file in version-specific directory matching our CUDA version
                set(CUDSS_LIB_PATH "${CUDSS_INSTALL_PATH}/lib/${CUDSS_CUDA_VERSION}/cudss.lib")
                message(STATUS "Checking for cuDSS library at: ${CUDSS_LIB_PATH}")
                if(EXISTS "${CUDSS_LIB_PATH}")
                    set(CUDSS_FOUND TRUE)
                    set(CUDSS_INCLUDE_DIR "${CUDSS_INSTALL_PATH}/include")
                    set(CUDSS_LIBRARY_DIR "${CUDSS_INSTALL_PATH}/lib/${CUDSS_CUDA_VERSION}")
                    set(CUDSS_LIBRARY "${CUDSS_LIBRARY_DIR}/cudss.lib")
                    message(STATUS "cuDSS library found!")
                else()
                    # Check what CUDA versions are available in cuDSS installation
                    file(GLOB CUDSS_AVAILABLE_VERSIONS "${CUDSS_INSTALL_PATH}/lib/[0-9]*")
                    message(STATUS "cuDSS lib not found at expected location")
                    message(STATUS "Available cuDSS library directories: ${CUDSS_AVAILABLE_VERSIONS}")
                    if(CUDSS_AVAILABLE_VERSIONS)
                        message(WARNING "cuDSS found at ${CUDSS_INSTALL_PATH} but does not have CUDA ${CUDSS_CUDA_VERSION} support")
                        message(WARNING "Available cuDSS versions: ${CUDSS_AVAILABLE_VERSIONS}")
                        message(WARNING "Current CUDA Toolkit: ${CUDAToolkit_VERSION} (requires cuDSS for CUDA ${CUDSS_CUDA_VERSION})")
                    endif()
                endif()
            else()
                message(STATUS "cudss.h not found in ${CUDSS_INSTALL_PATH}/include")
            endif()
        else()
            message(STATUS "No cuDSS installations found in Program Files")
        endif()

        # Fallback: Check CUDA Toolkit directory
        if(NOT CUDSS_FOUND AND CUDAToolkit_INCLUDE_DIRS)
            if(EXISTS "${CUDAToolkit_INCLUDE_DIRS}/cudss.h" AND
               EXISTS "${CUDAToolkit_LIBRARY_DIR}/cudss.lib")
                set(CUDSS_FOUND TRUE)
                set(CUDSS_INCLUDE_DIR "${CUDAToolkit_INCLUDE_DIRS}")
                set(CUDSS_LIBRARY_DIR "${CUDAToolkit_LIBRARY_DIR}")
                set(CUDSS_LIBRARY "${CUDAToolkit_LIBRARY_DIR}/cudss.lib")
                set(CUDSS_INSTALL_PATH "${CUDAToolkit_ROOT}")
            endif()
        endif()
    else()
        # Linux: Check multiple possible installation locations

        # 1. Check if CUDSS_ROOT environment variable is set
        if(DEFINED ENV{CUDSS_ROOT} AND EXISTS "$ENV{CUDSS_ROOT}/include/cudss.h")
            if(EXISTS "$ENV{CUDSS_ROOT}/lib64/libcudss.so" OR EXISTS "$ENV{CUDSS_ROOT}/lib/libcudss.so")
                set(CUDSS_FOUND TRUE)
                set(CUDSS_INSTALL_PATH "$ENV{CUDSS_ROOT}")
                set(CUDSS_INCLUDE_DIR "${CUDSS_INSTALL_PATH}/include")
                if(EXISTS "${CUDSS_INSTALL_PATH}/lib64/libcudss.so")
                    set(CUDSS_LIBRARY_DIR "${CUDSS_INSTALL_PATH}/lib64")
                    set(CUDSS_LIBRARY "${CUDSS_LIBRARY_DIR}/libcudss.so")
                else()
                    set(CUDSS_LIBRARY_DIR "${CUDSS_INSTALL_PATH}/lib")
                    set(CUDSS_LIBRARY "${CUDSS_LIBRARY_DIR}/libcudss.so")
                endif()
            endif()
        endif()

        # 2. Check standard CUDA installation directory
        if(NOT CUDSS_FOUND)
            set(CUDA_PATHS
                "/usr/local/cuda"
                "/usr/local/cuda-${CUDAToolkit_VERSION_MAJOR}.${CUDAToolkit_VERSION_MINOR}"
                "/usr/local/cuda-${CUDAToolkit_VERSION_MAJOR}"
                "${CUDAToolkit_TARGET_DIR}"
            )

            foreach(CUDA_PATH IN LISTS CUDA_PATHS)
                if(EXISTS "${CUDA_PATH}/include/cudss.h")
                    if(EXISTS "${CUDA_PATH}/lib64/libcudss.so")
                        set(CUDSS_FOUND TRUE)
                        set(CUDSS_INSTALL_PATH "${CUDA_PATH}")
                        set(CUDSS_INCLUDE_DIR "${CUDA_PATH}/include")
                        set(CUDSS_LIBRARY_DIR "${CUDA_PATH}/lib64")
                        set(CUDSS_LIBRARY "${CUDSS_LIBRARY_DIR}/libcudss.so")
                        break()
                    elseif(EXISTS "${CUDA_PATH}/lib/libcudss.so")
                        set(CUDSS_FOUND TRUE)
                        set(CUDSS_INSTALL_PATH "${CUDA_PATH}")
                        set(CUDSS_INCLUDE_DIR "${CUDA_PATH}/include")
                        set(CUDSS_LIBRARY_DIR "${CUDA_PATH}/lib")
                        set(CUDSS_LIBRARY "${CUDSS_LIBRARY_DIR}/libcudss.so")
                        break()
                    endif()
                endif()
            endforeach()
        endif()

        # 3. Check /opt/nvidia/cudss or similar paths
        if(NOT CUDSS_FOUND)
            file(GLOB CUDSS_OPT_VERSIONS "/opt/nvidia/cudss/*" "/opt/cudss/*")
            if(CUDSS_OPT_VERSIONS)
                list(SORT CUDSS_OPT_VERSIONS)
                list(REVERSE CUDSS_OPT_VERSIONS)  # Get latest version
                list(GET CUDSS_OPT_VERSIONS 0 CUDSS_INSTALL_PATH)

                if(EXISTS "${CUDSS_INSTALL_PATH}/include/cudss.h")
                    if(EXISTS "${CUDSS_INSTALL_PATH}/lib64/libcudss.so")
                        set(CUDSS_FOUND TRUE)
                        set(CUDSS_INCLUDE_DIR "${CUDSS_INSTALL_PATH}/include")
                        set(CUDSS_LIBRARY_DIR "${CUDSS_INSTALL_PATH}/lib64")
                        set(CUDSS_LIBRARY "${CUDSS_LIBRARY_DIR}/libcudss.so")
                    elseif(EXISTS "${CUDSS_INSTALL_PATH}/lib/libcudss.so")
                        set(CUDSS_FOUND TRUE)
                        set(CUDSS_INCLUDE_DIR "${CUDSS_INSTALL_PATH}/include")
                        set(CUDSS_LIBRARY_DIR "${CUDSS_INSTALL_PATH}/lib")
                        set(CUDSS_LIBRARY "${CUDSS_LIBRARY_DIR}/libcudss.so")
                    endif()
                endif()
            endif()
        endif()
    endif()

    # Report cuDSS detection status
    if(CUDSS_FOUND)
        message(STATUS "cuDSS: FOUND")
        message(STATUS "  cuDSS Location: ${CUDSS_INSTALL_PATH}")
        message(STATUS "  cuDSS Include: ${CUDSS_INCLUDE_DIR}")
        message(STATUS "  cuDSS Library: ${CUDSS_LIBRARY}")

        # Add cuDSS to CMAKE_PREFIX_PATH so subprojects can find it
        list(APPEND CMAKE_PREFIX_PATH "${CUDSS_INSTALL_PATH}")

        # Set environment variable for subprojects
        set(ENV{CUDSS_ROOT} "${CUDSS_INSTALL_PATH}")

        # Export variables for COLMAP/GLOMAP
        set(CUDSS_INCLUDE_DIR "${CUDSS_INCLUDE_DIR}" CACHE PATH "cuDSS include directory")
        set(CUDSS_LIBRARY_DIR "${CUDSS_LIBRARY_DIR}" CACHE PATH "cuDSS library directory")
        set(CUDSS_LIBRARY "${CUDSS_LIBRARY}" CACHE FILEPATH "cuDSS library")

        # Add cuDSS bin directory to PATH for runtime DLL discovery (Windows)
        if(WIN32 AND EXISTS "${CUDSS_INSTALL_PATH}/bin")
            set(CUDSS_BIN_DIR "${CUDSS_INSTALL_PATH}/bin")
            # Add to PATH for runtime
            set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_RPATH};${CUDSS_BIN_DIR}")
            message(STATUS "  cuDSS Bin (DLLs): ${CUDSS_BIN_DIR}")
            message(STATUS "  NOTE: Ensure ${CUDSS_BIN_DIR} is in your PATH at runtime")
        endif()

        # Set cudss_DIR for find_package(cudss)
        if(EXISTS "${CUDSS_INSTALL_PATH}/lib/${CUDSS_CUDA_VERSION}/cmake/cudss")
            set(cudss_DIR "${CUDSS_INSTALL_PATH}/lib/${CUDSS_CUDA_VERSION}/cmake/cudss" CACHE PATH "Path to cudss CMake config")
        elseif(EXISTS "${CUDSS_INSTALL_PATH}/lib/cmake/cudss")
            set(cudss_DIR "${CUDSS_INSTALL_PATH}/lib/cmake/cudss" CACHE PATH "Path to cudss CMake config")
        endif()
    else()
        message(STATUS "cuDSS: NOT FOUND (optional - provides 2-5x performance improvement)")
        message(STATUS "  To install cuDSS, see: docs/INSTALL_CUDSS.md")
    endif()
endif()

# Build dependencies in order
# Dependency chain: Ceres -> (COLMAP, PoseLib) -> GLOMAP
#
# Note: We build TWO versions of COLMAP:
# 1. Latest COLMAP (third_party/colmap) - for standalone use
# 2. COLMAP 3.11 (third_party/colmap-for-glomap) - pinned version for GLOMAP compatibility
#
# Installation structure:
# build/install/
#   ├── ceres/       # Ceres Solver installation
#   ├── colmap/      # COLMAP installation (for pycolmap)
#   ├── poselib/     # PoseLib installation (for pyposelib)
#   └── glomap/      # GLOMAP installation

# Base install directory
set(BASE_INSTALL_DIR "${CMAKE_BINARY_DIR}/install" CACHE PATH "Base installation directory")

# Step 1: Build Ceres Solver (base dependency for everything)
# Use ExternalProject to build and install Ceres first, then make it available to other projects
if(BUILD_CERES)
    message(STATUS "Configuring Ceres Solver as external project...")

    # Determine generator arguments
    if(CMAKE_GENERATOR MATCHES "Visual Studio")
        set(CERES_GENERATOR_ARGS
            -G "${CMAKE_GENERATOR}"
            -A "${CMAKE_GENERATOR_PLATFORM}"
        )
    else()
        set(CERES_GENERATOR_ARGS
            -G "${CMAKE_GENERATOR}"
        )
    endif()

    # Build list of CMAKE_ARGS for Ceres
    # Note: Ceres uses USE_CUDA, not CUDA_ENABLED
    # VCPKG_OVERLAY_PORTS is handled by the toolchain, not needed as explicit arg
    # BUILD_TESTING=OFF to avoid linker issues with gklib in vcpkg METIS
    # Disable vcpkg manifest mode for ExternalProjects - they use the shared vcpkg_installed
    # directory where all dependencies have already been installed by the top-level CMake
    # Determine vcpkg installed path for this platform
    if(WIN32)
        set(VCPKG_INSTALLED_TRIPLET_DIR "${CMAKE_BINARY_DIR}/vcpkg_installed/x64-windows")
    else()
        set(VCPKG_INSTALLED_TRIPLET_DIR "${CMAKE_BINARY_DIR}/vcpkg_installed/x64-linux")
    endif()

    set(CERES_CMAKE_ARGS
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        -DVCPKG_INSTALLED_DIR=${CMAKE_BINARY_DIR}/vcpkg_installed
        -DVCPKG_MANIFEST_MODE=OFF
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
        -DCMAKE_INSTALL_PREFIX=${BASE_INSTALL_DIR}/ceres
        -DBUILD_TESTING=OFF
        -DBUILD_EXAMPLES=OFF
        -DBUILD_BENCHMARKS=OFF
        # Use vcpkg's SuiteSparse config so Ceres links against the same targets as GLOMAP
        -DSuiteSparse_DIR=${VCPKG_INSTALLED_TRIPLET_DIR}/share/suitesparse
        -DMETIS_DIR=${VCPKG_INSTALLED_TRIPLET_DIR}/share/metis
    )

    # Add CUDA support if enabled
    if(CUDA_ENABLED)
        list(APPEND CERES_CMAKE_ARGS -DUSE_CUDA=default)
        # Force shared CUDA runtime to avoid static/dynamic linkage conflicts
        list(APPEND CERES_CMAKE_ARGS "-DCMAKE_CUDA_RUNTIME_LIBRARY=Shared")
        # CUDA 13.x requires C++17 for CCCL headers
        if(CUDA13_CUDA_STANDARD)
            list(APPEND CERES_CMAKE_ARGS "-DCMAKE_CUDA_STANDARD=${CUDA13_CUDA_STANDARD}")
        endif()
        if(CUDA13_THRUST_FLAGS)
            list(APPEND CERES_CMAKE_ARGS "-DCMAKE_CUDA_FLAGS=${CUDA13_THRUST_FLAGS}")
        endif()
    endif()

    # Add cuDSS configuration if found
    if(CUDSS_FOUND AND cudss_DIR)
        list(APPEND CERES_CMAKE_ARGS -Dcudss_DIR=${cudss_DIR})
    endif()

    ExternalProject_Add(ceres-solver-external
        SOURCE_DIR "${CMAKE_SOURCE_DIR}/third_party/ceres-solver"
        BINARY_DIR "${CMAKE_BINARY_DIR}/ceres"
        CMAKE_GENERATOR "${CMAKE_GENERATOR}"
        CMAKE_GENERATOR_PLATFORM "${CMAKE_GENERATOR_PLATFORM}"
        # Apply patch to handle vcpkg ALIAS targets in Ceres's FindSuiteSparse.cmake
        # (CUDA architecture 120 patch removed - using consistent arch list 75;80;86;89;90)
        PATCH_COMMAND ${CMAKE_COMMAND}
            -DCERES_SOURCE_DIR=${CMAKE_SOURCE_DIR}/third_party/ceres-solver
            -P ${CMAKE_SOURCE_DIR}/cmake/patch_ceres_suitesparse.cmake
        CMAKE_ARGS ${CERES_CMAKE_ARGS}
        BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE}
        INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE} --target install
        BUILD_ALWAYS OFF
    )

    # Add to CMAKE_PREFIX_PATH so other modules can find it
    list(APPEND CMAKE_PREFIX_PATH "${BASE_INSTALL_DIR}/ceres")
endif()

# Step 2: Build PoseLib (depends on Ceres)
# Note: PoseLib is built here even if only GLOMAP is requested
# GLOMAP's FETCH_POSELIB must be OFF to use our local PoseLib
if(BUILD_GLOMAP)
    message(STATUS "Configuring PoseLib as external project...")

    ExternalProject_Add(poselib-external
        SOURCE_DIR "${CMAKE_SOURCE_DIR}/third_party/poselib"
        BINARY_DIR "${CMAKE_BINARY_DIR}/poselib"
        CMAKE_GENERATOR "${CMAKE_GENERATOR}"
        CMAKE_GENERATOR_PLATFORM "${CMAKE_GENERATOR_PLATFORM}"
        CMAKE_ARGS
            -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
            -DVCPKG_OVERLAY_PORTS=${VCPKG_OVERLAY_PORTS}
            -DVCPKG_INSTALLED_DIR=${CMAKE_BINARY_DIR}/vcpkg_installed
            -DVCPKG_MANIFEST_MODE=OFF
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_INSTALL_PREFIX=${BASE_INSTALL_DIR}/poselib
            -DCMAKE_PREFIX_PATH=${BASE_INSTALL_DIR}/ceres
            -DCMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES}
        BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE}
        INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE} --target install
        BUILD_ALWAYS OFF
        STEP_TARGETS install
        DEPENDS ceres-solver-external
    )

    list(APPEND CMAKE_PREFIX_PATH "${BASE_INSTALL_DIR}/poselib")
endif()

# Step 3: Build COLMAP (latest version - depends on Ceres)
if(BUILD_COLMAP)
    message(STATUS "Configuring COLMAP (latest) as external project...")

    ExternalProject_Add(colmap-external
        SOURCE_DIR "${CMAKE_SOURCE_DIR}/third_party/colmap"
        BINARY_DIR "${CMAKE_BINARY_DIR}/colmap"
        CMAKE_GENERATOR "${CMAKE_GENERATOR}"
        CMAKE_GENERATOR_PLATFORM "${CMAKE_GENERATOR_PLATFORM}"
        # Patch COLMAP to set GFLAGS_USE_TARGET_NAMESPACE before FindDependencies
        PATCH_COMMAND ${CMAKE_COMMAND}
            -DCOLMAP_SOURCE_DIR=${CMAKE_SOURCE_DIR}/third_party/colmap
            -P ${CMAKE_SOURCE_DIR}/cmake/patch_colmap_gflags.cmake
        CMAKE_ARGS
            -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
            -DVCPKG_OVERLAY_PORTS=${VCPKG_OVERLAY_PORTS}
            -DVCPKG_INSTALLED_DIR=${CMAKE_BINARY_DIR}/vcpkg_installed
            -DVCPKG_MANIFEST_MODE=OFF
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_INSTALL_PREFIX=${BASE_INSTALL_DIR}/colmap
            -DCMAKE_PREFIX_PATH=${BASE_INSTALL_DIR}/ceres
            -DCUDA_ENABLED=${CUDA_ENABLED}
            -DCMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES}
            -DCMAKE_CUDA_STANDARD=${CUDA13_CUDA_STANDARD}
            -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared
            -DCMAKE_CUDA_FLAGS=${CUDA13_THRUST_FLAGS}
            -DGUI_ENABLED=OFF
            -DTESTS_ENABLED=OFF
            -DX_VCPKG_APPLOCAL_DEPS_INSTALL=ON
        BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE}
        INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE} --target install
        BUILD_ALWAYS OFF
        DEPENDS ceres-solver-external
    )

    list(APPEND CMAKE_PREFIX_PATH "${BASE_INSTALL_DIR}/colmap")
endif()

# Step 3b: Build COLMAP for pycolmap (Python wheel building - depends on Ceres)
# This is built separately with specific configurations optimized for Python bindings
# Configuration based on COLMAP's official pycolmap GitHub Actions workflow
if(BUILD_COLMAP_FOR_PYCOLMAP)
    message(STATUS "Configuring COLMAP for pycolmap (Python wheels) as external project...")

    ExternalProject_Add(colmap-for-pycolmap-external
        SOURCE_DIR "${CMAKE_SOURCE_DIR}/third_party/colmap-for-pycolmap"
        BINARY_DIR "${CMAKE_BINARY_DIR}/colmap-pycolmap"
        CMAKE_GENERATOR "${CMAKE_GENERATOR}"
        CMAKE_GENERATOR_PLATFORM "${CMAKE_GENERATOR_PLATFORM}"
        # Patch COLMAP to set GFLAGS_USE_TARGET_NAMESPACE before FindDependencies
        PATCH_COMMAND ${CMAKE_COMMAND}
            -DCOLMAP_SOURCE_DIR=${CMAKE_SOURCE_DIR}/third_party/colmap-for-pycolmap
            -P ${CMAKE_SOURCE_DIR}/cmake/patch_colmap_gflags.cmake
        CMAKE_ARGS
            -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
            -DVCPKG_OVERLAY_PORTS=${VCPKG_OVERLAY_PORTS}
            -DVCPKG_INSTALLED_DIR=${CMAKE_BINARY_DIR}/vcpkg_installed
            -DVCPKG_MANIFEST_MODE=OFF
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_INSTALL_PREFIX=${BASE_INSTALL_DIR}/colmap-for-pycolmap
            -DCMAKE_PREFIX_PATH=${BASE_INSTALL_DIR}/ceres
            -DCUDA_ENABLED=${CUDA_ENABLED}
            -DCMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES}
            -DCMAKE_CUDA_STANDARD=${CUDA13_CUDA_STANDARD}
            -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared
            -DCMAKE_CUDA_FLAGS=${CUDA13_THRUST_FLAGS}
            -DGUI_ENABLED=OFF
            -DTESTS_ENABLED=OFF
            -DCGAL_ENABLED=ON
            -DOPENGL_ENABLED=OFF
            -DGFLAGS_USE_TARGET_NAMESPACE=ON
            -DX_VCPKG_APPLOCAL_DEPS_INSTALL=ON
        BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE}
        INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE} --target install
        BUILD_ALWAYS OFF
        DEPENDS ceres-solver-external
    )

    list(APPEND CMAKE_PREFIX_PATH "${BASE_INSTALL_DIR}/colmap-for-pycolmap")
endif()

# Step 4: Build COLMAP for GLOMAP (pinned to commit 78f1eefa - COLMAP 3.11)
# This is built separately to ensure GLOMAP compatibility
if(BUILD_GLOMAP)
    message(STATUS "Configuring COLMAP for GLOMAP (v3.11 - commit 78f1eefa) as external project...")

    # Determine vcpkg triplet for path hints (COLMAP 3.11's FindFLANN.cmake needs hints)
    if(WIN32)
        set(VCPKG_TRIPLET "x64-windows")
    else()
        set(VCPKG_TRIPLET "x64-linux")
    endif()
    set(VCPKG_INSTALLED_PATH "${CMAKE_BINARY_DIR}/vcpkg_installed/${VCPKG_TRIPLET}")

    ExternalProject_Add(colmap-for-glomap-external
        SOURCE_DIR "${CMAKE_SOURCE_DIR}/third_party/colmap-for-glomap"
        BINARY_DIR "${CMAKE_BINARY_DIR}/colmap-g"
        CMAKE_GENERATOR "${CMAKE_GENERATOR}"
        CMAKE_GENERATOR_PLATFORM "${CMAKE_GENERATOR_PLATFORM}"
        # Patch COLMAP for vcpkg compatibility:
        # 1. Set GFLAGS_USE_TARGET_NAMESPACE before FindDependencies
        # 2. Replace FindFLANN.cmake with vcpkg-compatible version
        # 3. Fix colmap-config.cmake.in to load dependencies before targets
        PATCH_COMMAND ${CMAKE_COMMAND}
            -DCOLMAP_SOURCE_DIR=${CMAKE_SOURCE_DIR}/third_party/colmap-for-glomap
            -P ${CMAKE_SOURCE_DIR}/cmake/patch_colmap_gflags.cmake
        COMMAND ${CMAKE_COMMAND}
            -DCOLMAP_SOURCE_DIR=${CMAKE_SOURCE_DIR}/third_party/colmap-for-glomap
            -P ${CMAKE_SOURCE_DIR}/cmake/patch_colmap_flann.cmake
        COMMAND ${CMAKE_COMMAND}
            -DCOLMAP_SOURCE_DIR=${CMAKE_SOURCE_DIR}/third_party/colmap-for-glomap
            -P ${CMAKE_SOURCE_DIR}/cmake/patch_colmap_flann_link.cmake
        COMMAND ${CMAKE_COMMAND}
            -DCOLMAP_SOURCE_DIR=${CMAKE_SOURCE_DIR}/third_party/colmap-for-glomap
            -P ${CMAKE_SOURCE_DIR}/cmake/patch_colmap_config.cmake
        # Use LIST_SEPARATOR to handle semicolons in CMAKE_PREFIX_PATH correctly
        LIST_SEPARATOR |
        CMAKE_ARGS
            -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
            -DVCPKG_OVERLAY_PORTS=${VCPKG_OVERLAY_PORTS}
            -DVCPKG_INSTALLED_DIR=${CMAKE_BINARY_DIR}/vcpkg_installed
            -DVCPKG_MANIFEST_MODE=OFF
            -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
            -DCMAKE_INSTALL_PREFIX=${BASE_INSTALL_DIR}/colmap-for-glomap
            -DCMAKE_PREFIX_PATH=${BASE_INSTALL_DIR}/ceres|${VCPKG_INSTALLED_PATH}
            -DCUDA_ENABLED=${CUDA_ENABLED}
            -DCMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES}
            -DCMAKE_CUDA_STANDARD=${CUDA13_CUDA_STANDARD}
            -DCMAKE_CUDA_RUNTIME_LIBRARY=Shared
            -DCMAKE_CUDA_FLAGS=${CUDA13_THRUST_FLAGS}
            -DGUI_ENABLED=OFF
            -DCGAL_ENABLED=OFF
            -DTESTS_ENABLED=OFF
            -DFLANN_INCLUDE_DIR_HINTS=${VCPKG_INSTALLED_PATH}/include
            -DFLANN_LIBRARY_DIR_HINTS=${VCPKG_INSTALLED_PATH}/lib
            -DX_VCPKG_APPLOCAL_DEPS_INSTALL=ON
            # Define glog version macros for COLMAP compatibility with vcpkg glog 0.7+
            # vcpkg's glog doesn't define GLOG_VERSION_MAJOR in headers, causing COLMAP
            # to use the wrong glog API
            "-DCMAKE_CXX_FLAGS=-DGLOG_VERSION_MAJOR=0 -DGLOG_VERSION_MINOR=7"
        BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE}
        INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config ${CMAKE_BUILD_TYPE} --target install
        BUILD_ALWAYS OFF
        STEP_TARGETS install
        DEPENDS ceres-solver-external
    )

    list(APPEND CMAKE_PREFIX_PATH "${BASE_INSTALL_DIR}/colmap-for-glomap")
endif()

# Step 5: Build GLOMAP (depends on COLMAP-for-GLOMAP and PoseLib)
# Note: GLOMAP is NOT configured here to avoid dependency issues
# It must be built after dependencies are installed using a separate CMake invocation
# See scripts_windows/build_glomap_fast.ps1 for the build orchestration
if(BUILD_GLOMAP)
    message(STATUS "GLOMAP will be configured separately after dependencies are built")
    message(STATUS "  Dependencies: Ceres, PoseLib, COLMAP for GLOMAP")
    message(STATUS "  Use build script to build GLOMAP after dependencies")
endif()

# Print configuration summary
message(STATUS "==================== Configuration Summary ====================")
message(STATUS "CUDA Support: ${CUDA_ENABLED}")
if(CUDA_ENABLED)
    message(STATUS "CUDA Version: ${CUDAToolkit_VERSION}")
    message(STATUS "CUDA Architectures: ${CMAKE_CUDA_ARCHITECTURES}")
    if(CUDSS_FOUND)
        message(STATUS "cuDSS Support: ENABLED (${CUDSS_INSTALL_PATH})")
    else()
        message(STATUS "cuDSS Support: DISABLED (not found - optional)")
    endif()
endif()
message(STATUS "Build COLMAP: ${BUILD_COLMAP}")
message(STATUS "Build COLMAP for pycolmap: ${BUILD_COLMAP_FOR_PYCOLMAP}")
message(STATUS "Build GLOMAP: ${BUILD_GLOMAP}")
message(STATUS "Build Ceres Solver: ${BUILD_CERES}")
message(STATUS "===============================================================")
