#!/bin/bash

set -e

# Create temporary dotfiles directory within allowed path
temp_dir="tests/../dotfiles/test_temp_debug"
rm -rf "$temp_dir"
mkdir -p "$temp_dir/.config"
echo "test" > "$temp_dir/.config/test.conf"

export DOTFILES_DIR="$temp_dir"

echo "Running setup-user --dry-run..."
./setup-user --dry-run
echo "Script completed with status: $?"

rm -rf "$temp_dir"