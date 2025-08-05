#!/usr/bin/env bash

# Test runner for setup-user and setup-server scripts

set -e

cd "$(dirname "$0")/.."

echo "🧪 Running setup-user tests..."
echo

bats tests/test_setup_user.bats
bats tests/test_setup_user_dotfilter.bats

echo
echo "🧩 Running shared functions tests..."
echo

bats tests/test_shared_functions.bats

echo
echo "🖥️  Running setup-server tests..."
echo

bats tests/test_setup_server.bats

echo
echo "🔒 Running security tests..."
echo

bats tests/test_security.bats

echo
echo "✅ All tests completed successfully!"