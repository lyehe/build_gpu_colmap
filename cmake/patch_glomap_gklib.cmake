# Patch GLOMAP's CMakeLists.txt to add GKlib dependency
#
# Problem: METIS depends on GKlib, but when SuiteSparse/CHOLMOD brings in
#          METIS, the transitive GKlib dependency is lost due to link order.
#
# Solution: Add GKlib explicitly to glomap_main's link libraries to ensure
#           it's linked after all other libraries that might reference METIS.
#
# Required variables (set via -D):
#   GLOMAP_SOURCE_DIR - Path to GLOMAP source directory
#   VCPKG_INSTALLED_PATH - Path to vcpkg installed directory

if(NOT DEFINED GLOMAP_SOURCE_DIR)
    message(FATAL_ERROR "GLOMAP_SOURCE_DIR must be defined")
endif()

set(CMAKE_FILE "${GLOMAP_SOURCE_DIR}/glomap/CMakeLists.txt")

if(NOT EXISTS "${CMAKE_FILE}")
    message(WARNING "GLOMAP CMakeLists.txt not found at ${CMAKE_FILE}, skipping patch")
    return()
endif()

file(READ "${CMAKE_FILE}" CONTENT)

# Check if already patched
if(CONTENT MATCHES "GKlib.*METIS fix")
    message(STATUS "GLOMAP CMakeLists.txt already patched for GKlib")
    return()
endif()

# Add GKlib with --whole-archive to force all symbols to be included
# This resolves the circular dependency with METIS regardless of link order
string(REPLACE
    "target_link_libraries(glomap_main glomap)"
    "target_link_libraries(glomap_main glomap)

# GKlib - METIS fix: Use --whole-archive to include all GKlib symbols
# METIS depends on GKlib, but static linking with circular deps needs all symbols
find_library(GKLIB_LIBRARY NAMES GKlib gklib PATHS \${CMAKE_PREFIX_PATH} PATH_SUFFIXES lib NO_DEFAULT_PATH)
if(GKLIB_LIBRARY)
    if(CMAKE_SYSTEM_NAME STREQUAL \"Linux\")
        # Linux: use --whole-archive to include all GKlib symbols
        target_link_libraries(glomap_main -Wl,--whole-archive \${GKLIB_LIBRARY} -Wl,--no-whole-archive)
        message(STATUS \"Added GKlib with --whole-archive to glomap_main\")
    else()
        # Other platforms: just add GKlib
        target_link_libraries(glomap_main \${GKLIB_LIBRARY})
        message(STATUS \"Added GKlib to glomap_main: \${GKLIB_LIBRARY}\")
    endif()
endif()"
    CONTENT "${CONTENT}")

file(WRITE "${CMAKE_FILE}" "${CONTENT}")
message(STATUS "Patched ${CMAKE_FILE}: added GKlib to glomap_main link libraries")
