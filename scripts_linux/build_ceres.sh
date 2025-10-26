#!/bin/bash
# Build script for Ceres Solver on Linux
# Usage: ./build_ceres.sh [Debug|Release] [options]

set -e

# Default configuration
BUILD_TYPE="Release"
CUDA_ENABLED="ON"
BUILD_DIR="build"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VCPKG_ROOT="${PROJECT_ROOT}/third_party/vcpkg"
NUM_JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Calculate optimal job count (75% of cores)
OPTIMAL_JOBS=$((NUM_JOBS * 3 / 4))
if [ $OPTIMAL_JOBS -lt 1 ]; then
    OPTIMAL_JOBS=1
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse command line arguments
CLEAN_BUILD=false
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
            CUDA_ENABLED="OFF"
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --jobs|-j)
            OPTIMAL_JOBS="$2"
            shift 2
            ;;
        --help|-h)
            echo "Build Ceres Solver"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  Debug           Build in Debug mode"
            echo "  Release         Build in Release mode (default)"
            echo "  --no-cuda       Disable CUDA support"
            echo "  --clean         Clean build directory before building"
            echo "  --jobs N, -j N  Use N parallel jobs (default: $NUM_JOBS)"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    Build Ceres in Release mode with CUDA"
            echo "  $0 Debug              Build in Debug mode"
            echo "  $0 --no-cuda          Build without CUDA support"
            echo "  $0 --clean            Clean and build"
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo "================================================================"
echo -e "${CYAN}Fast Ceres Solver Build (Optimized)${NC}"
echo "================================================================"
echo "Module: Ceres Solver only"
echo "Configuration: $BUILD_TYPE"
echo "CUDA Enabled: $CUDA_ENABLED"
echo "Parallel Jobs: $OPTIMAL_JOBS (of $NUM_JOBS cores)"

# Check if Ninja is available
if command -v ninja >/dev/null 2>&1; then
    NINJA_PATH=$(which ninja)
    echo "Generator: Ninja"
    echo -e "${GREEN}Ninja found: $NINJA_PATH${NC}"
    CMAKE_GENERATOR="Ninja"
else
    echo "Generator: Unix Makefiles"
    echo -e "${YELLOW}WARNING: Ninja not found in PATH${NC}"
    echo -e "${YELLOW}Falling back to Unix Makefiles (slower)${NC}"
    echo ""
    echo -e "${CYAN}To install Ninja:${NC}"
    echo "  sudo apt-get install ninja-build"
    CMAKE_GENERATOR="Unix Makefiles"
fi

echo "================================================================"

# Warn if system vcpkg environment variables are set
if [ -n "$VCPKG_ROOT" ] || [ -n "$VCPKG_INSTALLATION_ROOT" ]; then
    echo ""
    echo -e "${YELLOW}WARNING: System vcpkg environment variables detected!${NC}"
    [ -n "$VCPKG_ROOT" ] && echo -e "${YELLOW}  VCPKG_ROOT = $VCPKG_ROOT${NC}"
    [ -n "$VCPKG_INSTALLATION_ROOT" ] && echo -e "${YELLOW}  VCPKG_INSTALLATION_ROOT = $VCPKG_INSTALLATION_ROOT${NC}"
    echo ""
    echo -e "${GREEN}This build will use the LOCAL vcpkg submodule at:${NC}"
    echo "  ${SCRIPT_DIR}/../third_party/vcpkg"
    echo ""
    echo -e "${GREEN}To avoid confusion, consider unsetting system vcpkg variables:${NC}"
    echo -e "${NC}  unset VCPKG_ROOT${NC}"
    echo -e "${NC}  unset VCPKG_INSTALLATION_ROOT${NC}"
    echo ""
fi

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR" ]; then
    echo -e "${YELLOW}Cleaning build directory...${NC}"
    rm -rf "$BUILD_DIR"
fi

# Check if vcpkg is bootstrapped
if [ ! -f "${VCPKG_ROOT}/vcpkg" ]; then
    echo ""
    echo -e "${YELLOW}Bootstrapping vcpkg...${NC}"
    "${VCPKG_ROOT}/bootstrap-vcpkg.sh"
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to bootstrap vcpkg${NC}"
        exit 1
    fi
fi

# Update vcpkg.json with current vcpkg baseline commit if using "latest"
VCPKG_JSON="${SCRIPT_DIR}/../vcpkg.json"
if grep -q '"builtin-baseline": "latest"' "$VCPKG_JSON" 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}Detecting vcpkg baseline commit...${NC}"
    pushd "${VCPKG_ROOT}" > /dev/null
    VCPKG_COMMIT=$(git rev-parse HEAD 2>/dev/null)
    if [ $? -eq 0 ] && [ ${#VCPKG_COMMIT} -eq 40 ]; then
        echo "  Setting vcpkg baseline to: $VCPKG_COMMIT"
        sed -i "s/\"builtin-baseline\": \"latest\"/\"builtin-baseline\": \"$VCPKG_COMMIT\"/" "$VCPKG_JSON"
    else
        echo -e "${YELLOW}  Warning: Could not detect vcpkg commit, keeping 'latest'${NC}"
    fi
    popd > /dev/null
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Configure CMake
echo ""
echo -e "${GREEN}Configuring CMake for Ceres Solver...${NC}"
cd "$BUILD_DIR"
cmake .. \
    -G "$CMAKE_GENERATOR" \
    -DCMAKE_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCUDA_ENABLED="$CUDA_ENABLED" \
    -DBUILD_CERES=ON \
    -DBUILD_COLMAP=OFF \
    -DBUILD_GLOMAP=OFF

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: CMake configuration failed${NC}"
    exit 1
fi

# Build
echo ""
echo -e "${GREEN}Building Ceres Solver...${NC}"
cmake --build . --config "$BUILD_TYPE" --parallel "$OPTIMAL_JOBS"

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Build failed${NC}"
    exit 1
fi

cd ..
cd ..
echo ""
echo "================================================================"
echo -e "${GREEN}Fast Ceres Solver build completed successfully!${NC}"
echo "Build artifacts: $BUILD_DIR"
echo "================================================================"
