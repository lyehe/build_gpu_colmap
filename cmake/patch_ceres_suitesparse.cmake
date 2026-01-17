# Patch Ceres's FindSuiteSparse.cmake to handle ALIAS targets from vcpkg
# This script is called as a CMake PATCH_COMMAND for ceres-solver
#
# The issue: vcpkg's SuiteSparse creates ALIAS targets (e.g., SuiteSparse::AMD).
# When Ceres's FindSuiteSparse.cmake runs, it may not find SuiteSparse via
# NO_MODULE search (if SuiteSparse_FOUND isn't set). It then continues and
# tries to call set_property() on the existing ALIAS targets, which fails with:
#   "set_property can not be used on an ALIAS target"
#
# The fix: Move set_property calls inside the "if NOT TARGET" block so we only
# set properties when we create the target ourselves.

# CERES_SOURCE_DIR must be set via -D
if(NOT DEFINED CERES_SOURCE_DIR)
    message(FATAL_ERROR "CERES_SOURCE_DIR must be defined")
endif()

set(FIND_SUITESPARSE_FILE "${CERES_SOURCE_DIR}/cmake/FindSuiteSparse.cmake")

if(NOT EXISTS "${FIND_SUITESPARSE_FILE}")
    message(WARNING "FindSuiteSparse.cmake not found at ${FIND_SUITESPARSE_FILE}, skipping patch")
    return()
endif()

file(READ "${FIND_SUITESPARSE_FILE}" CONTENT)

# Check if already patched (look for our specific comment)
if(CONTENT MATCHES "Only set properties if we created the target")
    message(STATUS "FindSuiteSparse.cmake already patched for ALIAS targets")
    return()
endif()

# The original code structure we need to fix:
#
#     if (NOT TARGET SuiteSparse::${COMPONENT})
#       add_library(SuiteSparse::${COMPONENT} IMPORTED UNKNOWN)
#     endif (NOT TARGET SuiteSparse::${COMPONENT})
#
#     set_property(TARGET SuiteSparse::${COMPONENT} PROPERTY
#       INTERFACE_INCLUDE_DIRECTORIES ${SuiteSparse_${COMPONENT}_INCLUDE_DIR})
#     set_property(TARGET SuiteSparse::${COMPONENT} PROPERTY
#       IMPORTED_LOCATION ${SuiteSparse_${COMPONENT}_LIBRARY})
#
# Should become:
#
#     if (NOT TARGET SuiteSparse::${COMPONENT})
#       add_library(SuiteSparse::${COMPONENT} IMPORTED UNKNOWN)
#       # Only set properties if we created the target (not if it's an existing ALIAS)
#       set_property(TARGET SuiteSparse::${COMPONENT} PROPERTY
#         INTERFACE_INCLUDE_DIRECTORIES ${SuiteSparse_${COMPONENT}_INCLUDE_DIR})
#       set_property(TARGET SuiteSparse::${COMPONENT} PROPERTY
#         IMPORTED_LOCATION ${SuiteSparse_${COMPONENT}_LIBRARY})
#     endif (NOT TARGET SuiteSparse::${COMPONENT})

# Replace the problematic code block
string(REPLACE
"if (NOT TARGET SuiteSparse::\${COMPONENT})
      add_library(SuiteSparse::\${COMPONENT} IMPORTED UNKNOWN)
    endif (NOT TARGET SuiteSparse::\${COMPONENT})

    set_property(TARGET SuiteSparse::\${COMPONENT} PROPERTY
      INTERFACE_INCLUDE_DIRECTORIES \${SuiteSparse_\${COMPONENT}_INCLUDE_DIR})
    set_property(TARGET SuiteSparse::\${COMPONENT} PROPERTY
      IMPORTED_LOCATION \${SuiteSparse_\${COMPONENT}_LIBRARY})"
"if (NOT TARGET SuiteSparse::\${COMPONENT})
      add_library(SuiteSparse::\${COMPONENT} IMPORTED UNKNOWN)
      # Only set properties if we created the target (not if it's an existing ALIAS)
      set_property(TARGET SuiteSparse::\${COMPONENT} PROPERTY
        INTERFACE_INCLUDE_DIRECTORIES \${SuiteSparse_\${COMPONENT}_INCLUDE_DIR})
      set_property(TARGET SuiteSparse::\${COMPONENT} PROPERTY
        IMPORTED_LOCATION \${SuiteSparse_\${COMPONENT}_LIBRARY})
    endif (NOT TARGET SuiteSparse::\${COMPONENT})"
CONTENT "${CONTENT}")

file(WRITE "${FIND_SUITESPARSE_FILE}" "${CONTENT}")
message(STATUS "Successfully patched ${FIND_SUITESPARSE_FILE} to handle ALIAS targets")
