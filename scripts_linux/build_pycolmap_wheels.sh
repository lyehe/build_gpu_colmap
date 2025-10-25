#!/bin/bash
# Build pycolmap wheels for all installed Python versions using colmap-for-pycolmap
# Usage: ./build_pycolmap_wheels.sh [Debug|Release] [options]

set -e

# Default configuration
BUILD_TYPE="Release"
NO_CUDA=false
CLEAN_BUILD=false
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COLMAP_SOURCE="${PROJECT_ROOT}/third_party/colmap-for-pycolmap"
BUILD_DIR="${PROJECT_ROOT}/build"
COLMAP_INSTALL="${BUILD_DIR}/install/colmap-for-pycolmap"
VCPKG_ROOT="${PROJECT_ROOT}/third_party/vcpkg"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DARK_GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        Debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        Release)
            BUILD_TYPE="Release"
            shift
            ;;
        --no-cuda)
            NO_CUDA=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --help|-h)
            echo "Build pycolmap wheels for ALL installed Python versions"
            echo ""
            echo "This script automatically:"
            echo "  1. Initializes colmap-for-pycolmap submodule if needed"
            echo "  2. Builds COLMAP-for-pycolmap with optimized settings"
            echo "  3. Detects all Python 3.9+ installations"
            echo "  4. Builds a wheel for each Python version"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  Debug              Build in Debug mode"
            echo "  Release            Build in Release mode (default)"
            echo "  --no-cuda          Build without CUDA support"
            echo "  --clean            Clean build before building"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Detection:"
            echo "  The script searches for Python installations in:"
            echo "  - Common python3.X commands (python3.9, python3.10, etc.)"
            echo "  - PATH environment variable"
            echo "  - Common installation directories (/usr/bin, /usr/local/bin)"
            echo ""
            echo "Requirements:"
            echo "  - Python 3.9+ (multiple versions recommended)"
            echo "  - GCC 9+ or Clang 10+"
            echo "  - CMake 3.28+"
            echo "  - Git"
            echo ""
            echo "Output:"
            echo "  All wheels in: third_party/colmap-for-pycolmap/wheelhouse/"
            echo "  - pycolmap-*-cp39-*.whl"
            echo "  - pycolmap-*-cp310-*.whl"
            echo "  - pycolmap-*-cp311-*.whl"
            echo "  - pycolmap-*-cp312-*.whl"
            echo "  - etc."
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --no-cuda"
            echo "  $0 --clean"
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo "================================================================"
echo -e "${CYAN}Build pycolmap Wheels for All Python Versions${NC}"
echo "================================================================"
echo "Configuration: $BUILD_TYPE"
echo "CUDA: $(if [ "$NO_CUDA" = true ]; then echo 'Disabled'; else echo 'Enabled'; fi)"
echo "COLMAP Source: $COLMAP_SOURCE"
echo "================================================================"

# Helper function to initialize submodules if not already done
initialize_submodule() {
    local submodule_path=$1
    local name=$2
    local full_path="${PROJECT_ROOT}/${submodule_path}"

    if [ ! -d "${full_path}/.git" ]; then
        echo ""
        echo -e "${YELLOW}Initializing ${name} submodule...${NC}"
        cd "${PROJECT_ROOT}"
        git submodule update --init --recursive "${submodule_path}"
        if [ $? -ne 0 ]; then
            echo -e "${RED}ERROR: Failed to initialize ${name} submodule${NC}"
            exit 1
        fi
        echo -e "${GREEN}  ${name} initialized successfully${NC}"
    fi
}

# Initialize required submodules
echo ""
echo -e "${CYAN}Checking required submodules...${NC}"
initialize_submodule "third_party/vcpkg" "vcpkg"
initialize_submodule "third_party/ceres-solver" "Ceres Solver"
initialize_submodule "third_party/colmap-for-pycolmap" "COLMAP for pycolmap"
echo ""

# Bootstrap vcpkg if needed
VCPKG_EXE="${VCPKG_ROOT}/vcpkg"
if [ ! -f "${VCPKG_EXE}" ]; then
    echo -e "${YELLOW}Bootstrapping vcpkg...${NC}"
    BOOTSTRAP_SCRIPT="${SCRIPT_DIR}/bootstrap.sh"
    bash "${BOOTSTRAP_SCRIPT}" --no-prompt
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to bootstrap vcpkg${NC}"
        exit 1
    fi
    echo ""
fi

# Build COLMAP-for-pycolmap if not already built or if Clean is specified
COLMAP_BIN="${COLMAP_INSTALL}/bin/colmap"
NEEDS_BUILD=false

if [ ! -f "$COLMAP_BIN" ] || [ "$CLEAN_BUILD" = true ]; then
    NEEDS_BUILD=true
fi

if [ "$NEEDS_BUILD" = true ]; then
    echo ""
    echo -e "${YELLOW}Building COLMAP-for-pycolmap...${NC}"
    echo -e "${DARK_GRAY}This may take 30-60 minutes on first build...${NC}"
    echo ""

    # Clean build directories if requested
    if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR" ]; then
        echo -e "${YELLOW}Cleaning build directories...${NC}"

        # Clean colmap-pycolmap build directory
        COLMAP_PYCOLMAP_BUILD="${BUILD_DIR}/colmap-pycolmap"
        if [ -d "$COLMAP_PYCOLMAP_BUILD" ]; then
            echo -e "${DARK_GRAY}  Removing $COLMAP_PYCOLMAP_BUILD${NC}"
            rm -rf "$COLMAP_PYCOLMAP_BUILD"
        fi

        # Clean ExternalProject stamp files
        EXTERNAL_PROJECT_STAMPS="${BUILD_DIR}/colmap-for-pycolmap-external-prefix"
        if [ -d "$EXTERNAL_PROJECT_STAMPS" ]; then
            echo -e "${DARK_GRAY}  Removing $EXTERNAL_PROJECT_STAMPS${NC}"
            rm -rf "$EXTERNAL_PROJECT_STAMPS"
        fi

        # Clean installation directory
        if [ -d "$COLMAP_INSTALL" ]; then
            echo -e "${DARK_GRAY}  Removing $COLMAP_INSTALL${NC}"
            rm -rf "$COLMAP_INSTALL"
        fi

        # Clean top-level CMakeCache.txt if it exists (may interfere)
        TOP_CMAKE_CACHE="${BUILD_DIR}/CMakeCache.txt"
        if [ -f "$TOP_CMAKE_CACHE" ]; then
            echo -e "${DARK_GRAY}  Removing $TOP_CMAKE_CACHE${NC}"
            rm -f "$TOP_CMAKE_CACHE"
        fi

        echo -e "${GREEN}  Clean complete${NC}"
    fi

    if [ ! -d "$BUILD_DIR" ]; then
        mkdir -p "$BUILD_DIR"
    fi

    # Check if Ninja is available (preferred for speed)
    if command -v ninja >/dev/null 2>&1; then
        GENERATOR="Ninja"
        echo -e "${GREEN}Ninja found: $(which ninja)${NC}"
    else
        GENERATOR="Unix Makefiles"
        echo -e "${YELLOW}Ninja not found, using Unix Makefiles${NC}"
        echo -e "${DARK_GRAY}Install ninja for faster builds: sudo apt-get install ninja-build${NC}"
    fi

    # Configure CMake
    cd "$BUILD_DIR"

    VCPKG_TOOLCHAIN="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
    CUDA_ENABLED="ON"
    if [ "$NO_CUDA" = true ]; then
        CUDA_ENABLED="OFF"
    fi

    echo -e "${CYAN}Configuring CMake with ${GENERATOR}...${NC}"
    cmake .. \
        -G "$GENERATOR" \
        -DCMAKE_TOOLCHAIN_FILE="$VCPKG_TOOLCHAIN" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
        -DCUDA_ENABLED="$CUDA_ENABLED" \
        -DBUILD_COLMAP=OFF \
        -DBUILD_COLMAP_FOR_PYCOLMAP=ON \
        -DBUILD_GLOMAP=OFF \
        -DBUILD_CERES=ON \
        -DGFLAGS_USE_TARGET_NAMESPACE=ON

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: CMake configuration failed${NC}"
        exit 1
    fi

    echo ""
    echo -e "${CYAN}Building COLMAP-for-pycolmap...${NC}"
    cmake --build . --config "$BUILD_TYPE" --parallel

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Build failed${NC}"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}COLMAP-for-pycolmap built successfully!${NC}"
    cd "$SCRIPT_DIR"
else
    echo ""
    echo -e "${GREEN}COLMAP-for-pycolmap already built at $COLMAP_INSTALL${NC}"
fi

# Function to get Python version from executable
get_python_version() {
    local python_exe=$1

    if ! command -v "$python_exe" >/dev/null 2>&1; then
        return 1
    fi

    local version_output=$($python_exe --version 2>&1)
    if [[ $version_output =~ Python\ ([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
        return 0
    fi

    return 1
}

# Detect all Python installations
echo ""
echo -e "${YELLOW}Detecting Python installations...${NC}"

declare -A PYTHON_VERSIONS
declare -A SEEN_VERSIONS

# Method 1: Try common python3.X commands
echo -e "  ${DARK_GRAY}Checking python3.X commands...${NC}"
for minor in {9..15}; do
    python_cmd="python3.$minor"
    if command -v "$python_cmd" >/dev/null 2>&1; then
        version=$(get_python_version "$python_cmd")
        if [ $? -eq 0 ] && [ -n "$version" ]; then
            if [ -z "${SEEN_VERSIONS[$version]}" ]; then
                PYTHON_VERSIONS["$python_cmd"]="$version"
                SEEN_VERSIONS["$version"]=1
                echo -e "    ${GREEN}Found: Python $version via $python_cmd${NC}"
            fi
        fi
    fi
done

# Method 2: Check python3 and python in PATH
echo -e "  ${DARK_GRAY}Checking PATH...${NC}"
for python_cmd in python3 python; do
    if command -v "$python_cmd" >/dev/null 2>&1; then
        version=$(get_python_version "$python_cmd")
        if [ $? -eq 0 ] && [ -n "$version" ]; then
            if [ -z "${SEEN_VERSIONS[$version]}" ]; then
                PYTHON_VERSIONS["$python_cmd"]="$version"
                SEEN_VERSIONS["$version"]=1
                echo -e "    ${GREEN}Found: Python $version via $python_cmd${NC}"
            fi
        fi
    fi
done

# Method 3: Common installation directories (optional)
echo -e "  ${DARK_GRAY}Checking common directories...${NC}"
for dir in /usr/bin /usr/local/bin /opt/python*/bin ~/.local/bin; do
    if [ -d "$dir" ]; then
        for python_exe in "$dir"/python3.[0-9]*; do
            if [ -x "$python_exe" ]; then
                python_cmd=$(basename "$python_exe")
                version=$(get_python_version "$python_exe")
                if [ $? -eq 0 ] && [ -n "$version" ]; then
                    if [ -z "${SEEN_VERSIONS[$version]}" ]; then
                        PYTHON_VERSIONS["$python_exe"]="$version"
                        SEEN_VERSIONS["$version"]=1
                        echo -e "    ${GREEN}Found: Python $version at $python_exe${NC}"
                    fi
                fi
            fi
        done
    fi
done

# Filter to Python 3.9+ and create ordered array
declare -a VALID_PYTHONS
for python_cmd in "${!PYTHON_VERSIONS[@]}"; do
    version="${PYTHON_VERSIONS[$python_cmd]}"
    IFS='.' read -r major minor patch <<< "$version"

    if [ "$major" -eq 3 ] && [ "$minor" -ge 9 ]; then
        VALID_PYTHONS+=("$python_cmd:$version")
    fi
done

# Sort by version
IFS=$'\n' VALID_PYTHONS=($(sort -t: -k2 -V <<< "${VALID_PYTHONS[*]}"))
unset IFS

if [ ${#VALID_PYTHONS[@]} -eq 0 ]; then
    echo ""
    echo -e "${RED}ERROR: No Python 3.9+ installations found${NC}"
    echo ""
    echo -e "${YELLOW}To install multiple Python versions (Ubuntu/Debian):${NC}"
    echo "  sudo apt-get install python3.9 python3.9-dev"
    echo "  sudo apt-get install python3.10 python3.10-dev"
    echo "  sudo apt-get install python3.11 python3.11-dev"
    echo "  sudo apt-get install python3.12 python3.12-dev"
    exit 1
fi

echo ""
echo -e "${GREEN}Found ${#VALID_PYTHONS[@]} compatible Python version(s):${NC}"
for entry in "${VALID_PYTHONS[@]}"; do
    IFS=':' read -r python_cmd version <<< "$entry"
    echo "  - Python $version ($python_cmd)"
done

# Build wheel for each Python version
echo ""
echo "================================================================"
echo -e "${CYAN}Building wheels for all versions...${NC}"
echo "================================================================"

SUCCESSFUL_BUILDS=()
FAILED_BUILDS=()

count=0
for entry in "${VALID_PYTHONS[@]}"; do
    IFS=':' read -r python_cmd version <<< "$entry"
    count=$((count + 1))

    echo ""
    echo -e "${CYAN}[$count/${#VALID_PYTHONS[@]}] Building for Python $version...${NC}"
    echo "================================================================"

    # Save original PATH
    ORIGINAL_PATH="$PATH"

    # Add Python to PATH
    python_dir=$(dirname "$(command -v "$python_cmd")")
    export PATH="$python_dir:$ORIGINAL_PATH"

    (
        # Build wheel using pip and scikit-build-core
        echo -e "  ${DARK_GRAY}Installing/upgrading build tools...${NC}"
        "$python_cmd" -m pip install --quiet --upgrade pip setuptools wheel
        "$python_cmd" -m pip install --quiet --upgrade scikit-build-core[pyproject] pybind11 auditwheel patchelf

        echo -e "  ${DARK_GRAY}Building wheel with pip...${NC}"

        # Get pybind11 CMake directory (installed by pip)
        # This is needed because vcpkg toolchain intercepts find_package(pybind11)
        PYBIND11_CMAKE_DIR=$("$python_cmd" -c "import pybind11; print(pybind11.get_cmake_dir())" 2>/dev/null)

        # Prepare CMake configuration settings for scikit-build-core
        # These are passed to pip wheel via --config-settings
        VCPKG_TOOLCHAIN="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
        VCPKG_INSTALLED="${BUILD_DIR}/vcpkg_installed"

        # CMAKE_PREFIX_PATH needs both COLMAP and pybind11 (colon-separated on Linux)
        CMAKE_PREFIX_PATH="${COLMAP_INSTALL}:${PYBIND11_CMAKE_DIR}"

        echo -e "  ${DARK_GRAY}CMAKE_TOOLCHAIN_FILE: $VCPKG_TOOLCHAIN${NC}"
        echo -e "  ${DARK_GRAY}VCPKG_INSTALLED_DIR: $VCPKG_INSTALLED${NC}"
        echo -e "  ${DARK_GRAY}CMAKE_PREFIX_PATH: $CMAKE_PREFIX_PATH${NC}"

        cd "$COLMAP_SOURCE"

        # Build wheel using pip with explicit CMake configuration
        # Based on official COLMAP workflow: .github/workflows/build-pycolmap.yml
        "$python_cmd" -m pip wheel . --no-deps -w wheelhouse \
            --config-settings="cmake.define.CMAKE_TOOLCHAIN_FILE=${VCPKG_TOOLCHAIN}" \
            --config-settings="cmake.define.VCPKG_INSTALLED_DIR=${VCPKG_INSTALLED}" \
            --config-settings="cmake.define.CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}" \
            --config-settings="cmake.define.VCPKG_TARGET_TRIPLET=x64-linux"

        if [ $? -eq 0 ]; then
            # Find the wheel that was just built
            WHEEL_FILE=$(ls -t wheelhouse/pycolmap-*.whl 2>/dev/null | head -n1)

            if [ -n "$WHEEL_FILE" ] && [ -f "$WHEEL_FILE" ]; then
                echo -e "  ${DARK_GRAY}Bundling shared libraries with auditwheel...${NC}"

                # Use auditwheel to bundle all shared libraries
                # Try manylinux_2_31 first (modern), fall back to manylinux2014 (broad compatibility)
                VCPKG_LIB_PATH="${VCPKG_INSTALLED}/x64-linux/lib"
                COLMAP_LIB_PATH="${COLMAP_INSTALL}/lib"

                export LD_LIBRARY_PATH="${VCPKG_LIB_PATH}:${COLMAP_LIB_PATH}:${LD_LIBRARY_PATH}"

                # Try modern manylinux first
                if "$python_cmd" -m auditwheel repair -w wheelhouse --plat manylinux_2_31_x86_64 "$WHEEL_FILE" 2>/dev/null; then
                    echo -e "  ${GREEN}Created manylinux_2_31_x86_64 wheel${NC}"
                    exit 0
                elif "$python_cmd" -m auditwheel repair -w wheelhouse --plat manylinux2014_x86_64 "$WHEEL_FILE" 2>/dev/null; then
                    echo -e "  ${GREEN}Created manylinux2014_x86_64 wheel${NC}"
                    exit 0
                else
                    echo -e "${RED}FAILED: auditwheel repair failed${NC}"
                    exit 1
                fi
            else
                echo -e "${RED}FAILED: No wheel file found${NC}"
                exit 1
            fi
        else
            echo -e "${RED}FAILED: Wheel build failed${NC}"
            exit 1
        fi
    )

    BUILD_RESULT=$?

    # Restore original PATH
    export PATH="$ORIGINAL_PATH"

    if [ $BUILD_RESULT -eq 0 ]; then
        SUCCESSFUL_BUILDS+=("Python $version")
        echo ""
        echo -e "${GREEN}SUCCESS: Wheel built for Python $version${NC}"
    else
        FAILED_BUILDS+=("Python $version")
        echo ""
        echo -e "${RED}FAILED: Build failed for Python $version${NC}"
    fi
done

# Summary
echo ""
echo "================================================================"
echo -e "${CYAN}Build Summary${NC}"
echo "================================================================"

if [ ${#SUCCESSFUL_BUILDS[@]} -gt 0 ]; then
    echo ""
    echo -e "${GREEN}Successful builds (${#SUCCESSFUL_BUILDS[@]}):${NC}"
    for build in "${SUCCESSFUL_BUILDS[@]}"; do
        echo -e "  ${GREEN}[OK] $build${NC}"
    done
fi

if [ ${#FAILED_BUILDS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed builds (${#FAILED_BUILDS[@]}):${NC}"
    for build in "${FAILED_BUILDS[@]}"; do
        echo -e "  ${RED}[FAIL] $build${NC}"
    done
fi

echo ""
echo -e "${CYAN}All wheels are in: third_party/colmap-for-pycolmap/wheelhouse/${NC}"

WHEELHOUSE_DIR="${COLMAP_SOURCE}/wheelhouse"
if [ -d "$WHEELHOUSE_DIR" ]; then
    WHEELS=$(ls -t "$WHEELHOUSE_DIR"/pycolmap-*.whl 2>/dev/null)
    if [ -n "$WHEELS" ]; then
        echo ""
        echo -e "${CYAN}Generated wheels:${NC}"
        for wheel in $WHEELS; do
            size=$(du -h "$wheel" | cut -f1)
            basename_wheel=$(basename "$wheel")
            echo "  - $basename_wheel ($size)"
        done
    fi
fi

echo ""
echo "================================================================"
if [ ${#FAILED_BUILDS[@]} -eq 0 ]; then
    echo -e "${GREEN}All wheels built successfully!${NC}"
else
    echo -e "${YELLOW}Some builds failed - see summary above${NC}"
fi
echo "================================================================"
