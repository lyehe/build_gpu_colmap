#!/bin/bash
# Complete setup script for a new Point Cloud Tools repository
# This script initializes all submodules, bootstraps vcpkg, and prepares the environment
# Usage: ./setup_new_repo.sh [--install-deps] [--no-cuda]

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

INSTALL_DEPS=false
NO_CUDA=false

# Show help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script performs a complete setup for a new repository clone:"
    echo "1. Initializes and updates all git submodules"
    echo "2. Bootstraps vcpkg"
    echo "3. Optionally installs dependencies"
    echo ""
    echo "Options:"
    echo "  --install-deps    Automatically install vcpkg dependencies"
    echo "  --no-cuda         Configure for build without CUDA support"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                           Setup with prompts"
    echo "  $0 --install-deps            Setup and install dependencies"
    echo "  $0 --install-deps --no-cuda  Setup without CUDA"
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-deps)
            INSTALL_DEPS=true
            shift
            ;;
        --no-cuda)
            NO_CUDA=true
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

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}Point Cloud Tools - New Repository Setup${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

# Step 1: Initialize git submodules
echo -e "${YELLOW}[1/3] Initializing git submodules...${NC}"
echo -e "${GRAY}This may take several minutes depending on your internet connection...${NC}"
echo ""

cd "$PROJECT_ROOT"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Not a git repository. Please clone the repository first.${NC}"
    exit 1
fi

# Initialize and update all submodules recursively
git submodule update --init --recursive --progress

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to initialize submodules${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Submodules initialized successfully!${NC}"
echo ""

# Show submodule status
echo -e "${CYAN}Submodule status:${NC}"
git submodule status
echo ""

# Step 2: Bootstrap vcpkg
echo -e "${YELLOW}[2/3] Bootstrapping vcpkg...${NC}"
echo ""

VCPKG_ROOT="$PROJECT_ROOT/third_party/vcpkg"
VCPKG_EXE="$VCPKG_ROOT/vcpkg"

if [ -f "$VCPKG_EXE" ]; then
    echo -e "${GREEN}vcpkg is already bootstrapped.${NC}"
else
    BOOTSTRAP_SCRIPT="$VCPKG_ROOT/bootstrap-vcpkg.sh"

    if [ ! -f "$BOOTSTRAP_SCRIPT" ]; then
        echo -e "${RED}ERROR: vcpkg bootstrap script not found. Submodules may not be initialized correctly.${NC}"
        exit 1
    fi

    echo -e "${GRAY}Running vcpkg bootstrap...${NC}"
    cd "$VCPKG_ROOT"
    ./bootstrap-vcpkg.sh

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to bootstrap vcpkg${NC}"
        exit 1
    fi

    cd "$PROJECT_ROOT"
    echo ""
    echo -e "${GREEN}vcpkg bootstrapped successfully!${NC}"
fi

echo ""

# Step 3: Install dependencies (optional)
echo -e "${YELLOW}[3/3] Installing dependencies...${NC}"

SHOULD_INSTALL=$INSTALL_DEPS

if [ "$INSTALL_DEPS" = false ]; then
    read -p "Would you like to install vcpkg dependencies now? (y/n): " RESPONSE
    if [ "$RESPONSE" = "y" ] || [ "$RESPONSE" = "Y" ]; then
        SHOULD_INSTALL=true
    fi
fi

if [ "$SHOULD_INSTALL" = true ]; then
    echo ""
    echo -e "${GRAY}Installing base dependencies from vcpkg.json...${NC}"
    echo -e "${GRAY}This will take a while on first run (15-30 minutes)...${NC}"
    echo ""

    cd "$PROJECT_ROOT"
    VCPKG_INSTALL_DIR="$PROJECT_ROOT/vcpkg_installed"

    # Install base dependencies
    "$VCPKG_EXE" install --x-manifest-root=. --x-install-root="$VCPKG_INSTALL_DIR"

    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}WARNING: Some dependencies failed to install. You can try again later.${NC}"
    else
        echo ""
        echo -e "${GREEN}Dependencies installed successfully!${NC}"
    fi
else
    echo -e "${GRAY}Skipping dependency installation.${NC}"
    echo -e "${CYAN}You can install dependencies later by running:${NC}"
    echo -e "${NC}  ./scripts_linux/bootstrap.sh${NC}"
fi

echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}Repository Setup Complete!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""

# Print next steps
echo -e "${CYAN}Next steps:${NC}"
echo ""

if [ "$NO_CUDA" = true ]; then
    echo -e "${YELLOW}To build the project (without CUDA):${NC}"
    echo -e "${NC}  ./scripts_linux/build.sh Release --no-cuda${NC}"
else
    echo -e "${YELLOW}To build the project:${NC}"
    echo -e "${NC}  ./scripts_linux/build.sh Release${NC}"
fi

echo ""
echo -e "${YELLOW}To update submodules in the future:${NC}"
echo -e "${NC}  ./scripts_linux/update_submodules.sh --all${NC}"
echo ""
echo -e "${CYAN}For more information, see README.md${NC}"
echo ""
