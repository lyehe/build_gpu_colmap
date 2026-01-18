# Patch Ceres's FindSuiteSparse.cmake to handle ALIAS targets from vcpkg
# This script is called as a CMake PATCH_COMMAND for ceres-solver
#
# Problem: vcpkg's SuiteSparse creates ALIAS targets. When GLOMAP loads Ceres,
# CeresConfig.cmake calls find_dependency(SuiteSparse) which runs FindSuiteSparse.cmake.
# Multiple set_property calls fail because "set_property can not be used on an ALIAS target."
#
# Solution: Add an early check after the NO_MODULE search to detect vcpkg ALIAS targets.
# If detected, force SuiteSparse_FOUND=TRUE to trigger early return.

if(NOT DEFINED CERES_SOURCE_DIR)
    message(FATAL_ERROR "CERES_SOURCE_DIR must be defined")
endif()

set(FIND_SUITESPARSE_FILE "${CERES_SOURCE_DIR}/cmake/FindSuiteSparse.cmake")

if(NOT EXISTS "${FIND_SUITESPARSE_FILE}")
    message(WARNING "FindSuiteSparse.cmake not found at ${FIND_SUITESPARSE_FILE}, skipping patch")
    return()
endif()

file(READ "${FIND_SUITESPARSE_FILE}" CONTENT)

# Check if already patched
if(CONTENT MATCHES "VCPKG_ALIAS_PATCH")
    message(STATUS "FindSuiteSparse.cmake already patched")
    return()
endif()

# The original code around lines 96-102:
#   if (NOT SuiteSparse_NO_CMAKE)
#     find_package (SuiteSparse NO_MODULE QUIET)
#   endif (NOT SuiteSparse_NO_CMAKE)
#
#   if (SuiteSparse_FOUND)
#     return ()
#   endif (SuiteSparse_FOUND)
#
# After NO_MODULE search, vcpkg's config may have created ALIAS targets but
# SuiteSparse_FOUND might not be set. We detect ALIAS targets and return early.

string(REPLACE
"if (NOT SuiteSparse_NO_CMAKE)
  find_package (SuiteSparse NO_MODULE QUIET)
endif (NOT SuiteSparse_NO_CMAKE)

if (SuiteSparse_FOUND)
  return ()
endif (SuiteSparse_FOUND)"
"if (NOT SuiteSparse_NO_CMAKE)
  find_package (SuiteSparse NO_MODULE QUIET)
endif (NOT SuiteSparse_NO_CMAKE)

# VCPKG_ALIAS_PATCH: Detect vcpkg ALIAS targets and return early
# vcpkg creates ALIAS targets that cannot have set_property called on them.
# Check for CHOLMOD which is commonly used and has the same target name in both Ceres and vcpkg.
if (NOT SuiteSparse_FOUND AND TARGET SuiteSparse::CHOLMOD)
  get_target_property(_ss_aliased SuiteSparse::CHOLMOD ALIASED_TARGET)
  if (_ss_aliased)
    set(SuiteSparse_FOUND TRUE)
    message(STATUS \"SuiteSparse: Using vcpkg ALIAS targets (detected via CHOLMOD)\")
  endif()
  unset(_ss_aliased)
endif()

if (SuiteSparse_FOUND)
  return ()
endif (SuiteSparse_FOUND)"
CONTENT "${CONTENT}")

file(WRITE "${FIND_SUITESPARSE_FILE}" "${CONTENT}")
message(STATUS "Patched ${FIND_SUITESPARSE_FILE} for vcpkg ALIAS targets")
