#!/bin/bash
# Build pycolmap wheel with bundled libraries
# Usage: ./build_pycolmap_wheel.sh [Debug|Release] [options]

set -e

# Default configuration
BUILD_TYPE="Release"
NO_CUDA=false
CLEAN_BUILD=false
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COLMAP_SOURCE="${PROJECT_ROOT}/third_party/colmap"
BUILD_DIR="${PROJECT_ROOT}/build"
COLMAP_INSTALL="${BUILD_DIR}/install/colmap"

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
            echo "Build pycolmap Python wheel with bundled libraries"
            echo ""
            echo "This script:"
            echo "  1. Ensures COLMAP is built and installed"
            echo "  2. Builds pycolmap Python bindings"
            echo "  3. Bundles all required shared libraries using auditwheel"
            echo "  4. Creates a redistributable .whl file"
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
            echo "Requirements:"
            echo "  - Python 3.9+ with pip"
            echo "  - COLMAP already built (run build_colmap.sh first)"
            echo "  - auditwheel (installed automatically)"
            echo ""
            echo "Output:"
            echo "  Wheel file: wheelhouse/pycolmap-*.whl"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --no-cuda"
            echo "  $0 --clean Debug"
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo "================================================================"
echo -e "${CYAN}Build pycolmap Wheel with Bundled Libraries${NC}"
echo "================================================================"
echo "Configuration: $BUILD_TYPE"
echo "CUDA: $(if [ "$NO_CUDA" = true ]; then echo 'Disabled'; else echo 'Enabled'; fi)"
echo "COLMAP Source: $COLMAP_SOURCE"
echo "COLMAP Install: $COLMAP_INSTALL"
echo "================================================================"

# Check if COLMAP is built
if [ ! -d "$COLMAP_INSTALL" ]; then
    echo ""
    echo -e "${RED}ERROR: COLMAP not found at $COLMAP_INSTALL${NC}"
    echo -e "${YELLOW}Please build COLMAP first:${NC}"
    echo "  ./scripts_linux/build_colmap.sh $BUILD_TYPE"
    exit 1
fi

# Verify COLMAP installation
COLMAP_BIN="${COLMAP_INSTALL}/bin/colmap"
if [ ! -f "$COLMAP_BIN" ]; then
    echo ""
    echo -e "${RED}ERROR: COLMAP executable not found at $COLMAP_BIN${NC}"
    echo -e "${YELLOW}COLMAP installation appears incomplete${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Found COLMAP installation at $COLMAP_INSTALL${NC}"

# Check Python installation
echo ""
echo -e "${YELLOW}Checking Python installation...${NC}"
if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}ERROR: python3 not found in PATH${NC}"
    echo -e "${YELLOW}Please install Python 3.9+ and add it to PATH${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}Python version: $PYTHON_VERSION${NC}"

# Check Python version (need 3.9+)
PYTHON_VERSION_NUM=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
MAJOR=$(echo $PYTHON_VERSION_NUM | cut -d. -f1)
MINOR=$(echo $PYTHON_VERSION_NUM | cut -d. -f2)

if [ "$MAJOR" -lt 3 ] || [ "$MAJOR" -eq 3 -a "$MINOR" -lt 9 ]; then
    echo -e "${RED}ERROR: Python 3.9+ required, found Python $PYTHON_VERSION_NUM${NC}"
    exit 1
fi

# Install build dependencies
echo ""
echo -e "${YELLOW}Installing Python build dependencies...${NC}"
python3 -m pip install --upgrade pip wheel build auditwheel patchelf
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to install Python dependencies${NC}"
    exit 1
fi

# Always clean build directory to avoid CMake cache issues
echo ""
echo -e "${YELLOW}Cleaning previous pycolmap build...${NC}"

PYCOLMAP_DIRS=(
    "${COLMAP_SOURCE}/build"
    "${COLMAP_SOURCE}/dist"
    "${COLMAP_SOURCE}/_skbuild"
    "${COLMAP_SOURCE}/python/pycolmap.egg-info"
)

for dir in "${PYCOLMAP_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        rm -rf "$dir"
        echo -e "${DARK_GRAY}  Removed: $dir${NC}"
    fi
done

# Set environment variables for build
echo ""
echo -e "${YELLOW}Configuring build environment...${NC}"

# Point to our COLMAP installation
VCPKG_ROOT="${PROJECT_ROOT}/third_party/vcpkg"
VCPKG_TOOLCHAIN="${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
VCPKG_INSTALLED="${BUILD_DIR}/vcpkg_installed/x64-linux"

export CMAKE_PREFIX_PATH="$COLMAP_INSTALL:$VCPKG_INSTALLED"
export COLMAP_INSTALL_PATH="$COLMAP_INSTALL"

# Use vcpkg toolchain so it can find all dependencies properly
# Pass CMake arguments to disable GUI/OpenGL features not needed for Python bindings
export CMAKE_ARGS="-DCMAKE_TOOLCHAIN_FILE=\"$VCPKG_TOOLCHAIN\" -DGUI_ENABLED=OFF -DOPENGL_ENABLED=OFF -DTESTS_ENABLED=OFF"

# Add COLMAP lib and vcpkg lib to LD_LIBRARY_PATH for runtime discovery
export LD_LIBRARY_PATH="${COLMAP_INSTALL}/lib:${COLMAP_INSTALL}/lib64:${VCPKG_INSTALLED}/lib:${LD_LIBRARY_PATH}"

echo -e "${DARK_GRAY}  CMAKE_PREFIX_PATH: $CMAKE_PREFIX_PATH${NC}"
echo -e "${DARK_GRAY}  COLMAP_INSTALL_PATH: $COLMAP_INSTALL_PATH${NC}"
echo -e "${DARK_GRAY}  CMAKE_ARGS: $CMAKE_ARGS${NC}"
echo -e "${DARK_GRAY}  LD_LIBRARY_PATH: ${COLMAP_INSTALL}/lib:${VCPKG_INSTALLED}/lib${NC}"

# Navigate to COLMAP source
cd "$COLMAP_SOURCE"

# Build the wheel
echo ""
echo -e "${GREEN}Building pycolmap wheel...${NC}"
echo -e "${DARK_GRAY}  This may take 10-15 minutes...${NC}"

# Use python -m build to create wheel
python3 -m build --wheel --outdir dist

if [ $? -ne 0 ]; then
    echo -e "${RED}Wheel build failed${NC}"
    exit 1
fi

# Find the generated wheel
WHEEL_FILE=$(ls -t dist/pycolmap-*.whl 2>/dev/null | head -1)
if [ -z "$WHEEL_FILE" ]; then
    echo -e "${RED}No wheel file found in dist/${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Wheel built successfully: $(basename $WHEEL_FILE)${NC}"

# Bundle libraries using auditwheel
echo ""
echo -e "${GREEN}Bundling shared libraries with auditwheel...${NC}"
echo -e "${DARK_GRAY}  This will include all required .so files in the wheel${NC}"

# Create wheelhouse directory for repaired wheels
WHEELHOUSE_DIR="${COLMAP_SOURCE}/wheelhouse"
mkdir -p "$WHEELHOUSE_DIR"

# Run auditwheel to bundle libraries
# --plat manylinux_2_31_x86_64 is for modern Linux (glibc 2.31+)
# Use manylinux2014_x86_64 for broader compatibility
auditwheel repair \
    --plat manylinux_2_31_x86_64 \
    --wheel-dir "$WHEELHOUSE_DIR" \
    "$WHEEL_FILE"

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}WARNING: auditwheel failed with manylinux_2_31, trying manylinux2014...${NC}"

    # Fallback to older manylinux for compatibility
    auditwheel repair \
        --plat manylinux2014_x86_64 \
        --wheel-dir "$WHEELHOUSE_DIR" \
        "$WHEEL_FILE"

    if [ $? -ne 0 ]; then
        echo -e "${RED}auditwheel failed to bundle libraries${NC}"
        echo -e "${YELLOW}The wheel may still work but won't be portable${NC}"
        echo -e "${YELLOW}Using original wheel: $WHEEL_FILE${NC}"
        cp "$WHEEL_FILE" "$WHEELHOUSE_DIR/"
    fi
fi

# Find the repaired wheel
REPAIRED_WHEEL=$(ls -t "$WHEELHOUSE_DIR"/pycolmap-*.whl 2>/dev/null | head -1)
if [ -z "$REPAIRED_WHEEL" ]; then
    echo -e "${RED}No repaired wheel found in wheelhouse/${NC}"
    exit 1
fi

WHEEL_SIZE=$(du -h "$REPAIRED_WHEEL" | cut -f1)

echo ""
echo "================================================================"
echo -e "${GREEN}pycolmap wheel build completed successfully!${NC}"
echo "================================================================"
echo ""
echo -e "${CYAN}Wheel file (with bundled libraries):${NC}"
echo "  $REPAIRED_WHEEL"
echo ""
echo -e "${CYAN}Wheel size: $WHEEL_SIZE${NC}"
echo ""
echo -e "${CYAN}To install:${NC}"
echo "  pip install \"$REPAIRED_WHEEL\""
echo ""
echo -e "${CYAN}To test:${NC}"
echo "  python3 -c \"import pycolmap; print(pycolmap.__version__)\""
echo "================================================================"
