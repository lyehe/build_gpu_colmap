#!/usr/bin/env bash
# Script to automatically detect and pin COLMAP version for GLOMAP compatibility
# This script reads GLOMAP's expected COLMAP commit and checks out that version in colmap-for-glomap

set -e

FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force]"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
GLOMAP_PATH="$PROJECT_ROOT/third_party/glomap"
COLMAP_FOR_GLOMAP_PATH="$PROJECT_ROOT/third_party/colmap-for-glomap"
GLOMAP_DEPS_FILE="$GLOMAP_PATH/cmake/FindDependencies.cmake"

echo -e "\033[1;36m[*] Syncing COLMAP version for GLOMAP compatibility...\033[0m"

# Check if GLOMAP exists
if [ ! -d "$GLOMAP_PATH" ]; then
    echo -e "\033[1;31m[ERROR] GLOMAP submodule not found at: $GLOMAP_PATH\033[0m"
    echo -e "\033[1;33mRun: git submodule update --init --recursive\033[0m"
    exit 1
fi

# Check if colmap-for-glomap exists
if [ ! -d "$COLMAP_FOR_GLOMAP_PATH" ]; then
    echo -e "\033[1;31m[ERROR] colmap-for-glomap submodule not found at: $COLMAP_FOR_GLOMAP_PATH\033[0m"
    echo -e "\033[1;33mRun: git submodule update --init --recursive\033[0m"
    exit 1
fi

# Check if FindDependencies.cmake exists
if [ ! -f "$GLOMAP_DEPS_FILE" ]; then
    echo -e "\033[1;31m[ERROR] GLOMAP dependencies file not found: $GLOMAP_DEPS_FILE\033[0m"
    exit 1
fi

# Extract COLMAP commit from GLOMAP's FindDependencies.cmake
echo -e "\033[1;33m[1/4] Reading GLOMAP's expected COLMAP version...\033[0m"
EXPECTED_COLMAP_COMMIT=$(grep -A 5 "FetchContent_Declare(COLMAP" "$GLOMAP_DEPS_FILE" | grep "GIT_TAG" | awk '{print $2}' | tr -d '[:space:]')

if [ -z "$EXPECTED_COLMAP_COMMIT" ] || [ ${#EXPECTED_COLMAP_COMMIT} -ne 40 ]; then
    echo -e "\033[1;31m[ERROR] Could not find valid COLMAP GIT_TAG in $GLOMAP_DEPS_FILE\033[0m"
    exit 1
fi

echo "  Expected COLMAP commit: $EXPECTED_COLMAP_COMMIT"

# Get current COLMAP-for-GLOMAP commit
echo -e "\033[1;33m[2/4] Checking current colmap-for-glomap version...\033[0m"
pushd "$COLMAP_FOR_GLOMAP_PATH" > /dev/null
CURRENT_COMMIT=$(git rev-parse HEAD)
popd > /dev/null

echo "  Current commit: $CURRENT_COMMIT"

# Check if already at correct version
if [ "$CURRENT_COMMIT" = "$EXPECTED_COLMAP_COMMIT" ] && [ "$FORCE" = false ]; then
    echo -e "\033[1;32m[OK] colmap-for-glomap is already at the correct version!\033[0m"
    echo -e "\033[1;30m  Use --force to update anyway\033[0m"
    exit 0
fi

# Update colmap-for-glomap to expected version
echo -e "\033[1;33m[3/4] Updating colmap-for-glomap to expected version...\033[0m"
pushd "$COLMAP_FOR_GLOMAP_PATH" > /dev/null

# Fetch latest commits
echo "  Fetching COLMAP commits..."
git fetch origin > /dev/null 2>&1

# Check if commit exists
if ! git cat-file -e "$EXPECTED_COLMAP_COMMIT^{commit}" 2>/dev/null; then
    echo -e "\033[1;31m[ERROR] Commit $EXPECTED_COLMAP_COMMIT not found in COLMAP repository\033[0m"
    popd > /dev/null
    exit 1
fi

# Checkout expected commit
echo "  Checking out commit $EXPECTED_COLMAP_COMMIT..."
git checkout "$EXPECTED_COLMAP_COMMIT" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "\033[1;32m[OK] Successfully updated colmap-for-glomap\033[0m"
else
    echo -e "\033[1;31m[ERROR] Failed to checkout commit\033[0m"
    popd > /dev/null
    exit 1
fi

popd > /dev/null

# Verify final state
echo -e "\033[1;33m[4/4] Verifying update...\033[0m"
pushd "$COLMAP_FOR_GLOMAP_PATH" > /dev/null
FINAL_COMMIT=$(git rev-parse HEAD)
COMMIT_MESSAGE=$(git log -1 --oneline)
popd > /dev/null

if [ "$FINAL_COMMIT" = "$EXPECTED_COLMAP_COMMIT" ]; then
    echo -e "\033[1;32m[SUCCESS] colmap-for-glomap is now at the correct version!\033[0m"
    echo "  Commit: $FINAL_COMMIT"
    echo "  Message: $COMMIT_MESSAGE"
    echo ""
    echo -e "\033[1;36mYou can now build GLOMAP with: ./scripts_linux/build.sh\033[0m"
else
    echo -e "\033[1;31m[ERROR] Verification failed - final commit doesn't match expected\033[0m"
    echo "  Expected: $EXPECTED_COLMAP_COMMIT"
    echo "  Got: $FINAL_COMMIT"
    exit 1
fi
