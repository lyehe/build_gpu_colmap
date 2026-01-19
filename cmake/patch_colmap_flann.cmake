# Patch COLMAP's FindFLANN.cmake to work with vcpkg's FLANN package
#
# Problem: vcpkg's FLANN exports targets as flann::flann_cpp_s (static) or flann::flann_cpp (shared)
#          but COLMAP expects a library named "flann" and creates an INTERFACE target named "flann"
#
# Solution: Replace FindFLANN.cmake with a version that:
#           1. First tries vcpkg's CMake config (find_package(flann CONFIG))
#           2. Creates a compatibility 'flann' target aliasing the vcpkg target
#           3. Falls back to manual search if needed

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

# Check if already patched with vcpkg support
if(CONTENT MATCHES "flann::flann_cpp")
    message(STATUS "FindFLANN.cmake already patched for vcpkg support")
    return()
endif()

# Write completely new FindFLANN.cmake that supports vcpkg
set(NEW_CONTENT [[# FindFLANN.cmake - Patched for vcpkg compatibility
# This version first tries vcpkg's CMake config, then falls back to manual search

set(FLANN_INCLUDE_DIR_HINTS "" CACHE PATH "FLANN include directory")
set(FLANN_LIBRARY_DIR_HINTS "" CACHE PATH "FLANN library directory")

unset(FLANN_FOUND)
unset(FLANN_INCLUDE_DIRS)
unset(FLANN_LIBRARIES)

# Method 1: Try vcpkg's CMake config (preferred)
# vcpkg exports flann::flann_cpp (shared) or flann::flann_cpp_s (static)
find_package(flann CONFIG QUIET)

if(flann_FOUND OR FLANN_FOUND)
    message(STATUS "Found FLANN via vcpkg CMake config")

    # Determine which target is available
    if(TARGET flann::flann_cpp_s)
        set(_FLANN_TARGET flann::flann_cpp_s)
        message(STATUS "  Using static target: flann::flann_cpp_s")
    elseif(TARGET flann::flann_cpp)
        set(_FLANN_TARGET flann::flann_cpp)
        message(STATUS "  Using shared target: flann::flann_cpp")
    else()
        message(WARNING "flann package found but no expected targets. Available targets may differ.")
        # Try to find any flann target
        get_property(_flann_targets GLOBAL PROPERTY PACKAGES_FOUND)
    endif()

    if(_FLANN_TARGET)
        set(FLANN_FOUND TRUE)
        # Create compatibility target 'flann' that COLMAP expects
        if(NOT TARGET flann)
            add_library(flann INTERFACE IMPORTED)
            set_target_properties(flann PROPERTIES
                INTERFACE_LINK_LIBRARIES "${_FLANN_TARGET}"
            )
        endif()
        return()
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
    target_include_directories(flann INTERFACE ${FLANN_INCLUDE_DIRS})
    target_link_libraries(flann INTERFACE ${FLANN_LIBRARIES})
endif()
]])

file(WRITE "${FIND_FLANN_FILE}" "${NEW_CONTENT}")
message(STATUS "Replaced ${FIND_FLANN_FILE} with vcpkg-compatible version")
