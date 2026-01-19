# Patch COLMAP's colmap-config.cmake.in to load dependencies before targets
#
# Problem: colmap-config.cmake.in loads colmap-targets.cmake BEFORE FindDependencies.cmake
#          but colmap-targets.cmake references 'flann' which is created by FindDependencies.cmake
#
# Solution: Swap the order so dependencies are found before targets are loaded

# COLMAP_SOURCE_DIR must be set via -D
if(NOT DEFINED COLMAP_SOURCE_DIR)
    message(FATAL_ERROR "COLMAP_SOURCE_DIR must be defined")
endif()

set(CONFIG_FILE "${COLMAP_SOURCE_DIR}/cmake/colmap-config.cmake.in")

if(NOT EXISTS "${CONFIG_FILE}")
    message(WARNING "colmap-config.cmake.in not found at ${CONFIG_FILE}, skipping patch")
    return()
endif()

file(READ "${CONFIG_FILE}" CONTENT)

# Check if already patched
if(CONTENT MATCHES "FindDependencies.cmake BEFORE targets")
    message(STATUS "colmap-config.cmake.in already patched")
    return()
endif()

# Normalize line endings
string(REPLACE "\r\n" "\n" CONTENT "${CONTENT}")
string(REPLACE "\r" "\n" CONTENT "${CONTENT}")

# Find the include lines and swap them
# Original order:
#   include(${PACKAGE_PREFIX_DIR}/share/colmap/colmap-targets.cmake)
#   include(${PACKAGE_PREFIX_DIR}/share/colmap/cmake/FindDependencies.cmake)
# New order:
#   include(${PACKAGE_PREFIX_DIR}/share/colmap/cmake/FindDependencies.cmake)
#   include(${PACKAGE_PREFIX_DIR}/share/colmap/colmap-targets.cmake)

string(REPLACE
    "include(\${PACKAGE_PREFIX_DIR}/share/colmap/colmap-targets.cmake)\ninclude(\${PACKAGE_PREFIX_DIR}/share/colmap/cmake/FindDependencies.cmake)"
    "# Load FindDependencies.cmake BEFORE targets to ensure FLANN target exists\ninclude(\${PACKAGE_PREFIX_DIR}/share/colmap/cmake/FindDependencies.cmake)\ninclude(\${PACKAGE_PREFIX_DIR}/share/colmap/colmap-targets.cmake)"
    CONTENT "${CONTENT}")

file(WRITE "${CONFIG_FILE}" "${CONTENT}")
message(STATUS "Patched ${CONFIG_FILE} to load dependencies before targets")
