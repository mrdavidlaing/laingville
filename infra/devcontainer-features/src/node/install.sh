#!/bin/bash
# infra/devcontainer-features/src/node/install.sh
set -e

echo "Node/Bun DevContainer Feature installed"
echo "Node devShell will be activated via 'nix develop' in postStartCommand"

# Feature installation is minimal - actual Node/Bun comes from Nix devShell
# This feature primarily declares VS Code extensions and settings
