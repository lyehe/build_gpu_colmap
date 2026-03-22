#!/bin/bash
# Download ALIKED and LightGlue ONNX models for COLMAP
# Models are cached in ~/.cache/colmap/ (same location COLMAP uses)
#
# Usage: ./download_models.sh [--cache-dir DIR]

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DARK_GRAY='\033[0;90m'
NC='\033[0m'

# Default cache directory (matches COLMAP's default)
CACHE_DIR="${HOME}/.cache/colmap"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cache-dir)
            CACHE_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Download ALIKED and LightGlue ONNX models for COLMAP"
            echo ""
            echo "Usage: $0 [--cache-dir DIR]"
            echo ""
            echo "Options:"
            echo "  --cache-dir DIR    Cache directory (default: ~/.cache/colmap)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Models downloaded:"
            echo "  - aliked-n16rot.onnx     ALIKED N16ROT feature extractor"
            echo "  - aliked-n32.onnx        ALIKED N32 feature extractor"
            echo "  - aliked-lightglue.onnx  ALIKED LightGlue feature matcher"
            echo "  - bruteforce-matcher.onnx  Brute-force ONNX matcher"
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

BASE_URL="https://github.com/colmap/colmap/releases/download/3.13.0"

# Model definitions: "filename sha256"
MODELS=(
    "aliked-n16rot.onnx 39c423d0a6f03d39ec89d3d1d61853765c2fb6a8b8381376c703e5758778a547"
    "aliked-n32.onnx a077728a02d2de1a775c66df6de8cfeb7c6b51ca57572c64c680131c988c8b3c"
    "aliked-lightglue.onnx b9a5de7204648b18a8cf5dcac819f9d30de1a5961ef03756803c8b86c2dceb8d"
    "bruteforce-matcher.onnx 3c1282f96d83f5ffc861a873298d08bbe5219f59af59223f5ceab5c41a182a47"
)

echo -e "${CYAN}Download COLMAP ONNX Models${NC}"
echo "================================================================"
echo "Cache directory: $CACHE_DIR"
echo ""

mkdir -p "$CACHE_DIR"

DOWNLOADED=0
SKIPPED=0
FAILED=0

for entry in "${MODELS[@]}"; do
    FILENAME="${entry%% *}"
    SHA256="${entry##* }"
    CACHED_FILE="${CACHE_DIR}/${SHA256}-${FILENAME}"

    echo -n -e "  ${FILENAME}... "

    # Check if already cached with correct hash
    if [ -f "$CACHED_FILE" ]; then
        # Verify checksum
        ACTUAL_SHA256=$(sha256sum "$CACHED_FILE" | cut -d' ' -f1)
        if [ "$ACTUAL_SHA256" = "$SHA256" ]; then
            echo -e "${GREEN}already cached${NC}"
            SKIPPED=$((SKIPPED + 1))
            continue
        else
            echo -e "${YELLOW}cached file corrupted, re-downloading${NC}"
            rm -f "$CACHED_FILE"
        fi
    fi

    # Download
    echo -e "${DARK_GRAY}downloading...${NC}"
    URL="${BASE_URL}/${FILENAME}"

    if curl -fSL --progress-bar -o "$CACHED_FILE" "$URL"; then
        # Verify checksum
        ACTUAL_SHA256=$(sha256sum "$CACHED_FILE" | cut -d' ' -f1)
        if [ "$ACTUAL_SHA256" = "$SHA256" ]; then
            SIZE=$(du -h "$CACHED_FILE" | cut -f1)
            echo -e "  ${GREEN}OK${NC} (${SIZE})"
            DOWNLOADED=$((DOWNLOADED + 1))
        else
            echo -e "  ${RED}FAILED: checksum mismatch${NC}"
            echo -e "  ${DARK_GRAY}Expected: ${SHA256}${NC}"
            echo -e "  ${DARK_GRAY}Got:      ${ACTUAL_SHA256}${NC}"
            rm -f "$CACHED_FILE"
            FAILED=$((FAILED + 1))
        fi
    else
        echo -e "  ${RED}FAILED: download error${NC}"
        rm -f "$CACHED_FILE"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "================================================================"
echo -e "Downloaded: ${GREEN}${DOWNLOADED}${NC}  Cached: ${CYAN}${SKIPPED}${NC}  Failed: ${RED}${FAILED}${NC}"

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Some downloads failed. Check your internet connection.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All models ready!${NC}"
echo -e "${DARK_GRAY}COLMAP will automatically find them in ${CACHE_DIR}${NC}"
echo "================================================================"
