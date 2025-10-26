# Patch COLMAP's CMakeLists.txt to set GFLAGS_USE_TARGET_NAMESPACE before FindDependencies
# This is required because vcpkg's glog package expects gflags::gflags target to exist
#
# Usage: cmake -DCOLMAP_SOURCE_DIR=<path> -P patch_colmap_gflags.cmake

if(NOT DEFINED COLMAP_SOURCE_DIR)
    message(FATAL_ERROR "COLMAP_SOURCE_DIR must be defined")
endif()

set(CMAKELISTS_FILE "${COLMAP_SOURCE_DIR}/CMakeLists.txt")

if(NOT EXISTS "${CMAKELISTS_FILE}")
    message(FATAL_ERROR "CMakeLists.txt not found at ${CMAKELISTS_FILE}")
endif()

# Read the CMakeLists.txt file
file(READ "${CMAKELISTS_FILE}" CMAKELISTS_CONTENT)

# Check if already patched
if(CMAKELISTS_CONTENT MATCHES "GFLAGS_USE_TARGET_NAMESPACE")
    message(STATUS "COLMAP CMakeLists.txt already patched for gflags namespace")
    return()
endif()

# Find the line that includes FindDependencies.cmake
set(PATTERN "include\\(cmake/FindDependencies\\.cmake\\)")

if(NOT CMAKELISTS_CONTENT MATCHES "${PATTERN}")
    message(FATAL_ERROR "Could not find 'include(cmake/FindDependencies.cmake)' in CMakeLists.txt")
endif()

# Add the cache variable setting and find gflags before FindDependencies
# Use bracket syntax to avoid escaping issues
set(PATCH_TEXT [=[# Set gflags namespace flag before finding dependencies
# This is required because vcpkg's glog expects gflags::gflags target
# Force the value to ON and mark as CACHE variable
set(GFLAGS_USE_TARGET_NAMESPACE ON CACHE BOOL "Use gflags namespace (required for vcpkg glog)" FORCE)
message(STATUS "GFLAGS_USE_TARGET_NAMESPACE set to: ${GFLAGS_USE_TARGET_NAMESPACE}")

# Find gflags BEFORE glog to ensure namespace is set correctly
find_package(gflags CONFIG REQUIRED)
if(TARGET gflags::gflags)
  message(STATUS "Found gflags with namespace support")
  # Also create an alias to ensure it's available
  if(NOT TARGET gflags)
    add_library(gflags ALIAS gflags::gflags)
  endif()
else()
  message(FATAL_ERROR "gflags::gflags target not found despite GFLAGS_USE_TARGET_NAMESPACE=ON")
endif()

include(cmake/FindDependencies.cmake)]=])

string(REGEX REPLACE "${PATTERN}" "${PATCH_TEXT}" CMAKELISTS_CONTENT "${CMAKELISTS_CONTENT}")

# Write the patched file back
file(WRITE "${CMAKELISTS_FILE}" "${CMAKELISTS_CONTENT}")

message(STATUS "Successfully patched ${CMAKELISTS_FILE} to set GFLAGS_USE_TARGET_NAMESPACE")
