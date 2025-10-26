#!/bin/bash
# Fast GLOMAP Build Script - Two-stage build for dependency resolution
# Usage: ./build_glomap.sh [Debug|Release] [options]

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
DARK_GRAY='\033[0;90m'
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
            echo "Fast GLOMAP Build Script (Two-stage Build)"
            echo ""
            echo "This script builds:"
            echo "  - Ceres Solver (dependency, if not already built)"
            echo "  - PoseLib (dependency, if not already built)"
            echo "  - COLMAP for GLOMAP (v3.11 - pinned for compatibility)"
            echo "  - GLOMAP (global structure-from-motion)"
            echo ""
            echo "Performance optimizations:"
            echo "  - Two-stage build (dependencies first, then GLOMAP)"
            echo "  - Automatic Ninja detection with fallback to Make"
            echo "  - Maximum CPU parallelism (75% of cores)"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  Debug              Build in Debug mode"
            echo "  Release            Build in Release mode (default)"
            echo "  --no-cuda          Disable CUDA support"
            echo "  --clean            Clean build directory before building"
            echo "  --jobs N, -j N     Use N parallel jobs (default: $OPTIMAL_JOBS)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Note:"
            echo "  GLOMAP requires a specific COLMAP version (3.11) which is built"
            echo "  separately from the latest COLMAP version."
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

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
initialize_submodule "third_party/poselib" "PoseLib"
initialize_submodule "third_party/colmap-for-glomap" "COLMAP for GLOMAP"
initialize_submodule "third_party/glomap" "GLOMAP"
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

echo "================================================================"
echo -e "${CYAN}Fast GLOMAP Build (Two-stage + Optimized)${NC}"
echo "================================================================"
echo "Modules: Ceres + PoseLib + COLMAP 3.11 + GLOMAP"
echo "Configuration: $BUILD_TYPE"
echo "CUDA Enabled: $CUDA_ENABLED"
echo "Parallel Jobs: $OPTIMAL_JOBS (of $NUM_JOBS cores)"

# Check if Ninja is available
if command -v ninja >/dev/null 2>&1; then
    NINJA_PATH=$(which ninja)
    echo "Generator: Ninja"
    echo -e "${GREEN}Ninja found: $NINJA_PATH${NC}"
    USE_NINJA=true
    CMAKE_GENERATOR="Ninja"
else
    echo "Generator: Unix Makefiles"
    echo -e "${YELLOW}WARNING: Ninja not found in PATH${NC}"
    echo -e "${YELLOW}Falling back to Unix Makefiles (slower)${NC}"
    echo ""
    echo -e "${CYAN}To install Ninja:${NC}"
    echo "  sudo apt-get install ninja-build"
    USE_NINJA=false
    CMAKE_GENERATOR="Unix Makefiles"
fi

echo "================================================================"

# Sync COLMAP version for GLOMAP compatibility
SYNC_SCRIPT="${SCRIPT_DIR}/sync_colmap_for_glomap.sh"
if [ -f "$SYNC_SCRIPT" ]; then
    echo ""
    echo -e "${YELLOW}Syncing COLMAP version for GLOMAP compatibility...${NC}"
    bash "$SYNC_SCRIPT"
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Warning: Failed to sync COLMAP version for GLOMAP${NC}"
        echo -e "${YELLOW}Build may continue but GLOMAP compatibility is not guaranteed${NC}"
    fi
fi

# Clean build directory if requested
if [ "$CLEAN_BUILD" = true ] && [ -d "$BUILD_DIR" ]; then
    echo ""
    echo -e "${YELLOW}Cleaning build directory...${NC}"
    rm -rf "$BUILD_DIR"
fi

# Create build directory
if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
fi

# Configure CMake
echo ""
echo -e "${GREEN}Configuring CMake for GLOMAP...${NC}"
cd "$BUILD_DIR"

cmake .. \
    -G "$CMAKE_GENERATOR" \
    -DCMAKE_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCUDA_ENABLED="$CUDA_ENABLED" \
    -DBUILD_CERES=ON \
    -DBUILD_COLMAP=OFF \
    -DBUILD_GLOMAP=ON

if [ $? -ne 0 ]; then
    echo -e "${RED}CMake configuration failed${NC}"
    exit 1
fi

# Build dependencies first (Ceres, PoseLib, COLMAP) before GLOMAP
# Note: cmake --build with ExternalProject automatically skips targets that are up-to-date
echo ""
echo -e "${GREEN}Building dependencies with $OPTIMAL_JOBS parallel jobs...${NC}"

echo -e "${CYAN}[1/4] Building Ceres Solver...${NC}"
if [ -f "install/ceres/lib/cmake/Ceres/CeresConfig.cmake" ]; then
    echo -e "${DARK_GRAY}  [Checking if rebuild needed...]${NC}"
fi
cmake --build . --target ceres-solver-external --config "$BUILD_TYPE" --parallel "$OPTIMAL_JOBS"
if [ $? -ne 0 ]; then
    echo -e "${RED}Ceres build failed${NC}"
    exit 1
fi

echo -e "${CYAN}[2/4] Building PoseLib...${NC}"
if [ -f "install/poselib/lib/cmake/PoseLib/PoseLibConfig.cmake" ]; then
    echo -e "${DARK_GRAY}  [Checking if rebuild needed...]${NC}"
fi
cmake --build . --target poselib-external-install --config "$BUILD_TYPE" --parallel "$OPTIMAL_JOBS"
if [ $? -ne 0 ]; then
    echo -e "${RED}PoseLib build failed${NC}"
    exit 1
fi

echo -e "${CYAN}[3/4] Building COLMAP for GLOMAP (v3.11)...${NC}"
if [ -f "install/colmap-for-glomap/lib/cmake/COLMAP/COLMAPConfig.cmake" ]; then
    echo -e "${DARK_GRAY}  [Checking if rebuild needed...]${NC}"
fi
cmake --build . --target colmap-for-glomap-external-install --config "$BUILD_TYPE" --parallel "$OPTIMAL_JOBS"
if [ $? -ne 0 ]; then
    echo -e "${RED}COLMAP build failed${NC}"
    exit 1
fi

# Now configure and build GLOMAP (dependencies are installed and available)
echo -e "${GREEN}[4/4] Building GLOMAP...${NC}"
if [ -f "install/glomap/lib/cmake/glomap/glomapConfig.cmake" ]; then
    echo -e "${DARK_GRAY}  [Checking if rebuild needed...]${NC}"
fi

# Create glomap build directory if it doesn't exist
GLOMAP_BUILD_DIR="glomap"
if [ ! -d "$GLOMAP_BUILD_DIR" ]; then
    mkdir -p "$GLOMAP_BUILD_DIR"
fi

# Configure GLOMAP separately now that dependencies are installed
echo -e "${CYAN}  Configuring GLOMAP...${NC}"
cd "$GLOMAP_BUILD_DIR"

GLOMAP_SOURCE="${PROJECT_ROOT}/third_party/glomap"
GLOMAP_INSTALL_DIR="${PROJECT_ROOT}/build/install/glomap"
CERES_DIR="${PROJECT_ROOT}/build/install/ceres"
POSELIB_DIR="${PROJECT_ROOT}/build/install/poselib"
COLMAP_DIR="${PROJECT_ROOT}/build/install/colmap-for-glomap"

cmake "$GLOMAP_SOURCE" \
    -G "$CMAKE_GENERATOR" \
    -DCMAKE_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_INSTALL_PREFIX="$GLOMAP_INSTALL_DIR" \
    -DCMAKE_PREFIX_PATH="${CERES_DIR};${POSELIB_DIR};${COLMAP_DIR}" \
    -DPoseLib_DIR="${POSELIB_DIR}/lib/cmake/PoseLib" \
    -DCOLMAP_DIR="${COLMAP_DIR}/lib/cmake/COLMAP" \
    -DFETCH_COLMAP=OFF \
    -DFETCH_POSELIB=OFF \
    -DCUDA_ENABLED="$CUDA_ENABLED" \
    -DCMAKE_CUDA_ARCHITECTURES="75;80;86;89;90;120"

if [ $? -ne 0 ]; then
    echo -e "${RED}GLOMAP configuration failed${NC}"
    exit 1
fi

# Build GLOMAP
echo -e "${CYAN}  Building GLOMAP...${NC}"
cmake --build . --config "$BUILD_TYPE" --parallel "$OPTIMAL_JOBS"

if [ $? -ne 0 ]; then
    echo -e "${RED}GLOMAP build failed${NC}"
    exit 1
fi

# Install GLOMAP
echo -e "${CYAN}  Installing GLOMAP...${NC}"
cmake --build . --config "$BUILD_TYPE" --target install

if [ $? -ne 0 ]; then
    echo -e "${RED}GLOMAP install failed${NC}"
    exit 1
fi

cd ..
cd ..

# Copy cuDSS libraries if cuDSS was found and enabled
if [ "$CUDA_ENABLED" = "ON" ]; then
    echo ""
    echo -e "${CYAN}Checking for cuDSS libraries to copy...${NC}"

    CUDSS_FOUND=false
    CUDSS_LIB_DIR=""

    # Check standard cuDSS installation locations on Linux
    CUDSS_SEARCH_PATHS=(
        "$CUDSS_ROOT"
        "/usr/local/cuda/lib64"
        "/usr/local/cuda/lib"
        "/opt/nvidia/cudss/lib64"
        "/opt/nvidia/cudss/lib"
    )

    for search_path in "${CUDSS_SEARCH_PATHS[@]}"; do
        if [ -n "$search_path" ] && [ -d "$search_path" ]; then
            if [ -f "$search_path/libcudss.so" ]; then
                CUDSS_LIB_DIR="$search_path"
                CUDSS_FOUND=true
                break
            fi
        fi
    done

    # Also check for versioned installations in /opt/nvidia/cudss
    if [ "$CUDSS_FOUND" = false ] && [ -d "/opt/nvidia/cudss" ]; then
        for version_dir in $(ls -d /opt/nvidia/cudss/v* 2>/dev/null | sort -r); do
            if [ -f "$version_dir/lib64/libcudss.so" ]; then
                CUDSS_LIB_DIR="$version_dir/lib64"
                CUDSS_FOUND=true
                break
            elif [ -f "$version_dir/lib/libcudss.so" ]; then
                CUDSS_LIB_DIR="$version_dir/lib"
                CUDSS_FOUND=true
                break
            fi
        done
    fi

    if [ "$CUDSS_FOUND" = true ]; then
        INSTALL_LIB="${BUILD_DIR}/install/glomap/lib"
        if [ -d "$INSTALL_LIB" ]; then
            echo -e "${YELLOW}  Copying cuDSS libraries from: ${CUDSS_LIB_DIR}${NC}"
            cp -f "$CUDSS_LIB_DIR"/libcudss*.so* "$INSTALL_LIB/" 2>/dev/null || true
            echo -e "${GREEN}  cuDSS libraries copied successfully${NC}"
        else
            echo -e "${YELLOW}  Warning: Install directory not found, skipping cuDSS library copy${NC}"
        fi
    else
        echo -e "  cuDSS not found - skipping library copy"
        echo -e "  (This is optional - GLOMAP will work without cuDSS)"
    fi
fi

echo ""
echo "================================================================"
echo -e "${GREEN}Fast GLOMAP build completed successfully!${NC}"
echo "Build artifacts: ${BUILD_DIR}"
echo ""
echo -e "${CYAN}Installations:${NC}"
echo "  Ceres:              ${BUILD_DIR}/install/ceres"
echo "  PoseLib:            ${BUILD_DIR}/install/poselib"
echo "  COLMAP for GLOMAP:  ${BUILD_DIR}/install/colmap-for-glomap"
echo "  GLOMAP:             ${BUILD_DIR}/install/glomap"
echo "================================================================"
