#!/bin/bash
# Bootstrap script for vcpkg on Linux/macOS
# This script initializes vcpkg and optionally installs dependencies

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
VCPKG_ROOT="$PROJECT_ROOT/third_party/vcpkg"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================================"
echo "vcpkg Bootstrap Script for Linux/macOS"
echo "================================================================"

# Check if vcpkg submodule exists
if [ ! -d "$VCPKG_ROOT/.git" ]; then
    echo -e "${RED}ERROR: vcpkg submodule not found${NC}"
    echo "Please run: git submodule update --init --recursive"
    exit 1
fi

# Update vcpkg.json baseline with current vcpkg commit
echo -e "${YELLOW}Updating vcpkg.json baseline...${NC}"
cd "$VCPKG_ROOT"
VCPKG_COMMIT=$(git rev-parse HEAD)
if [ $? -eq 0 ]; then
    VCPKG_JSON="$PROJECT_ROOT/vcpkg.json"
    if [ -f "$VCPKG_JSON" ]; then
        OLD_BASELINE=$(grep -oP '"builtin-baseline":\s*"\K[^"]+' "$VCPKG_JSON" || echo "latest")

        if [ "$OLD_BASELINE" != "$VCPKG_COMMIT" ]; then
            echo -e "  Old baseline: ${RED}$OLD_BASELINE${NC}"
            echo -e "  New baseline: ${GREEN}$VCPKG_COMMIT${NC}"

            # Update baseline in vcpkg.json using sed
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS sed syntax
                sed -i '' "s/\"builtin-baseline\": \".*\"/\"builtin-baseline\": \"$VCPKG_COMMIT\"/" "$VCPKG_JSON"
            else
                # Linux sed syntax
                sed -i "s/\"builtin-baseline\": \".*\"/\"builtin-baseline\": \"$VCPKG_COMMIT\"/" "$VCPKG_JSON"
            fi
            echo -e "  ${GREEN}vcpkg.json baseline updated successfully!${NC}"
        else
            echo -e "  ${GREEN}Baseline already up to date: $VCPKG_COMMIT${NC}"
        fi
    fi
fi
echo ""

# Check if vcpkg is already bootstrapped
if [ -f "$VCPKG_ROOT/vcpkg" ]; then
    echo -e "${GREEN}vcpkg is already bootstrapped.${NC}"
    echo "vcpkg binary found at: $VCPKG_ROOT/vcpkg"
    echo ""
else
    # Bootstrap vcpkg
    echo "Bootstrapping vcpkg..."
    echo "This may take a few minutes..."
    echo ""

    cd "$VCPKG_ROOT"
    ./bootstrap-vcpkg.sh

    if [ $? -ne 0 ]; then
        echo ""
        echo -e "${RED}ERROR: Failed to bootstrap vcpkg${NC}"
        exit 1
    fi

    echo ""
    echo "================================================================"
    echo -e "${GREEN}vcpkg bootstrapped successfully!${NC}"
    echo "================================================================"
    echo ""
fi

# Ask if user wants to install dependencies now
read -p "Would you like to install dependencies now? (y/n): " INSTALL_DEPS

if [ "$INSTALL_DEPS" = "y" ] || [ "$INSTALL_DEPS" = "Y" ]; then
    echo ""
    echo "Installing dependencies via vcpkg manifest..."
    echo "This will install base dependencies defined in vcpkg.json"
    echo ""

    cd "$PROJECT_ROOT"
    "$VCPKG_ROOT/vcpkg" install --x-manifest-root=. --x-install-root=./vcpkg_installed

    if [ $? -ne 0 ]; then
        echo ""
        echo -e "${YELLOW}WARNING: Some dependencies failed to install${NC}"
        echo "You can try again later or install manually"
    else
        echo ""
        echo "================================================================"
        echo -e "${GREEN}Dependencies installed successfully!${NC}"
        echo "================================================================"
    fi
fi

echo ""
echo -e "${BLUE}Bootstrap complete! You can now build the project using:${NC}"
echo "  ./scripts_linux/build.sh Release"
echo ""
