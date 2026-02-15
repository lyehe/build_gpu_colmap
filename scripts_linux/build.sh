#!/bin/bash
# Build All - Point Cloud Tools Build Script
# Usage: ./build.sh [Debug|Release] [options]

set -e

# Default configuration
BUILD_TYPE="Release"
CLEAN_BUILD=false
NO_CUDA=false
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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
            echo "Build All - Point Cloud Tools"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "This script builds COLMAP (latest version) by calling build_colmap.sh."
            echo ""
            echo "Note: GLOMAP has been merged into COLMAP 3.14. Use 'colmap global_mapper' for global SfM."
            echo ""
            echo "Options:"
            echo "  Debug              Build in Debug mode"
            echo "  Release            Build in Release mode (default)"
            echo "  --no-cuda          Disable CUDA support"
            echo "  --clean            Clean build directory before building"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                   Build COLMAP"
            echo "  $0 --clean           Clean and rebuild"
            echo "  $0 --no-cuda         Build without CUDA support"
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Helper function to initialize submodules if not already done
initialize_submodule() {
    local submodule_path=$1
    local name=$2
    local full_path="${PROJECT_ROOT}/${submodule_path}"

    if [ ! -d "${full_path}/.git" ]; then
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
echo -e "${CYAN}Checking required submodules...${NC}"
initialize_submodule "third_party/vcpkg" "vcpkg"
initialize_submodule "third_party/ceres-solver" "Ceres Solver"
initialize_submodule "third_party/colmap" "COLMAP"
echo ""

# Bootstrap vcpkg if needed
VCPKG_ROOT="${PROJECT_ROOT}/third_party/vcpkg"
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

echo "================================================================"
echo -e "${CYAN}Point Cloud Tools - Build All${NC}"
echo "================================================================"
echo "Configuration: $BUILD_TYPE"
echo "CUDA: $(if [ "$NO_CUDA" = true ]; then echo 'Disabled'; else echo 'Enabled'; fi)"
echo "Components: COLMAP (latest)"
echo "================================================================"

# Build COLMAP
echo ""
echo -e "${GREEN}Building COLMAP (latest)...${NC}"

BUILD_ARGS=("$BUILD_TYPE")
if [ "$NO_CUDA" = true ]; then
    BUILD_ARGS+=("--no-cuda")
fi
if [ "$CLEAN_BUILD" = true ]; then
    BUILD_ARGS+=("--clean")
fi

COLMAP_SCRIPT="${SCRIPT_DIR}/build_colmap.sh"
bash "$COLMAP_SCRIPT" "${BUILD_ARGS[@]}"

if [ $? -ne 0 ]; then
    echo -e "${RED}COLMAP build failed${NC}"
    exit 1
fi

echo ""
echo "================================================================"
echo -e "${GREEN}Build completed successfully!${NC}"
echo "================================================================"
echo ""
echo -e "${CYAN}Note: GLOMAP has been merged into COLMAP 3.14.${NC}"
echo -e "${CYAN}Use 'colmap global_mapper' for global Structure-from-Motion.${NC}"
