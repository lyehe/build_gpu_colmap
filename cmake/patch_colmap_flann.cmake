# Patch COLMAP's FindFLANN.cmake to also search for flann_cpp (vcpkg naming)
# This script is called as a CMake PATCH_COMMAND for colmap-for-glomap

# COLMAP_SOURCE_DIR must be set via -D
if(NOT DEFINED COLMAP_SOURCE_DIR)
    message(FATAL_ERROR "COLMAP_SOURCE_DIR must be defined")
endif()

set(FIND_FLANN_FILE "${COLMAP_SOURCE_DIR}/cmake/FindFLANN.cmake")

if(NOT EXISTS "${FIND_FLANN_FILE}")
    message(WARNING "FindFLANN.cmake not found at ${FIND_FLANN_FILE}, skipping patch")
    return()
endif()

file(READ "${FIND_FLANN_FILE}" CONTENT)

# Check if already patched
if(CONTENT MATCHES "flann_cpp")
    message(STATUS "FindFLANN.cmake already patched for flann_cpp")
    return()
endif()

# Patch find_library to also search for flann_cpp (vcpkg names it this way)
string(REPLACE
    "NAMES
    flann"
    "NAMES
    flann flann_cpp flann_cpp_s"
    CONTENT "${CONTENT}")

file(WRITE "${FIND_FLANN_FILE}" "${CONTENT}")
message(STATUS "Successfully patched ${FIND_FLANN_FILE} to search for flann_cpp")
