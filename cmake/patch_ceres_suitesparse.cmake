# Patch Ceres's FindSuiteSparse.cmake to handle ALIAS targets from vcpkg
# This script is called as a CMake PATCH_COMMAND for ceres-solver
#
# Problem: vcpkg creates ALIAS targets for SuiteSparse components. Ceres's
# FindSuiteSparse.cmake calls set_property on these targets, which fails
# because "set_property can not be used on an ALIAS target."
#
# Solution: Replace set_property calls with a helper macro that checks for ALIAS.

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
if(CONTENT MATCHES "VCPKG_ALIAS_PATCH_V2")
    message(STATUS "FindSuiteSparse.cmake already patched")
    return()
endif()

# Add a helper macro right after the first cmake_policy line
# This macro wraps set_property and skips it for ALIAS targets
set(HELPER_MACRO
"# VCPKG_ALIAS_PATCH_V2: Helper macro to skip set_property for ALIAS targets
# vcpkg creates ALIAS targets that cannot have set_property called on them
macro(suitesparse_set_property_safe TARGET_NAME)
  get_target_property(_is_alias \${TARGET_NAME} ALIASED_TARGET)
  if (NOT _is_alias)
    set_property(TARGET \${TARGET_NAME} \${ARGN})
  endif()
  unset(_is_alias)
endmacro()

")

# Insert helper macro after cmake_policy(SET CMP0057 NEW)
string(REPLACE
"cmake_policy (SET CMP0057 NEW)"
"cmake_policy (SET CMP0057 NEW)

${HELPER_MACRO}"
CONTENT "${CONTENT}")

# Now replace all set_property calls that target SuiteSparse::
# Pattern: set_property (TARGET SuiteSparse:: -> suitesparse_set_property_safe(SuiteSparse::
# Handle both literal names (SuiteSparse::CHOLMOD) and variable names (SuiteSparse::${COMPONENT})
string(REGEX REPLACE
"set_property \\(TARGET (SuiteSparse::[A-Za-z0-9_:${}]+)"
"suitesparse_set_property_safe(\\1"
CONTENT "${CONTENT}")

# Also handle set_property(TARGET (no space after opening paren)
string(REGEX REPLACE
"set_property\\(TARGET (SuiteSparse::[A-Za-z0-9_:${}]+)"
"suitesparse_set_property_safe(\\1"
CONTENT "${CONTENT}")

# Handle ${COMPONENT} and ${component} explicitly (CMake regex doesn't handle $ well)
string(REPLACE
"set_property(TARGET SuiteSparse::\${COMPONENT} PROPERTY"
"suitesparse_set_property_safe(SuiteSparse::\${COMPONENT} PROPERTY"
CONTENT "${CONTENT}")

string(REPLACE
"set_property (TARGET SuiteSparse::\${component} APPEND PROPERTY"
"suitesparse_set_property_safe(SuiteSparse::\${component} APPEND PROPERTY"
CONTENT "${CONTENT}")

file(WRITE "${FIND_SUITESPARSE_FILE}" "${CONTENT}")
message(STATUS "Patched ${FIND_SUITESPARSE_FILE} for vcpkg ALIAS targets")
