#!/bin/bash

# Test runner for setup-user script

set -e

cd "$(dirname "$0")/.."

echo "🧪 Running setup-user tests..."
echo

bats tests/test_setup_user.bats

echo
echo "✅ All tests completed successfully!"