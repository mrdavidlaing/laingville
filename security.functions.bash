#!/usr/bin/env bash

# Security validation functions for setup scripts
# These functions provide input validation and sanitization to prevent
# common security vulnerabilities like command injection and directory traversal

# Validate package names against allowed patterns
# Prevents command injection through malicious package names
validate_package_name() {
    local pkg="$1"
    
    # Check for empty or null input
    [ -z "$pkg" ] && return 1
    
    # Check length limit (reasonable package name length)
    [ ${#pkg} -gt 200 ] && return 1
    
    # Allow alphanumeric characters, dots, hyphens, underscores, and plus signs
    # This covers most legitimate package naming conventions
    [[ "$pkg" =~ ^[a-zA-Z0-9][a-zA-Z0-9._+-]*$ ]] || return 1
    
    # Reject obviously malicious patterns
    [[ "$pkg" =~ (\;|\&|\||\$|\`|\\) ]] && return 1
    
    return 0
}

# Validate file paths for directory traversal attacks
# Ensures paths stay within expected boundaries
validate_path_traversal() {
    local path="$1"
    local base_dir="$2"
    local allow_symlinks="${3:-false}"
    
    [ -z "$path" ] || [ -z "$base_dir" ] && return 1
    
    # For symlink validation, we want to validate the target path itself, not what it points to
    local canonical_path
    if [ -L "$path" ]; then
        # For existing symlinks, validate the path itself without following it
        canonical_path="$path"
    else
        # For non-symlinks, use normal canonicalization
        if command -v realpath >/dev/null 2>&1; then
            canonical_path=$(realpath -m "$path" 2>/dev/null)
        else
            canonical_path=$(readlink -f "$path" 2>/dev/null)
        fi
    fi
    
    # If canonicalization fails, try basic path validation
    if [ -z "$canonical_path" ]; then
        # Check if the path contains traversal sequences - if so, reject it
        if [[ "$path" =~ /\.\./ ]] || [[ "$path" =~ /\.\./$ ]] || [[ "$path" =~ ^\.\./ ]]; then
            return 1  # Reject paths with .. traversal when they can't be resolved
        fi
        canonical_path="$path"
    fi
    
    local canonical_base
    canonical_base=$(readlink -f "$base_dir" 2>/dev/null || echo "$base_dir")
    
    # If symlinks are not allowed, do a simple check for direct symlinks
    if [ "$allow_symlinks" != "true" ] && [ -L "$path" ]; then
        return 1  # Path itself is a symlink and symlinks not allowed
    fi
    
    # Ensure the canonical path starts with the canonical base directory
    case "$canonical_path" in
        "$canonical_base"/*) return 0 ;;
        "$canonical_base") return 0 ;;
        *) return 1 ;;
    esac
}

# Sanitize filename for safe filesystem operations
# Removes dangerous characters and path traversal sequences
sanitize_filename() {
    local filename="$1"
    
    [ -z "$filename" ] && return 1
    
    # Remove path traversal sequences using tr to avoid sed escaping issues
    filename=$(echo "$filename" | tr -d '/' | tr -d '\\')
    
    # Remove null bytes and other dangerous characters
    filename=$(echo "$filename" | tr -d '\0' | tr -d '<>:"|?*')
    
    # Remove dots to prevent hidden files and traversal remnants
    filename=$(echo "$filename" | tr -d '.')
    
    # Remove leading/trailing whitespace using parameter expansion
    filename="${filename#"${filename%%[![:space:]]*}"}"  # remove leading whitespace
    filename="${filename%"${filename##*[![:space:]]}"}"  # remove trailing whitespace
    
    # Ensure filename isn't empty after sanitization
    [ -z "$filename" ] && return 1
    
    echo "$filename"
    return 0
}

# Validate YAML configuration file
# Checks file size, existence, and basic structure safety
validate_yaml_file() {
    local file="$1"
    local max_size="${2:-10485760}"  # 10MB default limit
    local max_lines="${3:-10000}"    # Line limit to prevent DoS
    
    # Check file existence and readability
    [ -f "$file" ] || return 1
    [ -r "$file" ] || return 1
    
    # Check file size to prevent DoS attacks
    local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    [ "$file_size" -le "$max_size" ] || {
        echo "Error: Configuration file too large (${file_size} bytes > ${max_size} bytes)" >&2
        return 1
    }
    
    # Check line count
    local line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
    [ "$line_count" -le "$max_lines" ] || {
        echo "Error: Configuration file has too many lines (${line_count} > ${max_lines})" >&2
        return 1
    }
    
    # Basic YAML structure validation (check for common issues)
    if grep -q $'\t' "$file"; then
        echo "Error: YAML file contains tabs, use spaces for indentation" >&2
        return 1
    fi
    
    return 0
}

# Validate platform/manager strings for YAML parsing
# Prevents injection through platform/manager parameters
validate_yaml_key() {
    local key="$1"
    
    [ -z "$key" ] && return 1
    
    # Only allow lowercase letters, numbers, and underscores
    [[ "$key" =~ ^[a-z0-9_]+$ ]] || return 1
    
    # Check reasonable length
    [ ${#key} -le 50 ] || return 1
    
    return 0
}

# Validate sudo requirements and permissions
# Ensures safe privilege escalation
validate_sudo_requirements() {
    local operation="$1"
    
    # Check if sudo is available
    if ! command -v sudo >/dev/null 2>&1; then
        echo "Error: sudo not available for $operation" >&2
        return 1
    fi
    
    # Check if user can sudo without password (for automated operations)
    if ! sudo -n true 2>/dev/null; then
        echo "Error: sudo requires password for $operation" >&2
        echo "Please run: sudo -v" >&2
        return 1
    fi
    
    return 0
}

# Validate systemd unit names
# Ensures systemd unit names are safe to use
validate_systemd_unit_name() {
    local unit_name="$1"
    
    [ -z "$unit_name" ] && return 1
    
    # Check length
    [ ${#unit_name} -le 256 ] || return 1
    
    # Validate systemd unit name format
    # Allow alphanumeric, dots, hyphens, underscores, @ symbols
    [[ "$unit_name" =~ ^[a-zA-Z0-9@._-]+\.(service|timer|target|socket|mount|automount|swap|path|slice|scope)$ ]] || return 1
    
    # Reject dangerous patterns
    [[ "$unit_name" =~ (\.\.|/) ]] && return 1
    
    return 0
}

# Validate hostname for server configuration
# Ensures hostname values are safe for directory names
validate_hostname() {
    local hostname="$1"
    
    [ -z "$hostname" ] && return 1
    
    # Check length (reasonable hostname length)
    [ ${#hostname} -le 253 ] || return 1
    
    # Validate hostname format (RFC compliant)
    [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]] || return 1
    
    # Ensure it doesn't start or end with dots or hyphens
    [[ "$hostname" =~ ^[.-] ]] && return 1
    [[ "$hostname" =~ [.-]$ ]] && return 1
    
    return 0
}

# Sanitize and validate environment variables
# Ensures environment variables are safe to use
validate_environment_variable() {
    local var_name="$1"
    local var_value="$2"
    local expected_prefix="$3"
    
    [ -z "$var_name" ] || [ -z "$var_value" ] && return 1
    
    # Resolve canonical path first to handle relative paths correctly
    local canonical_path
    canonical_path=$(readlink -f "$var_value" 2>/dev/null || echo "$var_value")
    
    # Also resolve the expected prefix to handle relative paths  
    local canonical_prefix
    if [ -n "$expected_prefix" ]; then
        canonical_prefix=$(readlink -f "$expected_prefix" 2>/dev/null || echo "$expected_prefix")
        
        # Ensure canonical path is within canonical prefix
        case "$canonical_path" in
            "$canonical_prefix"/*) return 0 ;;
            "$canonical_prefix") return 0 ;;
            *) return 1 ;;
        esac
    fi
    
    return 0
}

# Security logging function
# Logs security events for monitoring
log_security_event() {
    local event_type="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to stderr for immediate visibility
    echo "SECURITY[$timestamp]: $event_type - $message" >&2
    
    # Also log to system log if available
    if command -v logger >/dev/null 2>&1; then
        logger -t "laingville-setup" "SECURITY: $event_type - $message"
    fi
}