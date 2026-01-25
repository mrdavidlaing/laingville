#!/usr/bin/env bash
# test-yolo-agent-environment.sh - Validate yolo-agent environment in containers
#
# This script runs inside a container to verify the yolo-agent environment
# is properly configured with all language runtimes and dev tools.
#
# Usage:
#   docker run --rm <image> /path/to/test-yolo-agent-environment.sh
#   # Or mount and run:
#   docker run --rm -v $(pwd)/infra/tests:/tests <image> /tests/test-yolo-agent-environment.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
  echo -e "${GREEN}PASS${NC}: $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}: $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

warn() {
  echo -e "${YELLOW}WARN${NC}: $1"
}

section() {
  echo ""
  echo "=== $1 ==="
}

#############################################
# Container user and sudo checks
#############################################
section "Container User and Permissions"

# Check we're running as vscode user
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "vscode" ]; then
  pass "Running as vscode user"
else
  warn "Running as $CURRENT_USER (expected vscode)"
fi

# Check passwordless sudo works
if sudo -n true 2> /dev/null; then
  pass "Passwordless sudo is enabled"
else
  fail "Passwordless sudo is not enabled"
fi

# Test sudo can install packages (simulate with echo)
if sudo -n sh -c 'echo "test" > /tmp/sudo-test' 2> /dev/null; then
  pass "Sudo has write permissions"
  sudo rm -f /tmp/sudo-test
else
  fail "Sudo cannot write files"
fi

#############################################
# Essential dev tools checks
#############################################
section "Essential Development Tools"

for tool in git curl jq fd fzf bat just ssh direnv; do
  if command -v "$tool" > /dev/null 2>&1; then
    VERSION=$("$tool" --version 2>&1 | head -1 || echo "available")
    pass "$tool is available: $VERSION"
  else
    fail "$tool command not found"
  fi
done

# Check ripgrep (binary is called 'rg')
if command -v rg > /dev/null 2>&1; then
  RG_VERSION=$(rg --version 2>&1 | head -1)
  pass "ripgrep (rg) is available: $RG_VERSION"
else
  fail "ripgrep (rg) command not found"
fi

# Check nix is available and configured for flakes
if command -v nix > /dev/null 2>&1; then
  NIX_VERSION=$(nix --version 2>&1 | head -1)
  pass "nix is available: $NIX_VERSION"

  # Check if flakes are enabled
  if nix --version 2>&1 | grep -q "nix"; then
    if nix flake --help > /dev/null 2>&1; then
      pass "nix flakes are enabled"
    else
      warn "nix flakes may not be enabled"
    fi
  fi
else
  fail "nix command not found"
fi

#############################################
# Python checks
#############################################
section "Python Runtime"

# Check python3 is available
if command -v python3 > /dev/null 2>&1; then
  PYTHON_VERSION=$(python3 --version)
  pass "python3 is available: $PYTHON_VERSION"
else
  fail "python3 command not found"
fi

# Check python can execute code
if python3 -c "print('hello')" 2> /dev/null | grep -q "hello"; then
  pass "python3 can execute code"
else
  fail "python3 cannot execute code"
fi

# Check pip is available
if command -v pip > /dev/null 2>&1 || command -v pip3 > /dev/null 2>&1; then
  PIP_VERSION=$(pip --version 2> /dev/null || pip3 --version 2> /dev/null)
  pass "pip is available: $PIP_VERSION"
else
  fail "pip command not found"
fi

# Check Python dev tools
for tool in ruff pyright; do
  if command -v "$tool" > /dev/null 2>&1; then
    pass "$tool is available"
  else
    fail "$tool command not found"
  fi
done

#############################################
# Node.js checks
#############################################
section "Node.js Runtime"

# Check node is available
if command -v node > /dev/null 2>&1; then
  NODE_VERSION=$(node --version)
  pass "node is available: $NODE_VERSION"
else
  fail "node command not found"
fi

# Check node can execute JavaScript
if node -e "console.log('hello')" 2> /dev/null | grep -q "hello"; then
  pass "node can execute JavaScript"
else
  fail "node cannot execute JavaScript"
fi

# Check npm is available
if command -v npm > /dev/null 2>&1; then
  NPM_VERSION=$(npm --version)
  pass "npm is available: $NPM_VERSION"
else
  fail "npm command not found"
fi

# Check Node.js dev tools
for tool in bun npx; do
  if command -v "$tool" > /dev/null 2>&1; then
    pass "$tool is available"
  else
    warn "$tool command not found"
  fi
done

#############################################
# Go checks
#############################################
section "Go Runtime"

# Check go is available
if command -v go > /dev/null 2>&1; then
  GO_VERSION=$(go version)
  pass "go is available: $GO_VERSION"
else
  fail "go command not found"
fi

# Check go can build and run code
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
cat > hello.go << 'EOF'
package main
import "fmt"
func main() {
    fmt.Println("hello")
}
EOF

if go run hello.go 2> /dev/null | grep -q "hello"; then
  pass "go can compile and execute code"
else
  fail "go cannot compile and execute code"
fi

cd /
rm -rf "$TEMP_DIR"

# Check Go dev tools
for tool in gopls golangci-lint; do
  if command -v "$tool" > /dev/null 2>&1; then
    pass "$tool is available"
  else
    fail "$tool command not found"
  fi
done

#############################################
# Rust checks
#############################################
section "Rust Runtime"

# Check rustc is available
if command -v rustc > /dev/null 2>&1; then
  RUSTC_VERSION=$(rustc --version)
  pass "rustc is available: $RUSTC_VERSION"
else
  fail "rustc command not found"
fi

# Check cargo is available
if command -v cargo > /dev/null 2>&1; then
  CARGO_VERSION=$(cargo --version)
  pass "cargo is available: $CARGO_VERSION"
else
  fail "cargo command not found"
fi

# Check rust can compile and run code
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
cat > hello.rs << 'EOF'
fn main() {
    println!("hello");
}
EOF

if rustc hello.rs -o hello 2>&1 && ./hello 2>&1 | grep -q "hello"; then
  pass "rust can compile and execute code"
else
  warn "rust compilation failed - may need linker (cc/gcc). This is optional for most agent work."
fi

cd /
rm -rf "$TEMP_DIR"

# Check Rust dev tools
if command -v rust-analyzer > /dev/null 2>&1; then
  pass "rust-analyzer is available"
else
  fail "rust-analyzer command not found"
fi

# clippy is accessed via 'cargo clippy', not as standalone command
if cargo clippy --version > /dev/null 2>&1; then
  CLIPPY_VERSION=$(cargo clippy --version)
  pass "clippy is available: $CLIPPY_VERSION"
else
  fail "clippy (via cargo clippy) not available"
fi

if command -v rustfmt > /dev/null 2>&1; then
  pass "rustfmt is available"
else
  fail "rustfmt command not found"
fi

#############################################
# Bash checks
#############################################
section "Bash Runtime and Dev Tools"

# Check bash is available
if command -v bash > /dev/null 2>&1; then
  BASH_VERSION=$(bash --version | head -1)
  pass "bash is available: $BASH_VERSION"
else
  fail "bash command not found"
fi

# Check Bash dev tools
for tool in shellcheck shellspec shfmt; do
  if command -v "$tool" > /dev/null 2>&1; then
    pass "$tool is available"
  else
    fail "$tool command not found"
  fi
done

#############################################
# Environment configuration checks
#############################################
section "Environment Configuration"

# Check HOME is set
if [ -n "${HOME:-}" ]; then
  pass "HOME is set: $HOME"
else
  fail "HOME is not set"
fi

# Check USER is set
if [ -n "${USER:-}" ]; then
  pass "USER is set: $USER"
else
  fail "USER is not set"
fi

# Check PATH includes common directories
if echo "$PATH" | grep -q "/bin"; then
  pass "PATH includes /bin"
else
  fail "PATH does not include /bin"
fi

# Check SSL certificates are available
if [ -n "${SSL_CERT_FILE:-}" ] && [ -f "$SSL_CERT_FILE" ]; then
  pass "SSL_CERT_FILE is set and exists: $SSL_CERT_FILE"
else
  warn "SSL_CERT_FILE is not set or does not exist"
fi

# Check direnv hook is in bashrc
if [ -f "$HOME/.bashrc" ] && grep -q "direnv hook bash" "$HOME/.bashrc"; then
  pass "direnv hook is configured in .bashrc"
else
  warn "direnv hook is not configured in .bashrc"
fi

# Check starship is configured
if [ -f "$HOME/.config/starship.toml" ]; then
  pass "starship is configured"
else
  warn "starship is not configured"
fi

#############################################
# Summary
#############################################
section "Summary"
echo ""
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
