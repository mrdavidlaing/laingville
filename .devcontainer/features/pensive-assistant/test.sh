#!/bin/bash
#
# Test that pensive-assistant tools are available
# Run inside the devcontainer after feature installation
#

set -e

echo "=== Pensive Assistant Feature Tests ==="
echo ""

# Version checks (basic availability)
echo "Checking bd..."
bd --version || exit 1

echo "Checking zellij..."
zellij --version || exit 1

echo "Checking lazygit..."
lazygit --version || exit 1

echo "Checking bun (from base image)..."
bun --version || exit 1

echo "Checking opencode..."
opencode --version || exit 1

echo "Checking claude..."
claude --version || exit 1

echo ""
echo "=== Functional Smoke Tests ==="
echo ""

# Functional smoke tests (beyond --version)
# These catch cases where --version works but runtime is broken
echo "Testing opencode --help..."
opencode --help > /dev/null || exit 1

echo "Testing claude --help..."
claude --help > /dev/null || exit 1

echo ""
echo "=== Tarball Provenance Checks ==="
echo ""

# CRITICAL: Tarball provenance checks
# Verify tools are ACTUALLY from the extracted tarball, not just "in /nix/store"
# Being in /nix/store is necessary but not sufficient (could be from base image)

OPENCODE_PATH=$(command -v opencode)
CLAUDE_PATH=$(command -v claude)
echo "opencode path: $OPENCODE_PATH"
echo "claude path: $CLAUDE_PATH"

# Resolve symlinks to find actual binary location
OPENCODE_REAL=$(readlink -f "$OPENCODE_PATH" 2> /dev/null || echo "$OPENCODE_PATH")
CLAUDE_REAL=$(readlink -f "$CLAUDE_PATH" 2> /dev/null || echo "$CLAUDE_PATH")
echo "opencode real: $OPENCODE_REAL"
echo "claude real: $CLAUDE_REAL"

# Step 1: Assert NOT in home directory (catches bun install -g)
if [[ "$OPENCODE_REAL" == $HOME/* ]]; then
  echo "ERROR: opencode in home dir $OPENCODE_REAL (should be /nix/store)"
  exit 1
fi
if [[ "$CLAUDE_REAL" == $HOME/* ]]; then
  echo "ERROR: claude in home dir $CLAUDE_REAL (should be /nix/store)"
  exit 1
fi

# Step 2: Assert the resolved paths are in /nix/store
if [[ "$OPENCODE_REAL" != /nix/store/* ]]; then
  echo "ERROR: opencode resolves to $OPENCODE_REAL (expected /nix/store/...)"
  exit 1
fi
if [[ "$CLAUDE_REAL" != /nix/store/* ]]; then
  echo "ERROR: claude resolves to $CLAUDE_REAL (expected /nix/store/...)"
  exit 1
fi

# Step 3: Verify the store paths are PRESENT IN THE TARBALL
# This proves they came from the tarball, not from base image or other source

# Find tarball path (context-independent)
# In CI: /feature/dist/pensive-tools.tar.gz (mounted)
# In devcontainer: relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARBALL_PATH="${TARBALL_PATH:-${SCRIPT_DIR}/dist/pensive-tools.tar.gz}"

if [[ ! -f "$TARBALL_PATH" ]]; then
  echo "ERROR: Tarball not found at $TARBALL_PATH"
  echo "Set TARBALL_PATH env var or ensure dist/pensive-tools.tar.gz exists"
  exit 1
fi

TARBALL_CONTENTS=$(tar -tzf "$TARBALL_PATH")

# Extract store path prefix (e.g., /nix/store/abc123-opencode-ai-1.1.34)
OPENCODE_STORE_PATH=$(echo "$OPENCODE_REAL" | grep -oE '/nix/store/[^/]+')
CLAUDE_STORE_PATH=$(echo "$CLAUDE_REAL" | grep -oE '/nix/store/[^/]+')

echo "Checking tarball for: $OPENCODE_STORE_PATH"
if ! echo "$TARBALL_CONTENTS" | grep -q "^${OPENCODE_STORE_PATH#/}"; then
  echo "ERROR: opencode store path NOT in tarball"
  echo "Tarball contains:"
  echo "$TARBALL_CONTENTS" | grep "opencode" | head -5
  exit 1
fi

echo "Checking tarball for: $CLAUDE_STORE_PATH"
if ! echo "$TARBALL_CONTENTS" | grep -q "^${CLAUDE_STORE_PATH#/}"; then
  echo "ERROR: claude store path NOT in tarball"
  echo "Tarball contains:"
  echo "$TARBALL_CONTENTS" | grep "claude" | head -5
  exit 1
fi

echo ""
echo "=== All Tests Passed ==="
echo "✓ All 6 tools available (bd, zellij, lazygit, bun, opencode, claude)"
echo "✓ Functional smoke tests passed"
echo "✓ Tarball provenance verified"
exit 0
