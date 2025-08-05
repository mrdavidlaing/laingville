#!/usr/bin/env bash

# Platform polyfill functions for cross-platform compatibility
# These functions abstract platform-specific command differences

# Detect the current operating system
# Returns: "macos", "linux", or "unknown"
detect_os() {
    case "$(uname -s)" in
        "Darwin") echo "macos" ;;
        "Linux") echo "linux" ;;
        *) echo "unknown" ;;
    esac
}

# Cross-platform canonicalize path function
# On macOS, prefer realpath; on Linux, use readlink -f
# Args: $1 - path to canonicalize
# Returns: canonical absolute path or empty string on failure
canonicalize_path() {
    local path="$1"
    [ -z "$path" ] && return 1
    
    local os_type
    os_type=$(detect_os)
    
    case "$os_type" in
        "macos")
            if command -v realpath >/dev/null 2>&1; then
                # Use realpath if available (preferred on macOS)
                if [ -e "$path" ]; then
                    realpath "$path" 2>/dev/null
                else
                    # For non-existing files, canonicalize the parent and append the filename
                    local parent_dir=$(dirname "$path")
                    local filename=$(basename "$path")
                    local canonical_parent
                    canonical_parent=$(realpath "$parent_dir" 2>/dev/null || echo "$parent_dir")
                    echo "$canonical_parent/$filename"
                fi
            else
                # Fallback to readlink if realpath not available
                readlink -f "$path" 2>/dev/null
            fi
            ;;
        "linux")
            # Use readlink -f on Linux
            readlink -f "$path" 2>/dev/null
            ;;
        *)
            # Unknown platform - try both approaches
            if command -v realpath >/dev/null 2>&1; then
                realpath "$path" 2>/dev/null
            else
                readlink -f "$path" 2>/dev/null
            fi
            ;;
    esac
}

# Cross-platform file size function
# Args: $1 - file path
# Returns: file size in bytes or "0" on failure
get_file_size() {
    local file="$1"
    [ -z "$file" ] || [ ! -f "$file" ] && { echo "0"; return 1; }
    
    local os_type
    os_type=$(detect_os)
    
    if command -v stat >/dev/null 2>&1; then
        case "$os_type" in
            "linux")
                # Linux format
                stat -c%s "$file" 2>/dev/null || echo "0"
                ;;
            "macos")
                # macOS/BSD format
                stat -f%z "$file" 2>/dev/null || echo "0"
                ;;
            *)
                # Unknown platform - try both formats
                stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0"
                ;;
        esac
    else
        echo "0"
    fi
}

# Cross-platform readlink function that handles symlinks consistently
# Args: $1 - path to read
# Returns: target of symlink or empty string if not a symlink/error
read_symlink() {
    local path="$1"
    [ -z "$path" ] && return 1
    [ ! -L "$path" ] && return 1
    
    local os_type
    os_type=$(detect_os)
    
    case "$os_type" in
        "macos")
            # macOS readlink doesn't have -f flag by default
            readlink "$path" 2>/dev/null
            ;;
        "linux")
            # Linux readlink
            readlink "$path" 2>/dev/null
            ;;
        *)
            # Unknown platform
            readlink "$path" 2>/dev/null
            ;;
    esac
}

# Check if a command supports specific flags
# Args: $1 - command name, $2 - flag to test
# Returns: 0 if supported, 1 if not
command_supports_flag() {
    local cmd="$1"
    local flag="$2"
    
    [ -z "$cmd" ] || [ -z "$flag" ] && return 1
    
    # Test the flag with help or version output to avoid side effects
    "$cmd" "$flag" --help >/dev/null 2>&1 || \
    "$cmd" --help 2>&1 | grep -q -- "$flag" 2>/dev/null
}

# Cross-platform realpath-like function that works everywhere
# This is the main function to use for path canonicalization
# Args: $1 - path to resolve
# Returns: absolute canonical path
resolve_path() {
    local path="$1"
    [ -z "$path" ] && return 1
    
    # First try the polyfill canonicalize function
    local canonical
    canonical=$(canonicalize_path "$path")
    
    if [ -n "$canonical" ]; then
        echo "$canonical"
        return 0
    fi
    
    # Fallback: basic path normalization
    # Convert to absolute path if relative
    if [[ "$path" != /* ]]; then
        path="$(pwd)/$path"
    fi
    
    # Basic cleanup of . and .. components
    # This is a simplified approach - not as robust as real canonicalization
    echo "$path" | sed -e 's|/\./|/|g' -e 's|/[^/]*/\.\./|/|g' -e 's|//|/|g'
}