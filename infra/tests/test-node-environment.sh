#!/usr/bin/env bash
# Test Node.js environment in a container
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing ${test_name}... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to check command output
check_output() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing ${test_name}... "

    local output
    output=$(eval "$test_command" 2>&1)

    if echo "$output" | grep -qE "$expected_pattern"; then
        echo -e "${GREEN}✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        echo "  Expected pattern: $expected_pattern"
        echo "  Got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "====================================="
echo "Node.js Container Environment Tests"
echo "====================================="
echo ""

# Test 1: Node.js is installed
run_test "Node.js installed" "command -v node"

# Test 2: Node.js version
check_output "Node.js version" "node --version" "^v[0-9]+\.[0-9]+\.[0-9]+"

# Test 3: npm is installed
run_test "npm installed" "command -v npm"

# Test 4: npm version
check_output "npm version" "npm --version" "^[0-9]+\.[0-9]+\.[0-9]+"

# Test 5: npm can list global packages
run_test "npm globals accessible" "npm list -g --depth=0"

# Test 6: Node can execute simple code
run_test "Node execution" "node -e 'console.log(\"test\")'"

# Test 7: npm can install to a test directory
TESTS_RUN=$((TESTS_RUN + 1))
echo -n "Testing npm package installation... "
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
if npm init -y > /dev/null 2>&1 && npm install lodash > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    cd - > /dev/null
    rm -rf "$TEST_DIR"
else
    echo -e "${RED}✗ FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    cd - > /dev/null
    rm -rf "$TEST_DIR"
fi

# Test 8: Check for common Node.js tools
for tool in npx; do
    run_test "$tool installed" "command -v $tool"
done

# Print summary
echo ""
echo "====================================="
echo "Test Summary"
echo "====================================="
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
else
    echo -e "Tests failed: $TESTS_FAILED"
fi
echo "====================================="

# Exit with error if any tests failed
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

echo -e "\n${GREEN}All tests passed!${NC}"
exit 0
