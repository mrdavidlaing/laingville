#!/usr/bin/env bash

# Test runner for all Laingville tests

cd "$(dirname "$0")/.."

echo "🧪 Running all Laingville tests..."
echo

# Run all .bats files in the tests directory
bats tests/

echo
echo "✅ All tests completed!"