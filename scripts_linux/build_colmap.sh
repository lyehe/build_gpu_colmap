#!/bin/bash
# Build script for COLMAP (latest) on Linux
# Usage: ./build_colmap.sh [Debug|Release] [options]

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
            echo "Build COLMAP (latest) and dependencies"
            echo ""
            echo "This script builds:"
            echo "  - Ceres Solver (dependency)"
            echo "  - COLMAP (latest version)"
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
            echo "  $0                    Build COLMAP in Release mode with CUDA"
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
echo -e "${CYAN}Fast COLMAP Build (Optimized)${NC}"
echo "================================================================"
echo "Modules: Ceres Solver + COLMAP (latest)"
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
echo -e "${GREEN}Configuring CMake for COLMAP...${NC}"
cd "$BUILD_DIR"
# Set vcpkg manifest features based on CUDA
if [ "$CUDA_ENABLED" = "ON" ]; then
    VCPKG_FEATURES="cgal;cuda"
else
    VCPKG_FEATURES="cgal"
fi

cmake .. \
    -G "$CMAKE_GENERATOR" \
    -DCMAKE_TOOLCHAIN_FILE="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCUDA_ENABLED="$CUDA_ENABLED" \
    -DBUILD_CERES=ON \
    -DBUILD_COLMAP=ON \
    -DBUILD_GLOMAP=OFF \
    -DVCPKG_MANIFEST_FEATURES="$VCPKG_FEATURES"

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: CMake configuration failed${NC}"
    exit 1
fi

# Build
echo ""
echo -e "${GREEN}Building COLMAP and dependencies...${NC}"
cmake --build . --config "$BUILD_TYPE" --parallel "$OPTIMAL_JOBS"

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Build failed${NC}"
    exit 1
fi

# Copy all runtime dependencies to make COLMAP fully self-contained
echo ""
echo -e "${CYAN}Copying runtime dependencies...${NC}"

COLMAP_LIB="$BUILD_DIR/install/colmap/lib"

# 1. Copy CUDA runtime libraries if CUDA is enabled
if [ "$CUDA_ENABLED" = "ON" ]; then
    CUDA_LIB_PATHS=(
        "${CUDA_HOME}/lib64"
        "/usr/local/cuda/lib64"
        "/usr/local/cuda/lib"
    )

    CUDA_LIB_FOUND=false
    for CUDA_LIB_PATH in "${CUDA_LIB_PATHS[@]}"; do
        if [ -d "$CUDA_LIB_PATH" ]; then
            echo -e "${DARK_GRAY}  Copying CUDA runtime libraries from: ${CUDA_LIB_PATH}${NC}"

            # Copy essential CUDA runtime libraries
            CUDA_LIBS=(
                "libcudart.so*"
                "libcurand.so*"
                "libcublas.so*"
                "libcublasLt.so*"
                "libcusparse.so*"
                "libcusolver.so*"
                "libcufft.so*"
            )

            for pattern in "${CUDA_LIBS[@]}"; do
                cp -f "$CUDA_LIB_PATH"/$pattern "$COLMAP_LIB/" 2>/dev/null || true
            done

            CUDA_LIB_FOUND=true
            echo -e "${GREEN}    CUDA runtime libraries copied${NC}"
            break
        fi
    done

    if [ "$CUDA_LIB_FOUND" = false ]; then
        echo -e "${YELLOW}    Warning: CUDA lib directory not found, CUDA libraries not copied${NC}"
    fi
fi

# 2. Ensure all vcpkg dependencies are present
VCPKG_LIB="$BUILD_DIR/vcpkg_installed/x64-linux/lib"
if [ -d "$VCPKG_LIB" ]; then
    echo -e "${DARK_GRAY}  Ensuring all vcpkg dependencies are present...${NC}"
    # Only copy libraries that don't already exist (avoid overwriting)
    for lib in "$VCPKG_LIB"/*.so*; do
        if [ -f "$lib" ]; then
            LIB_NAME=$(basename "$lib")
            DEST_FILE="$COLMAP_LIB/$LIB_NAME"
            if [ ! -e "$DEST_FILE" ]; then
                cp -f "$lib" "$COLMAP_LIB/" 2>/dev/null || true
            fi
        fi
    done
    echo -e "${GREEN}    All vcpkg dependencies ensured${NC}"
fi

FINAL_COUNT=$(ls -1 "$COLMAP_LIB" 2>/dev/null | wc -l)
echo -e "${CYAN}  Total files in COLMAP lib: ${FINAL_COUNT}${NC}"

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
        INSTALL_LIB="$BUILD_DIR/install/colmap/lib"
        if [ -d "$INSTALL_LIB" ]; then
            echo -e "${YELLOW}  Copying cuDSS libraries from: ${CUDSS_LIB_DIR}${NC}"
            cp -f "$CUDSS_LIB_DIR"/libcudss*.so* "$INSTALL_LIB/" 2>/dev/null || true
            echo -e "${GREEN}  cuDSS libraries copied successfully${NC}"
        else
            echo -e "${YELLOW}  Warning: Install directory not found, skipping cuDSS library copy${NC}"
        fi
    else
        echo -e "  cuDSS not found - skipping library copy"
        echo -e "  (This is optional - COLMAP will work without cuDSS)"
    fi
fi

cd ..
cd ..
echo ""
echo "================================================================"
echo -e "${GREEN}Fast COLMAP build completed successfully!${NC}"
echo "Build artifacts: $BUILD_DIR"
echo "================================================================"
