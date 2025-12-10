#!/usr/bin/env bash
# Run container tests for specified images
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default registry
REGISTRY="${REGISTRY:-ghcr.io/mrdavidlaing/laingville}"

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] IMAGE [IMAGE...]

Run container environment tests for specified images.

OPTIONS:
    -h, --help          Show this help message
    -r, --registry REG  Use custom registry (default: $REGISTRY)
    -t, --tag TAG       Use specific tag (default: latest)
    -l, --local         Test locally built images (skip docker pull)

IMAGES:
    example-node-devcontainer
    example-node-runtime
    example-python-devcontainer
    example-python-runtime
    laingville-devcontainer

EXAMPLES:
    # Test all Node.js containers
    $(basename "$0") example-node-devcontainer example-node-runtime

    # Test with specific tag
    $(basename "$0") -t 2025-12-10 example-node-devcontainer

    # Test locally built image
    $(basename "$0") -l example-node-devcontainer

EOF
    exit 0
}

# Parse arguments
TAG="latest"
LOCAL_MODE=false
IMAGES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -l|--local)
            LOCAL_MODE=true
            shift
            ;;
        *)
            IMAGES+=("$1")
            shift
            ;;
    esac
done

# Check if at least one image is specified
if [ ${#IMAGES[@]} -eq 0 ]; then
    echo -e "${RED}Error: No images specified${NC}"
    echo ""
    usage
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Track overall results
TOTAL_IMAGES=0
PASSED_IMAGES=0
FAILED_IMAGES=0

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Container Environment Test Runner${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Function to determine which test script to use for an image
get_test_script() {
    local image="$1"

    case "$image" in
        *node*)
            echo "$SCRIPT_DIR/test-node-environment.sh"
            ;;
        *python*)
            echo "$SCRIPT_DIR/test-python-environment.sh"
            ;;
        laingville-devcontainer)
            # The main devcontainer might have both, test both
            echo "$SCRIPT_DIR/test-node-environment.sh"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Test each image
for image in "${IMAGES[@]}"; do
    TOTAL_IMAGES=$((TOTAL_IMAGES + 1))

    # Build full image name
    if [ "$LOCAL_MODE" = true ]; then
        FULL_IMAGE="$image:$TAG"
    else
        FULL_IMAGE="$REGISTRY/$image:$TAG"
    fi

    echo -e "${YELLOW}Testing image: ${FULL_IMAGE}${NC}"
    echo "---"

    # Pull image if not in local mode
    if [ "$LOCAL_MODE" = false ]; then
        echo "Pulling image..."
        if ! docker pull "$FULL_IMAGE"; then
            echo -e "${RED}Failed to pull image: $FULL_IMAGE${NC}"
            FAILED_IMAGES=$((FAILED_IMAGES + 1))
            echo ""
            continue
        fi
    fi

    # Get the appropriate test script
    TEST_SCRIPT=$(get_test_script "$image")

    if [ -z "$TEST_SCRIPT" ] || [ ! -f "$TEST_SCRIPT" ]; then
        echo -e "${YELLOW}Warning: No test script found for $image${NC}"
        echo -e "${YELLOW}Skipping tests for this image${NC}"
        echo ""
        continue
    fi

    # Make test script executable
    chmod +x "$TEST_SCRIPT"

    # Run the test script in the container
    echo "Running tests..."
    if docker run --rm -v "$TEST_SCRIPT:/tmp/test.sh:ro" "$FULL_IMAGE" bash /tmp/test.sh; then
        echo -e "${GREEN}✓ All tests passed for $image${NC}"
        PASSED_IMAGES=$((PASSED_IMAGES + 1))
    else
        echo -e "${RED}✗ Tests failed for $image${NC}"
        FAILED_IMAGES=$((FAILED_IMAGES + 1))
    fi

    echo ""
done

# Print overall summary
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Overall Test Summary${NC}"
echo -e "${BLUE}==========================================${NC}"
echo "Images tested: $TOTAL_IMAGES"
echo -e "Images passed: ${GREEN}$PASSED_IMAGES${NC}"
if [ $FAILED_IMAGES -gt 0 ]; then
    echo -e "Images failed: ${RED}$FAILED_IMAGES${NC}"
else
    echo -e "Images failed: $FAILED_IMAGES"
fi
echo -e "${BLUE}==========================================${NC}"

# Exit with error if any images failed
if [ $FAILED_IMAGES -gt 0 ]; then
    exit 1
fi

echo -e "\n${GREEN}All container tests passed!${NC}"
exit 0
