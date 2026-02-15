#!/bin/bash
# Build Environment Verification Script for Linux
# This script checks all required build tools and dependencies
# Usage: ./verify_build_environment.sh [--no-cuda]

set +e  # Don't exit on errors, we want to check everything

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Track overall status
ALL_CHECKS_PASSED=true
WARNINGS=()
ERRORS=()
CHECK_CUDA=true

# Show help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script verifies that all required build tools and dependencies are available."
    echo ""
    echo "Options:"
    echo "  --no-cuda       Skip CUDA toolkit verification"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              Verify all tools including CUDA"
    echo "  $0 --no-cuda    Skip CUDA verification"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cuda)
            CHECK_CUDA=false
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# Helper function to check command availability
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Helper function to compare versions
version_ge() {
    # Returns 0 (true) if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# Helper function to print status
print_status() {
    local name="$1"
    local passed="$2"
    local version="$3"
    local error_msg="$4"
    local solution="$5"

    if [ "$passed" = true ]; then
        printf "%-30s ${GREEN}[OK]${NC}" "$name"
        if [ -n "$version" ]; then
            echo -e " ${GRAY}- $version${NC}"
        else
            echo ""
        fi
    else
        printf "%-30s ${RED}[FAIL]${NC}\n" "$name"
        echo -e "  ${RED}ERROR: $error_msg${NC}"
        echo -e "  ${YELLOW}SOLUTION: $solution${NC}"
        echo ""
        ALL_CHECKS_PASSED=false
        ERRORS+=("$name")
    fi
}

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}Build Environment Verification for Linux${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Check 1: Bash Version
echo -e "${YELLOW}[1/11] Checking Bash...${NC}"
BASH_VERSION_NUM="${BASH_VERSION%%.*}"
if [ "$BASH_VERSION_NUM" -ge 4 ]; then
    print_status "Bash" true "v$BASH_VERSION"
else
    print_status "Bash" false "v$BASH_VERSION" \
        "Bash 4.0 or later is recommended" \
        "Update Bash: sudo apt-get update && sudo apt-get install bash (Debian/Ubuntu) or sudo yum install bash (RHEL/CentOS)"
fi

# Check 2: GCC/G++
echo -e "${YELLOW}[2/11] Checking GCC/G++ Compiler...${NC}"
if command_exists gcc && command_exists g++; then
    GCC_VERSION=$(gcc --version | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1)
    GCC_MAJOR=$(echo "$GCC_VERSION" | cut -d. -f1)

    if [ "$GCC_MAJOR" -ge 9 ]; then
        print_status "GCC/G++" true "v$GCC_VERSION"
    else
        print_status "GCC/G++" false "v$GCC_VERSION (too old)" \
            "GCC 9 or later is recommended (found $GCC_VERSION)" \
            "Update GCC: sudo apt-get install gcc-11 g++-11 (Debian/Ubuntu) or sudo yum install gcc-toolset-11 (RHEL/CentOS)"
    fi
else
    print_status "GCC/G++" false "" \
        "GCC/G++ compiler not found" \
        "Install build-essential: sudo apt-get install build-essential (Debian/Ubuntu) or sudo yum groupinstall 'Development Tools' (RHEL/CentOS)"
fi

# Check 3: CMake
echo -e "${YELLOW}[3/11] Checking CMake...${NC}"
if command_exists cmake; then
    CMAKE_VERSION=$(cmake --version | head -n1 | grep -oP '\d+\.\d+\.\d+' | head -n1)

    if version_ge "$CMAKE_VERSION" "3.28"; then
        print_status "CMake" true "v$CMAKE_VERSION"
    else
        print_status "CMake" false "v$CMAKE_VERSION (too old)" \
            "CMake 3.28 or later is required (found $CMAKE_VERSION)" \
            "Download from: https://cmake.org/download/ or use: pip3 install cmake --upgrade"
    fi
else
    print_status "CMake" false "" \
        "CMake not found" \
        "Install CMake: sudo apt-get install cmake (Debian/Ubuntu) or sudo yum install cmake (RHEL/CentOS) or pip3 install cmake"
fi

# Check 4: Make
echo -e "${YELLOW}[4/11] Checking Make...${NC}"
if command_exists make; then
    MAKE_VERSION=$(make --version | head -n1 | grep -oP '\d+\.\d+' | head -n1)
    print_status "Make" true "v$MAKE_VERSION"
else
    print_status "Make" false "" \
        "Make not found" \
        "Install: sudo apt-get install build-essential (Debian/Ubuntu) or sudo yum groupinstall 'Development Tools' (RHEL/CentOS)"
fi

# Check 5: Git
echo -e "${YELLOW}[5/11] Checking Git...${NC}"
if command_exists git; then
    GIT_VERSION=$(git --version | grep -oP '\d+\.\d+\.\d+' | head -n1)
    print_status "Git" true "v$GIT_VERSION"
else
    print_status "Git" false "" \
        "Git not found" \
        "Install Git: sudo apt-get install git (Debian/Ubuntu) or sudo yum install git (RHEL/CentOS)"
fi

# Check 6: Python3
echo -e "${YELLOW}[6/11] Checking Python3...${NC}"
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -n1)
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

    if [ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
        print_status "Python3" true "v$PYTHON_VERSION"
    else
        print_status "Python3" false "v$PYTHON_VERSION (too old)" \
            "Python 3.8 or later is required for PyCeres (found $PYTHON_VERSION)" \
            "Install Python 3.8+: sudo apt-get install python3.10 python3-pip (Debian/Ubuntu) or sudo yum install python39 (RHEL/CentOS)"
    fi
else
    print_status "Python3" false "" \
        "Python3 not found (required for PyCeres)" \
        "Install Python3: sudo apt-get install python3 python3-pip (Debian/Ubuntu) or sudo yum install python3 (RHEL/CentOS)"
fi

# Check 7: Python dev headers
echo -e "${YELLOW}[7/11] Checking Python development headers...${NC}"
if command_exists python3-config || [ -f "/usr/include/python3"*"/Python.h" ] 2>/dev/null; then
    print_status "Python Dev Headers" true "Found"
else
    print_status "Python Dev Headers" false "" \
        "Python development headers not found (required for PyCeres)" \
        "Install: sudo apt-get install python3-dev (Debian/Ubuntu) or sudo yum install python3-devel (RHEL/CentOS)"
fi

# Check 8: CUDA Toolkit (if requested)
if [ "$CHECK_CUDA" = true ]; then
    echo -e "${YELLOW}[8/11] Checking CUDA Toolkit...${NC}"

    if command_exists nvcc; then
        NVCC_VERSION=$(nvcc --version | grep "release" | grep -oP '\d+\.\d+' | head -n1)
        CUDA_MAJOR=$(echo "$NVCC_VERSION" | cut -d. -f1)

        if [ "$CUDA_MAJOR" -ge 11 ]; then
            print_status "CUDA Toolkit (nvcc)" true "v$NVCC_VERSION"
        else
            print_status "CUDA Toolkit (nvcc)" false "v$NVCC_VERSION (too old)" \
                "CUDA 11.0 or later is recommended (found $NVCC_VERSION)" \
                "Download from: https://developer.nvidia.com/cuda-downloads"
        fi
    else
        print_status "CUDA Toolkit (nvcc)" false "" \
            "CUDA Toolkit not found or nvcc not in PATH" \
            "Download and install CUDA Toolkit 11.0+ from: https://developer.nvidia.com/cuda-downloads
After installation, ensure /usr/local/cuda/bin is in your PATH:
  export PATH=/usr/local/cuda/bin:\$PATH
  export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH

To build without CUDA, use: --no-cuda flag with build scripts"
    fi

    # Check for CUDA installation directory
    if [ -d "/usr/local/cuda" ]; then
        CUDA_PATH="/usr/local/cuda"
        print_status "CUDA Installation" true "$CUDA_PATH"
    else
        if command_exists nvcc; then
            WARNINGS+=("CUDA directory /usr/local/cuda not found (but nvcc found in PATH)")
            echo -e "  ${YELLOW}WARNING: /usr/local/cuda directory not found${NC}"
            echo ""
        fi
    fi

    # Check for cuDSS (CUDA Direct Sparse Solver) - optional but useful for COLMAP
    CUDSS_FOUND=false
    CUDSS_LOCATION=""

    # Check multiple possible cuDSS locations
    if [ -n "$CUDSS_ROOT" ] && [ -f "$CUDSS_ROOT/include/cudss.h" ]; then
        if [ -f "$CUDSS_ROOT/lib64/libcudss.so" ] || [ -f "$CUDSS_ROOT/lib/libcudss.so" ]; then
            CUDSS_FOUND=true
            CUDSS_LOCATION="Environment variable (\$CUDSS_ROOT)"
        fi
    elif [ -f "/usr/local/cuda/include/cudss.h" ] && [ -f "/usr/local/cuda/lib64/libcudss.so" ]; then
        CUDSS_FOUND=true
        CUDSS_LOCATION="/usr/local/cuda"
    elif [ -d "/opt/nvidia/cudss" ] && [ -f "/opt/nvidia/cudss/include/cudss.h" ]; then
        if [ -f "/opt/nvidia/cudss/lib64/libcudss.so" ] || [ -f "/opt/nvidia/cudss/lib/libcudss.so" ]; then
            CUDSS_FOUND=true
            CUDSS_LOCATION="/opt/nvidia/cudss"
        fi
    elif [ -d "/opt/cudss" ] && [ -f "/opt/cudss/include/cudss.h" ]; then
        if [ -f "/opt/cudss/lib64/libcudss.so" ] || [ -f "/opt/cudss/lib/libcudss.so" ]; then
            CUDSS_FOUND=true
            CUDSS_LOCATION="/opt/cudss"
        fi
    fi

    if [ "$CUDSS_FOUND" = true ]; then
        print_status "cuDSS (CUDA Sparse Solver)" true "Found at $CUDSS_LOCATION"
    else
        echo -e "cuDSS (CUDA Sparse Solver)    ${YELLOW}[NOT FOUND]${NC}"
        echo -e "  ${CYAN}NOTE: cuDSS is optional but provides significant performance improvements for sparse solvers${NC}"
        echo -e "  ${CYAN}INSTALL: Download from https://developer.nvidia.com/cudss-downloads${NC}"
        echo -e "  ${CYAN}         See docs/INSTALL_CUDSS.md for installation instructions${NC}"
        echo ""
    fi
else
    echo -e "${GRAY}[8/11] Skipping CUDA check (disabled)${NC}"
fi

# Check 9: Ninja (optional but recommended)
echo -e "${YELLOW}[9/11] Checking Ninja Build System (optional)...${NC}"
if command_exists ninja; then
    NINJA_VERSION=$(ninja --version)
    print_status "Ninja" true "v$NINJA_VERSION"
else
    echo -e "Ninja                         ${YELLOW}[NOT FOUND]${NC}"
    echo -e "  ${CYAN}NOTE: Ninja is optional but recommended for faster builds${NC}"
    echo -e "  ${CYAN}INSTALL: sudo apt-get install ninja-build (Debian/Ubuntu) or sudo yum install ninja-build (RHEL/CentOS)${NC}"
    echo ""
fi

# Check 10: vcpkg (check if submodule exists)
echo -e "${YELLOW}[10/11] Checking vcpkg submodule...${NC}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
VCPKG_PATH="$PROJECT_ROOT/third_party/vcpkg"
VCPKG_EXE="$VCPKG_PATH/vcpkg"

if [ -d "$VCPKG_PATH" ]; then
    if [ -f "$VCPKG_EXE" ]; then
        print_status "vcpkg" true "Bootstrapped"
    else
        echo -e "vcpkg                         ${YELLOW}[NOT BOOTSTRAPPED]${NC}"
        echo -e "  ${CYAN}NOTE: vcpkg submodule exists but is not bootstrapped${NC}"
        echo -e "  ${CYAN}RUN: ./scripts_linux/bootstrap.sh${NC}"
        echo ""
    fi
else
    echo -e "vcpkg                         ${YELLOW}[NOT INITIALIZED]${NC}"
    echo -e "  ${CYAN}NOTE: vcpkg submodule not initialized${NC}"
    echo -e "  ${CYAN}RUN: git submodule update --init --recursive${NC}"
    echo ""
fi

# Check 11: Disk Space
echo -e "${YELLOW}[11/11] Checking available disk space...${NC}"
AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')

if [ "$AVAILABLE_SPACE" -gt 50 ]; then
    print_status "Disk Space" true "${AVAILABLE_SPACE} GB available"
elif [ "$AVAILABLE_SPACE" -gt 20 ]; then
    print_status "Disk Space" true "${AVAILABLE_SPACE} GB available (warning: may be insufficient)"
    WARNINGS+=("Low disk space (${AVAILABLE_SPACE} GB) - build may require 30-50 GB")
else
    print_status "Disk Space" false "${AVAILABLE_SPACE} GB available" \
        "Insufficient disk space for build (at least 30-50 GB recommended)" \
        "Free up disk space on the current filesystem"
fi

# Summary
echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}Verification Summary${NC}"
echo -e "${CYAN}================================================================${NC}"

if [ "$ALL_CHECKS_PASSED" = true ]; then
    echo ""
    echo -e "${GREEN}All critical checks passed!${NC}"
    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}Warnings (${#WARNINGS[@]}):${NC}"
        for warning in "${WARNINGS[@]}"; do
            echo -e "  ${YELLOW}- $warning${NC}"
        done
    fi
    echo ""
    echo -e "${CYAN}You can proceed with building:${NC}"
    echo -e "${NC}  ./scripts_linux/build.sh Release${NC}"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}Some checks failed. Please fix the errors above before building.${NC}"
    echo ""
    echo -e "${RED}Failed checks (${#ERRORS[@]}):${NC}"
    for error in "${ERRORS[@]}"; do
        echo -e "  ${RED}- $error${NC}"
    done
    echo ""
    echo -e "${YELLOW}After fixing issues, run this script again to verify.${NC}"
    echo ""
    exit 1
fi
