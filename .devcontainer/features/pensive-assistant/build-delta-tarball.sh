#!/bin/bash
# Build script that mirrors CI workflow (publish-feature.yml)
# This script runs inside the devcontainer base image to build a delta tarball
set -euo pipefail

# Set HOME explicitly to avoid nix's homeless-shelter handling
export HOME=/root

# Configure nix for building as root without nixbld group
# Enable sandbox since we run with --privileged (provides necessary capabilities)
# This avoids the /homeless-shelter purity check issue
mkdir -p /etc/nix
cat > /etc/nix/nix.conf << 'NIXCONF'
experimental-features = nix-command flakes
build-users-group =
sandbox = true
NIXCONF

cd /workspace

# Initialize as standalone git repo for nix flakes
git config --global --add safe.directory /workspace
git init -q
git add -A
git config user.email "ci@example.com"
git config user.name "CI"
git commit -q -m "build"

# Snapshot existing nix store paths BEFORE build
echo "Snapshotting base image store..."
find /nix/store -maxdepth 1 -mindepth 1 -type d 2> /dev/null > /tmp/existing-paths.txt || true

# Build the pensive tools environment (not the tarball output)
echo "Building pensive-assistant tools..."
nix build .#default --out-link result-env --impure

# Get the closure of the new environment
echo "Computing closure..."
nix-store --query --requisites result-env > /tmp/new-closure.txt

# Compute delta (paths in new closure but not in base image)
echo "Computing delta from base image..."
comm -23 <(sort /tmp/new-closure.txt) <(sort /tmp/existing-paths.txt) > /tmp/delta-paths.txt

if [ ! -s /tmp/delta-paths.txt ]; then
  echo "Warning: No new paths to add (all dependencies in base image)"
  cp /tmp/new-closure.txt /tmp/delta-paths.txt
fi

DELTA_PATHS=$(tr '\n' ' ' < /tmp/delta-paths.txt)
echo "Delta paths: $(wc -l < /tmp/delta-paths.txt) new store paths"

# Create tarball with only delta paths
rm -rf dist
mkdir -p dist
# shellcheck disable=SC2086 # DELTA_PATHS is intentionally word-split
tar -cf - $DELTA_PATHS | gzip > dist/pensive-tools.tar.gz

# Write the env path for reference
readlink -f result-env > dist/env-path

# Save dependency tree for stats
nix-store --query --tree result-env > dist/dep-tree.txt

# Create annotated dependency tree showing what's in tarball vs base
echo "Creating annotated dependency tree..."
awk '
BEGIN {
    # Load delta paths into array
    while ((getline < "/tmp/delta-paths.txt") > 0) {
        delta[$0] = 1
    }
    close("/tmp/delta-paths.txt")
}
{
    # Extract store path from tree line (handles tree drawing chars)
    line = $0
    path = $0
    # Remove tree drawing characters and whitespace
    gsub(/^[│├└─ ]+/, "", path)

    # Check if this store path is in delta
    is_new = 0
    for (d in delta) {
        if (index(path, d) == 1) {
            is_new = 1
            break
        }
    }

    # Print line with annotation
    if (is_new) {
        print "[+] " line
    } else {
        print "[=] " line
    }
}
' dist/dep-tree.txt > dist/dep-tree-annotated.txt

# Add size summary by computing sizes for delta paths
echo "Computing size breakdown..."
{
  echo "## Size Breakdown"
  echo ""
  echo "| Component | Size | In Tarball |"
  echo "|-----------|------|------------|"

  # Show sizes for key top-level dependencies
  # shellcheck disable=SC2086 # DELTA_PATHS is intentionally word-split
  for path in $DELTA_PATHS; do
    # Only show direct dependencies (not recursive deps)
    if grep -q "^├───$path\|^└───$path" dist/dep-tree.txt; then
      size=$(du -sh "$path" 2> /dev/null | cut -f1)
      name=$(basename "$path")
      echo "| $name | $size | ✓ |"
    fi
  done

  echo ""
  echo "**Total tarball size:** $(du -h dist/pensive-tools.tar.gz | cut -f1)"
} > dist/size-breakdown.txt

echo "Tarball size: $(du -h dist/pensive-tools.tar.gz | cut -f1)"
echo "Build complete!"
