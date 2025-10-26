#!/bin/bash
# Update all git submodules to their latest versions
# Usage: ./update_submodules.sh [--all | --vcpkg | --colmap | --glomap | --ceres | --pyceres | --poselib]

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

UPDATE_ALL=0
UPDATE_VCPKG=0
UPDATE_COLMAP=0
UPDATE_GLOMAP=0
UPDATE_CERES=0
UPDATE_PYCERES=0
UPDATE_POSELIB=0

# Show help
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --all           Update all submodules (default if no options specified)"
    echo "  --vcpkg         Update only vcpkg"
    echo "  --colmap        Update only COLMAP"
    echo "  --glomap        Update only GLOMAP"
    echo "  --ceres         Update only Ceres Solver"
    echo "  --pyceres       Update only PyCeres"
    echo "  --poselib       Update only PoseLib"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                Update all submodules"
    echo "  $0 --colmap --glomap              Update only COLMAP and GLOMAP"
    echo "  $0 --vcpkg                        Update only vcpkg"
    exit 0
}

# Parse arguments
if [ $# -eq 0 ]; then
    UPDATE_ALL=1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            UPDATE_ALL=1
            shift
            ;;
        --vcpkg)
            UPDATE_VCPKG=1
            shift
            ;;
        --colmap)
            UPDATE_COLMAP=1
            shift
            ;;
        --glomap)
            UPDATE_GLOMAP=1
            shift
            ;;
        --ceres)
            UPDATE_CERES=1
            shift
            ;;
        --pyceres)
            UPDATE_PYCERES=1
            shift
            ;;
        --poselib)
            UPDATE_POSELIB=1
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

echo "================================================================"
echo "Git Submodules Update Script"
echo "================================================================"

cd "$PROJECT_ROOT"

if [ $UPDATE_ALL -eq 1 ]; then
    echo "Updating all submodules..."
    echo ""
    git submodule update --remote --merge

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to update submodules${NC}"
        exit 1
    fi

    echo ""
    echo "================================================================"
    echo -e "${GREEN}All submodules updated successfully!${NC}"
    echo "================================================================"
else
    # Update individual submodules
    if [ $UPDATE_VCPKG -eq 1 ]; then
        echo "Updating vcpkg..."
        cd third_party/vcpkg
        git checkout master
        git pull
        cd ../..
        git add third_party/vcpkg
        echo -e "${GREEN}vcpkg updated${NC}"
        echo ""
    fi

    if [ $UPDATE_COLMAP -eq 1 ]; then
        echo "Updating COLMAP..."
        cd third_party/colmap
        git checkout main
        git pull
        cd ../..
        git add third_party/colmap
        echo -e "${GREEN}COLMAP updated${NC}"
        echo ""
    fi

    if [ $UPDATE_GLOMAP -eq 1 ]; then
        echo "Updating GLOMAP..."
        cd third_party/glomap
        git checkout main
        git pull
        cd ../..
        git add third_party/glomap
        echo -e "${GREEN}GLOMAP updated${NC}"
        echo ""
    fi

    if [ $UPDATE_CERES -eq 1 ]; then
        echo "Updating Ceres Solver..."
        cd third_party/ceres-solver
        git checkout master
        git pull
        cd ../..
        git add third_party/ceres-solver
        echo -e "${GREEN}Ceres Solver updated${NC}"
        echo ""
    fi

    if [ $UPDATE_PYCERES -eq 1 ]; then
        echo "Updating PyCeres..."
        cd third_party/pyceres
        git checkout main
        git pull
        cd ../..
        git add third_party/pyceres
        echo -e "${GREEN}PyCeres updated${NC}"
        echo ""
    fi

    if [ $UPDATE_POSELIB -eq 1 ]; then
        echo "Updating PoseLib..."
        cd third_party/poselib
        git checkout master
        git pull
        cd ../..
        git add third_party/poselib
        echo -e "${GREEN}PoseLib updated${NC}"
        echo ""
    fi

    echo "================================================================"
    echo -e "${GREEN}Selected submodules updated successfully!${NC}"
    echo "================================================================"
fi

echo ""
echo -e "${BLUE}Current submodule status:${NC}"
git submodule status
echo ""
echo -e "${YELLOW}To commit these changes, run:${NC}"
echo "  git commit -m \"Update submodules\""
echo ""
