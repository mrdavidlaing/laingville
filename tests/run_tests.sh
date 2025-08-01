#!/bin/bash

# Test runner for setup-user script

set -e

cd "$(dirname "$0")/.."

echo "🧪 Running setup-user tests..."
echo

echo "📋 Integration Tests:"
bats tests/integration/test_dry_run.bats tests/integration/test_user_scenarios.bats

echo
echo "🔬 Unit Tests:"
bats tests/unit/test_yaml_parsing.bats

echo
echo "✅ All tests completed successfully!"

# Optional: Show test coverage summary
echo
echo "📊 Test Coverage Summary:"
echo "- Integration tests: 7 tests covering end-to-end workflows"
echo "- Unit tests: 6 tests covering YAML parsing and platform detection"  
echo "- Total: 13 tests covering critical functionality"