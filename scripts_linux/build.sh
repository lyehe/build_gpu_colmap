#!/bin/bash
# Build All - Point Cloud Tools Build Script
# Usage: ./build.sh [Debug|Release] [options]

set -e

# Default configuration
BUILD_TYPE="Release"
SKIP_COLMAP=false
SKIP_GLOMAP=false
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
        --skip-glomap)
            SKIP_GLOMAP=true
            shift
            ;;
        --skip-colmap)
            SKIP_COLMAP=true
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
            echo "This script builds all components by calling individual build scripts:"
            echo "  - COLMAP (latest version) - unless --skip-colmap"
            echo "  - GLOMAP (with dependencies: Ceres, PoseLib, COLMAP v3.11) - unless --skip-glomap"
            echo ""
            echo "Options:"
            echo "  Debug              Build in Debug mode"
            echo "  Release            Build in Release mode (default)"
            echo "  --no-cuda          Disable CUDA support"
            echo "  --skip-glomap      Skip GLOMAP build"
            echo "  --skip-colmap      Skip COLMAP (latest) build"
            echo "  --clean            Clean build directory before building"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                   Build both COLMAP and GLOMAP"
            echo "  $0 --skip-glomap     Build only COLMAP (latest)"
            echo "  $0 --skip-colmap     Build only GLOMAP"
            echo "  $0 --clean           Clean and rebuild everything"
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

# Initialize required submodules based on what will be built
echo -e "${CYAN}Checking required submodules...${NC}"
initialize_submodule "third_party/vcpkg" "vcpkg"
initialize_submodule "third_party/ceres-solver" "Ceres Solver"

if [ "$SKIP_COLMAP" = false ]; then
    initialize_submodule "third_party/colmap" "COLMAP"
fi

if [ "$SKIP_GLOMAP" = false ]; then
    initialize_submodule "third_party/poselib" "PoseLib"
    initialize_submodule "third_party/colmap-for-glomap" "COLMAP for GLOMAP"
    initialize_submodule "third_party/glomap" "GLOMAP"
fi
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

COMPONENTS=()
if [ "$SKIP_COLMAP" = false ]; then
    COMPONENTS+=("COLMAP (latest)")
fi
if [ "$SKIP_GLOMAP" = false ]; then
    COMPONENTS+=("GLOMAP")
fi

if [ ${#COMPONENTS[@]} -eq 0 ]; then
    echo -e "${RED}Error: Nothing to build (both --skip-colmap and --skip-glomap specified)${NC}"
    exit 1
fi

echo "Components: ${COMPONENTS[*]}"
echo "================================================================"

# Build COLMAP (latest) first if requested
if [ "$SKIP_COLMAP" = false ]; then
    echo ""
    echo -e "${GREEN}Building COLMAP (latest)...${NC}"

    BUILD_ARGS=("$BUILD_TYPE")
    if [ "$NO_CUDA" = true ]; then
        BUILD_ARGS+=("--no-cuda")
    fi
    if [ "$CLEAN_BUILD" = true ]; then
        BUILD_ARGS+=("--clean")
        CLEAN_BUILD=false  # Only clean once
    fi

    COLMAP_SCRIPT="${SCRIPT_DIR}/build_colmap.sh"
    bash "$COLMAP_SCRIPT" "${BUILD_ARGS[@]}"

    if [ $? -ne 0 ]; then
        echo -e "${RED}COLMAP build failed${NC}"
        exit 1
    fi
fi

# Build GLOMAP (with dependencies) if requested
if [ "$SKIP_GLOMAP" = false ]; then
    echo ""
    echo -e "${GREEN}Building GLOMAP...${NC}"

    BUILD_ARGS=("$BUILD_TYPE")
    if [ "$NO_CUDA" = true ]; then
        BUILD_ARGS+=("--no-cuda")
    fi
    if [ "$CLEAN_BUILD" = true ]; then
        BUILD_ARGS+=("--clean")
    fi

    GLOMAP_SCRIPT="${SCRIPT_DIR}/build_glomap.sh"
    bash "$GLOMAP_SCRIPT" "${BUILD_ARGS[@]}"

    if [ $? -ne 0 ]; then
        echo -e "${RED}GLOMAP build failed${NC}"
        exit 1
    fi
fi

echo ""
echo "================================================================"
echo -e "${GREEN}All builds completed successfully!${NC}"
echo "================================================================"
