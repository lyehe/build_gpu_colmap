# Patch COLMAP's FindDependencies.cmake to fix ONNX install on Windows.
# The share/ directory is only created on non-Windows, but the install rule
# runs unconditionally, causing the install step to fail on Windows.
# Fix: wrap the install(DIRECTORY .../share/) in an if(EXISTS) guard.
#
# Usage: cmake -DCOLMAP_SOURCE_DIR=<path> -P patch_colmap_onnx_install.cmake

if(NOT DEFINED COLMAP_SOURCE_DIR)
    message(FATAL_ERROR "COLMAP_SOURCE_DIR must be defined")
endif()

set(TARGET_FILE "${COLMAP_SOURCE_DIR}/cmake/FindDependencies.cmake")

if(NOT EXISTS "${TARGET_FILE}")
    message(STATUS "FindDependencies.cmake not found - skipping ONNX install patch")
    return()
endif()

file(READ "${TARGET_FILE}" CONTENT)

# Check if already patched
if(CONTENT MATCHES "Guard onnxruntime share/ install")
    message(STATUS "FindDependencies.cmake already patched for ONNX install")
    return()
endif()

# Check if the problematic pattern exists
if(NOT CONTENT MATCHES "onnxruntime_BINARY_DIR}/share/")
    message(STATUS "ONNX share install pattern not found - skipping patch")
    return()
endif()

# Use regex to wrap the install(DIRECTORY ...share/...) block in if(EXISTS)
# Match: install(\n...DIRECTORY "${onnxruntime_BINARY_DIR}/share/"...\n...DESTINATION...)
string(REGEX REPLACE
    "([ \t]*)install\\(([^)]*onnxruntime_BINARY_DIR}/share/[^)]*)\\)"
    "\\1# Guard onnxruntime share/ install - directory only exists on non-Windows\n\\1if(EXISTS \"\${onnxruntime_BINARY_DIR}/share/\")\n\\1    install(\\2)\n\\1endif()"
    CONTENT "${CONTENT}"
)

file(WRITE "${TARGET_FILE}" "${CONTENT}")

# Verify
file(READ "${TARGET_FILE}" VERIFY_CONTENT)
if(VERIFY_CONTENT MATCHES "Guard onnxruntime share/ install")
    message(STATUS "Successfully patched ${TARGET_FILE} for ONNX install")
else()
    message(WARNING "ONNX install patch may not have applied correctly")
endif()
