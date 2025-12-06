#!/bin/bash
# infra/devcontainer-features/src/python/install.sh
set -e

echo "Python DevContainer Feature installed"
echo "Python devShell will be activated via 'nix develop' in postStartCommand"

# Feature installation is minimal - actual Python comes from Nix devShell
# This feature primarily declares VS Code extensions and settings
