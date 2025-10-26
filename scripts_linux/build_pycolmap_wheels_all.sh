#!/bin/bash
# Build pycolmap wheels for all installed Python versions
# Usage: ./build_pycolmap_wheels_all.sh [Debug|Release] [options]

set -e

# Default configuration
BUILD_TYPE="Release"
NO_CUDA=false
CLEAN_BUILD=false
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SINGLE_WHEEL_SCRIPT="${SCRIPT_DIR}/build_pycolmap_wheel.sh"

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
            echo "This script automatically detects all Python 3.9+ installations and builds"
            echo "a wheel for each version."
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  Debug              Build in Debug mode"
            echo "  Release            Build in Release mode (default)"
            echo "  --no-cuda          Build without CUDA support"
            echo "  --clean            Clean build before each version"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Detection:"
            echo "  The script searches for Python installations in:"
            echo "  - Common python3.X commands (python3.9, python3.10, etc.)"
            echo "  - PATH environment variable"
            echo "  - Common installation directories (/usr/bin, /usr/local/bin)"
            echo ""
            echo "Requirements:"
            echo "  - COLMAP already built (run build_colmap.sh first)"
            echo "  - Multiple Python versions installed (3.9, 3.10, 3.11, 3.12, 3.13+)"
            echo ""
            echo "Output:"
            echo "  All wheels in: third_party/colmap/wheelhouse/"
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
echo "================================================================"

# Function to get Python version
get_python_version() {
    local python_exe="$1"

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

# Filter to Python 3.9+
declare -a VALID_PYTHONS
declare -a VALID_VERSIONS

for python_cmd in "${!PYTHON_VERSIONS[@]}"; do
    version="${PYTHON_VERSIONS[$python_cmd]}"
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)

    if [ "$major" -eq 3 ] && [ "$minor" -ge 9 ]; then
        VALID_PYTHONS+=("$python_cmd")
        VALID_VERSIONS+=("$version")
    fi
done

if [ ${#VALID_PYTHONS[@]} -eq 0 ]; then
    echo ""
    echo -e "${RED}ERROR: No Python 3.9+ installations found${NC}"
    echo ""
    echo -e "${YELLOW}To install multiple Python versions (Ubuntu):${NC}"
    echo "  sudo apt-get install python3.9 python3.9-dev"
    echo "  sudo apt-get install python3.10 python3.10-dev"
    echo "  sudo apt-get install python3.11 python3.11-dev"
    echo "  sudo apt-get install python3.12 python3.12-dev"
    exit 1
fi

echo ""
echo -e "${GREEN}Found ${#VALID_PYTHONS[@]} compatible Python version(s):${NC}"
for i in "${!VALID_PYTHONS[@]}"; do
    python_cmd="${VALID_PYTHONS[$i]}"
    version="${PYTHON_VERSIONS[$python_cmd]}"
    python_path=$(which "$python_cmd")
    echo "  - Python $version ($python_path)"
done

# Build wheel for each Python version
echo ""
echo "================================================================"
echo -e "${CYAN}Building wheels for all versions...${NC}"
echo "================================================================"

declare -a SUCCESSFUL_BUILDS
declare -a FAILED_BUILDS

for i in "${!VALID_PYTHONS[@]}"; do
    python_cmd="${VALID_PYTHONS[$i]}"
    version="${PYTHON_VERSIONS[$python_cmd]}"

    echo ""
    echo -e "${CYAN}[$((i+1))/${#VALID_PYTHONS[@]}] Building for Python $version...${NC}"
    echo "================================================================"

    # Temporarily modify PATH to prioritize this Python version
    ORIGINAL_PATH="$PATH"
    PYTHON_DIR=$(dirname "$(which "$python_cmd")")
    export PATH="$PYTHON_DIR:$ORIGINAL_PATH"

    # Build arguments
    BUILD_ARGS=("$BUILD_TYPE")
    if [ "$NO_CUDA" = true ]; then
        BUILD_ARGS+=("--no-cuda")
    fi
    if [ "$CLEAN_BUILD" = true ]; then
        BUILD_ARGS+=("--clean")
    fi

    # Run the single-version build script
    if bash "$SINGLE_WHEEL_SCRIPT" "${BUILD_ARGS[@]}"; then
        SUCCESSFUL_BUILDS+=("Python $version")
        echo ""
        echo -e "${GREEN}SUCCESS: Wheel built for Python $version${NC}"
    else
        FAILED_BUILDS+=("Python $version")
        echo ""
        echo -e "${RED}FAILED: Wheel build failed for Python $version${NC}"
    fi

    # Restore original PATH
    export PATH="$ORIGINAL_PATH"
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
echo -e "${CYAN}All wheels are in: third_party/colmap/wheelhouse/${NC}"

WHEELHOUSE_DIR="${SCRIPT_DIR}/../third_party/colmap/wheelhouse"
if [ -d "$WHEELHOUSE_DIR" ]; then
    WHEELS=$(ls -t "$WHEELHOUSE_DIR"/pycolmap-*.whl 2>/dev/null || true)
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
