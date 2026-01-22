#!/bin/bash
#
# Test that pensive-assistant tools are available
# Run inside the devcontainer after feature installation
#

set -e

PASS=0
FAIL=0

check_tool() {
  local tool="$1"
  local check_cmd="${2:-$tool --version}"

  echo -n "Checking $tool... "
  if eval "$check_cmd" &> /dev/null; then
    echo "OK"
    PASS=$((PASS + 1))
  else
    echo "FAIL"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Pensive Assistant Feature Tests ==="
echo ""

# Nix-installed tools
check_tool "bd" "bd --version"
check_tool "zellij" "zellij --version"
check_tool "lazygit" "lazygit --version"

# Bun-installed tools
check_tool "claude" "command -v claude"

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Some tests failed!"
  exit 1
else
  echo "All tests passed!"
  exit 0
fi
