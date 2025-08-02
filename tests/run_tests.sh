#!/bin/bash

# Test runner for setup-user script

set -e

cd "$(dirname "$0")/.."

echo "🧪 Running setup-user tests..."
echo

bats tests/test_setup_user.bats

echo
echo "✅ All tests completed successfully!"

# Show what we tested
echo
echo "📊 Test Coverage:"
echo "- Essential functionality: --dry-run, error handling, YAML parsing"
echo "- Focused on user-facing behavior rather than implementation details"
echo "- Clear error messages when tests fail"