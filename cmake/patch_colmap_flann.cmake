# Patch COLMAP's FindFLANN.cmake to work with vcpkg's FLANN package
#
# Problem: vcpkg's FLANN exports targets as flann::flann_cpp_s (static) or flann::flann_cpp (shared)
#          but COLMAP expects a library named "flann" and creates an INTERFACE target named "flann"
#          When COLMAP exports its targets, the flann target reference needs to resolve to an
#          actual library path, not just a target name that may not exist at consumption time.
#
# Solution: Replace FindFLANN.cmake with a version that:
#           1. First tries vcpkg's CMake config (find_package(flann CONFIG))
#           2. Extracts the actual library path from the vcpkg target
#           3. Creates a compatibility 'flann' target using the full library path
#           This ensures the exported COLMAP config contains the actual library path

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

# Check if already patched with vcpkg support (v2 with full path extraction)
if(CONTENT MATCHES "IMPORTED_LOCATION_RELEASE")
    message(STATUS "FindFLANN.cmake already patched for vcpkg support (v2)")
    return()
endif()

# Write completely new FindFLANN.cmake that supports vcpkg
# Key improvement: Extract actual library paths from vcpkg targets for proper export
set(NEW_CONTENT [[# FindFLANN.cmake - Patched for vcpkg compatibility (v2)
# This version extracts actual library paths from vcpkg targets to ensure proper CMake export

set(FLANN_INCLUDE_DIR_HINTS "" CACHE PATH "FLANN include directory")
set(FLANN_LIBRARY_DIR_HINTS "" CACHE PATH "FLANN library directory")

unset(FLANN_FOUND)
unset(FLANN_INCLUDE_DIRS)
unset(FLANN_LIBRARIES)

# Helper function to extract library path from an imported target
# On Windows with shared libraries, we need the import library (.lib), not the DLL
function(_get_imported_library_path TARGET_NAME OUT_VAR)
    set(${OUT_VAR} "" PARENT_SCOPE)
    if(NOT TARGET ${TARGET_NAME})
        return()
    endif()

    set(_loc "")

    # On Windows, prefer IMPORTED_IMPLIB (import library) over IMPORTED_LOCATION (DLL)
    # because we need to link against the .lib, not the .dll
    if(WIN32)
        get_target_property(_loc ${TARGET_NAME} IMPORTED_IMPLIB_RELEASE)
        if(NOT _loc)
            get_target_property(_loc ${TARGET_NAME} IMPORTED_IMPLIB_RELWITHDEBINFO)
        endif()
        if(NOT _loc)
            get_target_property(_loc ${TARGET_NAME} IMPORTED_IMPLIB)
        endif()
    endif()

    # Fall back to IMPORTED_LOCATION (works for static libs and on non-Windows)
    if(NOT _loc)
        get_target_property(_loc ${TARGET_NAME} IMPORTED_LOCATION_RELEASE)
    endif()
    if(NOT _loc)
        get_target_property(_loc ${TARGET_NAME} IMPORTED_LOCATION_RELWITHDEBINFO)
    endif()
    if(NOT _loc)
        get_target_property(_loc ${TARGET_NAME} IMPORTED_LOCATION)
    endif()

    # On Windows, if we got a DLL path, try to find the corresponding import lib
    if(_loc AND WIN32 AND _loc MATCHES "\\.dll$")
        # Convert bin/foo.dll to lib/foo.lib
        string(REGEX REPLACE "/bin/([^/]+)\\.dll$" "/lib/\\1.lib" _implib "${_loc}")
        if(EXISTS "${_implib}")
            set(_loc "${_implib}")
        endif()
    endif()

    if(_loc)
        set(${OUT_VAR} "${_loc}" PARENT_SCOPE)
    endif()
endfunction()

# Method 1: Try vcpkg's CMake config (preferred)
# vcpkg exports flann::flann_cpp (shared) or flann::flann_cpp_s (static)
find_package(flann CONFIG QUIET)

if(flann_FOUND OR FLANN_FOUND)
    message(STATUS "Found FLANN via vcpkg CMake config")

    # Determine which target is available and extract its library path
    set(_FLANN_TARGET "")
    set(_FLANN_LIBRARY_PATH "")

    if(TARGET flann::flann_cpp_s)
        set(_FLANN_TARGET flann::flann_cpp_s)
        _get_imported_library_path(flann::flann_cpp_s _FLANN_LIBRARY_PATH)
        message(STATUS "  Using static target: flann::flann_cpp_s")
    elseif(TARGET flann::flann_cpp)
        set(_FLANN_TARGET flann::flann_cpp)
        _get_imported_library_path(flann::flann_cpp _FLANN_LIBRARY_PATH)
        message(STATUS "  Using shared target: flann::flann_cpp")
    elseif(TARGET flann::flann)
        set(_FLANN_TARGET flann::flann)
        _get_imported_library_path(flann::flann _FLANN_LIBRARY_PATH)
        message(STATUS "  Using target: flann::flann")
    endif()

    if(_FLANN_TARGET)
        # Get include directories from the target
        get_target_property(_FLANN_INCLUDE_DIRS ${_FLANN_TARGET} INTERFACE_INCLUDE_DIRECTORIES)
        if(_FLANN_INCLUDE_DIRS)
            set(FLANN_INCLUDE_DIRS "${_FLANN_INCLUDE_DIRS}")
        endif()

        if(_FLANN_LIBRARY_PATH)
            message(STATUS "  Library path: ${_FLANN_LIBRARY_PATH}")
            set(FLANN_LIBRARIES "${_FLANN_LIBRARY_PATH}")
            set(FLANN_FOUND TRUE)

            # Create compatibility target 'flann' that COLMAP expects
            # Use the actual library path, not the target name, for proper export
            if(NOT TARGET flann)
                add_library(flann INTERFACE IMPORTED)
                if(FLANN_INCLUDE_DIRS)
                    set_target_properties(flann PROPERTIES
                        INTERFACE_INCLUDE_DIRECTORIES "${FLANN_INCLUDE_DIRS}"
                    )
                endif()
                # Link to the actual library file path, not the target name
                # This ensures proper serialization when COLMAP exports its targets
                set_target_properties(flann PROPERTIES
                    INTERFACE_LINK_LIBRARIES "${FLANN_LIBRARIES}"
                )
            endif()
            return()
        else()
            message(WARNING "Could not extract library path from ${_FLANN_TARGET}")
        endif()
    endif()
endif()

# Method 2: Manual search (fallback for non-vcpkg builds)
message(STATUS "FLANN not found via CMake config, trying manual search...")

list(APPEND FLANN_CHECK_INCLUDE_DIRS
    ${FLANN_INCLUDE_DIR_HINTS}
    /usr/include
    /usr/local/include
    /opt/include
    /opt/local/include
)

list(APPEND FLANN_CHECK_LIBRARY_DIRS
    ${FLANN_LIBRARY_DIR_HINTS}
    /usr/lib
    /usr/local/lib
    /opt/lib
    /opt/local/lib
)

find_path(FLANN_INCLUDE_DIRS
    NAMES flann/flann.hpp
    PATHS ${FLANN_CHECK_INCLUDE_DIRS}
)

# Search for all possible FLANN library names (vcpkg uses flann_cpp variants)
# Use NO_DEFAULT_PATH to prefer explicit paths, then fall back to system paths
find_library(FLANN_LIBRARIES
    NAMES flann_cpp_s flann_cpp flann
    PATHS ${FLANN_CHECK_LIBRARY_DIRS}
)

if(FLANN_INCLUDE_DIRS AND FLANN_LIBRARIES)
    set(FLANN_FOUND TRUE)
endif()

if(FLANN_FOUND)
    message(STATUS "Found FLANN (manual search)")
    message(STATUS "  Includes : ${FLANN_INCLUDE_DIRS}")
    message(STATUS "  Libraries : ${FLANN_LIBRARIES}")
else()
    if(FLANN_FIND_REQUIRED)
        message(FATAL_ERROR "Could not find FLANN. Searched in: ${FLANN_CHECK_LIBRARY_DIRS}")
    endif()
endif()

# Create INTERFACE IMPORTED target for compatibility
if(NOT TARGET flann)
    add_library(flann INTERFACE IMPORTED)
    if(FLANN_INCLUDE_DIRS)
        set_target_properties(flann PROPERTIES
            INTERFACE_INCLUDE_DIRECTORIES "${FLANN_INCLUDE_DIRS}"
        )
    endif()
    if(FLANN_LIBRARIES)
        set_target_properties(flann PROPERTIES
            INTERFACE_LINK_LIBRARIES "${FLANN_LIBRARIES}"
        )
    endif()
endif()
]])

file(WRITE "${FIND_FLANN_FILE}" "${NEW_CONTENT}")
message(STATUS "Replaced ${FIND_FLANN_FILE} with vcpkg-compatible version (v2)")
