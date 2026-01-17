# Patch Ceres's FindSuiteSparse.cmake to handle ALIAS targets from vcpkg
# This script is called as a CMake PATCH_COMMAND for ceres-solver
#
# The issue: vcpkg's SuiteSparse creates ALIAS targets (e.g., SuiteSparse::AMD).
# When Ceres's FindSuiteSparse.cmake runs, it may not detect that SuiteSparse
# was already found via NO_MODULE search (if the config doesn't set SuiteSparse_FOUND).
# It then tries to call set_property() on the existing ALIAS targets, which fails with:
#   "set_property can not be used on an ALIAS target"
#
# The fix: Add an early check after the NO_MODULE search to detect if vcpkg's
# SuiteSparse config was loaded (by checking if any SuiteSparse::* targets are ALIAS).
# If so, force SuiteSparse_FOUND=TRUE to trigger early return.

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

# Check if already patched (look for our specific comment marker)
if(CONTENT MATCHES "PATCH: Check for vcpkg ALIAS targets")
    message(STATUS "FindSuiteSparse.cmake already patched for ALIAS targets")
    return()
endif()

# The NO_MODULE search happens at lines 96-98, and the early return is at lines 100-102.
# We need to add extra logic after the NO_MODULE search to detect vcpkg's ALIAS targets.
#
# Original:
#   if (NOT SuiteSparse_NO_CMAKE)
#     find_package (SuiteSparse NO_MODULE QUIET)
#   endif (NOT SuiteSparse_NO_CMAKE)
#
#   if (SuiteSparse_FOUND)
#     return ()
#   endif (SuiteSparse_FOUND)
#
# Patched:
#   if (NOT SuiteSparse_NO_CMAKE)
#     find_package (SuiteSparse NO_MODULE QUIET)
#   endif (NOT SuiteSparse_NO_CMAKE)
#
#   # PATCH: Check for vcpkg ALIAS targets - if they exist, force SuiteSparse_FOUND
#   if (NOT SuiteSparse_FOUND)
#     if (TARGET SuiteSparse::AMD)
#       get_target_property(_alias_check SuiteSparse::AMD ALIASED_TARGET)
#       if (_alias_check)
#         set(SuiteSparse_FOUND TRUE)
#         message(STATUS "SuiteSparse: Detected vcpkg ALIAS targets, using existing config")
#       endif()
#     endif()
#   endif()
#
#   if (SuiteSparse_FOUND)
#     return ()
#   endif (SuiteSparse_FOUND)

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

# PATCH: Check for vcpkg ALIAS targets - if they exist, force SuiteSparse_FOUND
# vcpkg creates ALIAS targets that cannot have properties set on them.
# If these targets exist, we should use the existing vcpkg config and return early.
if (NOT SuiteSparse_FOUND)
  if (TARGET SuiteSparse::AMD)
    get_target_property(_suitesparse_alias_check SuiteSparse::AMD ALIASED_TARGET)
    if (_suitesparse_alias_check)
      set(SuiteSparse_FOUND TRUE)
      message(STATUS \"SuiteSparse: Detected vcpkg ALIAS targets, using existing config\")
    endif()
    unset(_suitesparse_alias_check)
  endif()
endif()

if (SuiteSparse_FOUND)
  return ()
endif (SuiteSparse_FOUND)"
CONTENT "${CONTENT}")

file(WRITE "${FIND_SUITESPARSE_FILE}" "${CONTENT}")
message(STATUS "Successfully patched ${FIND_SUITESPARSE_FILE} to handle ALIAS targets")
