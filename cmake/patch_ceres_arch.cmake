# CMake script to patch Ceres Solver CMakeLists.txt to add CUDA architecture 120 support
# This is run as PATCH_COMMAND in ExternalProject_Add
#
# Usage: cmake -DCERES_SOURCE_DIR=<path> -P patch_ceres_arch.cmake

if(NOT DEFINED CERES_SOURCE_DIR)
    message(FATAL_ERROR "CERES_SOURCE_DIR must be defined")
endif()

set(CERES_CMAKE_FILE "${CERES_SOURCE_DIR}/CMakeLists.txt")

if(NOT EXISTS "${CERES_CMAKE_FILE}")
    message(FATAL_ERROR "Ceres CMakeLists.txt not found at: ${CERES_CMAKE_FILE}")
endif()

# Read the file
file(READ "${CERES_CMAKE_FILE}" CERES_CONTENT)

# Check if already patched (idempotent)
string(FIND "${CERES_CONTENT}" "# Support Blackwell GPUs" ALREADY_PATCHED)
if(NOT ALREADY_PATCHED EQUAL -1)
    message(STATUS "Ceres already patched for arch 120 support - skipping")
    return()
endif()

# Find the line to patch after (Hopper GPU support)
string(FIND "${CERES_CONTENT}" "# Support Hopper GPUs." HOPPER_POS)
if(HOPPER_POS EQUAL -1)
    message(FATAL_ERROR "Could not find Hopper GPU support section in Ceres CMakeLists.txt")
endif()

# Find the endif after Hopper section
string(FIND "${CERES_CONTENT}" "endif(CUDAToolkit_VERSION VERSION_GREATER_EQUAL \"11.8\")" ENDIF_POS REVERSE)
if(ENDIF_POS EQUAL -1)
    message(FATAL_ERROR "Could not find Hopper endif in Ceres CMakeLists.txt")
endif()

# Calculate position after the endif line
string(LENGTH "${CERES_CONTENT}" CONTENT_LENGTH)
math(EXPR SEARCH_START "${ENDIF_POS} + 60")
string(SUBSTRING "${CERES_CONTENT}" ${SEARCH_START} 100 AFTER_ENDIF)
string(FIND "${AFTER_ENDIF}" "\n" NEWLINE_POS)
math(EXPR INSERT_POS "${SEARCH_START} + ${NEWLINE_POS} + 1")

# Create the patch content
set(PATCH_CONTENT "        if (CUDAToolkit_VERSION VERSION_GREATER_EQUAL \"12.6\")
          # Support Blackwell GPUs.
          list(APPEND CMAKE_CUDA_ARCHITECTURES \"120\")
        endif(CUDAToolkit_VERSION VERSION_GREATER_EQUAL \"12.6\")
")

# Split content at insertion point
string(SUBSTRING "${CERES_CONTENT}" 0 ${INSERT_POS} BEFORE_INSERT)
string(SUBSTRING "${CERES_CONTENT}" ${INSERT_POS} -1 AFTER_INSERT)

# Reconstruct with patch
set(PATCHED_CONTENT "${BEFORE_INSERT}${PATCH_CONTENT}${AFTER_INSERT}")

# Write back to file
file(WRITE "${CERES_CMAKE_FILE}" "${PATCHED_CONTENT}")

message(STATUS "Successfully patched Ceres CMakeLists.txt to add CUDA architecture 120 support")
