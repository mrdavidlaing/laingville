#!/bin/bash

# Functions specific to setup-server script
# Note: Do not set -e here as functions need to handle their own error cases

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.functions.bash"

# Map hostname to server directory
map_hostname_to_server_dir() {
    local hostname="$1"
    echo "servers/$hostname"
}

# Get server packages using shared function but with server-specific path
get_server_packages() {
    local platform="$1" manager="$2"
    local packages_file="$SERVER_DIR/packages.yml"
    get_packages_from_file "$platform" "$manager" "$packages_file"
}

# Handle server package management
handle_server_packages() {
    local platform="$1" dry_run="$2"
    local packages_file="$SERVER_DIR/packages.yml"
    handle_packages_from_file "$platform" "$dry_run" "$packages_file" "SERVER"
}