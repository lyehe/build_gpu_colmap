# Stamp COLMAP and pycolmap release metadata without committing local edits to
# the upstream submodules.
#
# Usage:
#   cmake -DCOLMAP_SOURCE_DIR=<path> -DCOLMAP_RELEASE_VERSION=<version> \
#         -P patch_colmap_version.cmake

if(NOT DEFINED COLMAP_SOURCE_DIR)
    message(FATAL_ERROR "COLMAP_SOURCE_DIR must be defined")
endif()

if(NOT DEFINED COLMAP_RELEASE_VERSION OR COLMAP_RELEASE_VERSION STREQUAL "")
    message(FATAL_ERROR "COLMAP_RELEASE_VERSION must be defined")
endif()

set(CMAKELISTS_FILE "${COLMAP_SOURCE_DIR}/CMakeLists.txt")
set(PYPROJECT_FILE "${COLMAP_SOURCE_DIR}/pyproject.toml")

if(NOT EXISTS "${CMAKELISTS_FILE}")
    message(FATAL_ERROR "CMakeLists.txt not found at ${CMAKELISTS_FILE}")
endif()

file(READ "${CMAKELISTS_FILE}" CMAKELISTS_CONTENT)

if(NOT CMAKELISTS_CONTENT MATCHES "(^|\n)set\\(COLMAP_VERSION \"[^\"]+\"\\)")
    message(FATAL_ERROR "Could not find COLMAP_VERSION in ${CMAKELISTS_FILE}")
endif()

string(REGEX REPLACE
    "(^|\n)set\\(COLMAP_VERSION \"[^\"]+\"\\)"
    "\\1set(COLMAP_VERSION \"${COLMAP_RELEASE_VERSION}\")"
    CMAKELISTS_CONTENT
    "${CMAKELISTS_CONTENT}"
)
file(WRITE "${CMAKELISTS_FILE}" "${CMAKELISTS_CONTENT}")
message(STATUS "Stamped COLMAP_VERSION=${COLMAP_RELEASE_VERSION} in ${CMAKELISTS_FILE}")

if(EXISTS "${PYPROJECT_FILE}")
    file(READ "${PYPROJECT_FILE}" PYPROJECT_CONTENT)

    if(NOT PYPROJECT_CONTENT MATCHES "(^|\n)version = \"[^\"]+\"")
        message(FATAL_ERROR "Could not find pyproject version in ${PYPROJECT_FILE}")
    endif()

    string(REGEX REPLACE
        "(^|\n)version = \"[^\"]+\""
        "\\1version = \"${COLMAP_RELEASE_VERSION}\""
        PYPROJECT_CONTENT
        "${PYPROJECT_CONTENT}"
    )
    file(WRITE "${PYPROJECT_FILE}" "${PYPROJECT_CONTENT}")
    message(STATUS "Stamped pycolmap version=${COLMAP_RELEASE_VERSION} in ${PYPROJECT_FILE}")
endif()
