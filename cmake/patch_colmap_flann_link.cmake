# Patch COLMAP's CMakeLists.txt files to use FLANN_LIBRARIES variable instead of flann target
#
# Problem: COLMAP's CMakeLists.txt uses 'flann' target in PRIVATE_LINK_LIBS.
#          When CMake exports this, it becomes '-lflann' which doesn't exist (vcpkg uses flann_cpp_s).
#
# Solution: Replace 'flann' with '${FLANN_LIBRARIES}' in COLMAP's CMakeLists.txt files.
#           The FindFLANN.cmake sets FLANN_LIBRARIES to the full path of the library.
#           Using a variable instead of a target avoids the export serialization issue.
#
# Required variables (set via -D):
#   COLMAP_SOURCE_DIR - Path to COLMAP source directory

if(NOT DEFINED COLMAP_SOURCE_DIR)
    message(FATAL_ERROR "COLMAP_SOURCE_DIR must be defined")
endif()

# Files that reference 'flann' target
set(FILES_TO_PATCH
    "${COLMAP_SOURCE_DIR}/src/colmap/feature/CMakeLists.txt"
    "${COLMAP_SOURCE_DIR}/src/colmap/retrieval/CMakeLists.txt"
)

foreach(FILE_PATH ${FILES_TO_PATCH})
    if(NOT EXISTS "${FILE_PATH}")
        message(WARNING "File not found: ${FILE_PATH}, skipping")
        continue()
    endif()

    file(READ "${FILE_PATH}" CONTENT)

    # Check if already patched
    if(CONTENT MATCHES "FLANN_LIBRARIES")
        message(STATUS "${FILE_PATH} already patched for FLANN_LIBRARIES")
        continue()
    endif()

    # Replace 'flann' (as a standalone word in link libs) with ${FLANN_LIBRARIES}
    # The pattern is typically:
    #   PRIVATE_LINK_LIBS
    #       ...
    #       flann
    #       lz4
    #
    # We need to be careful to only replace standalone 'flann', not 'flann_cpp' etc.
    # Using regex to match 'flann' followed by newline or whitespace

    # Pattern: flann followed by newline (typical in COLMAP CMakeLists)
    string(REGEX REPLACE
        "(\n[ \t]+)flann(\n)"
        "\\1\${FLANN_LIBRARIES}\\2"
        CONTENT "${CONTENT}"
    )

    file(WRITE "${FILE_PATH}" "${CONTENT}")
    message(STATUS "Patched ${FILE_PATH}: replaced 'flann' with \${FLANN_LIBRARIES}")
endforeach()
