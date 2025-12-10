#!/usr/bin/env bash
# Test Python environment in a container
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

echo "======================================"
echo "Python Container Environment Tests"
echo "======================================"
echo ""

# Test 1: Python is installed
run_test "Python installed" "command -v python"

# Test 2: Python version
check_output "Python version" "python --version" "^Python [0-9]+\.[0-9]+\.[0-9]+"

# Test 3: pip is installed
run_test "pip installed" "command -v pip"

# Test 4: pip version
check_output "pip version" "pip --version" "^pip [0-9]+\.[0-9]+"

# Test 5: pip can list installed packages
run_test "pip list accessible" "pip list"

# Test 6: Python can execute simple code
run_test "Python execution" "python -c 'print(\"test\")'"

# Test 7: pip can install to a test directory
TESTS_RUN=$((TESTS_RUN + 1))
echo -n "Testing pip package installation... "
TEST_DIR=$(mktemp -d)
if pip install --target "$TEST_DIR" requests > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    rm -rf "$TEST_DIR"
else
    echo -e "${RED}✗ FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    rm -rf "$TEST_DIR"
fi

# Test 8: Check for common Python tools
for tool in python3; do
    run_test "$tool installed" "command -v $tool"
done

# Print summary
echo ""
echo "======================================"
echo "Test Summary"
echo "======================================"
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
else
    echo -e "Tests failed: $TESTS_FAILED"
fi
echo "======================================"

# Exit with error if any tests failed
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

echo -e "\n${GREEN}All tests passed!${NC}"
exit 0
