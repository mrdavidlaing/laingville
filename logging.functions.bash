#!/usr/bin/env bash

# Comprehensive logging system for setup scripts
# Provides consistent, scannable output with clear visual hierarchy

# Color and formatting constants
readonly LOG_RESET='\033[0m'
readonly LOG_BOLD='\033[1m'
readonly LOG_DIM='\033[2m'

# Color palette optimized for readability
readonly LOG_RED='\033[31m'
readonly LOG_GREEN='\033[32m'
readonly LOG_YELLOW='\033[33m'
readonly LOG_BLUE='\033[34m'
readonly LOG_MAGENTA='\033[35m'
readonly LOG_CYAN='\033[36m'
readonly LOG_WHITE='\033[37m'
readonly LOG_GRAY='\033[90m'

# Icons for better visual scanning
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✗"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_DEBUG="🔍"
readonly ICON_SECTION="▶"
readonly ICON_SUBSECTION="  ▸"
readonly ICON_DRY_RUN="•"

# Global state for consistent formatting
LOG_INDENT_LEVEL=0
LOG_QUIET=${LOG_QUIET:-false}
LOG_NO_COLOR=${LOG_NO_COLOR:-false}
LOG_COLOR_ENABLED=${LOG_COLOR_ENABLED:-false}

# Initialize logging system - call once at script start
log_init() {
    # Detect if we should use colors
    # Check for explicit disable first
    if [[ "${LOG_NO_COLOR}" == "true" ]]; then
        LOG_COLOR_ENABLED=false
    # Check for dumb terminal
    elif [[ "${TERM}" == "dumb" ]]; then
        LOG_COLOR_ENABLED=false
    # Check if stdout is a terminal OR if we have a TERM that supports colors
    elif [[ -t 1 ]] || [[ "${TERM}" =~ ^(xterm|screen|tmux|rxvt|linux|vt|alacritty) ]] || [[ "${TERM}" == *"256color"* ]]; then
        LOG_COLOR_ENABLED=true
    else
        LOG_COLOR_ENABLED=false
    fi
    
    # Show script start banner
    local script_name=$(basename "${0}")
    log_section "Starting ${script_name}"
    
    # Show dry-run mode if enabled
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
        echo
    fi
}

# Apply color formatting if enabled
_log_color() {
    local color="$1"
    local text="$2"
    
    if [[ "${LOG_COLOR_ENABLED}" == "true" ]]; then
        echo -e "${color}${text}${LOG_RESET}"
    else
        echo -e "${text}"
    fi
}

# Get current timestamp for logging
_log_timestamp() {
    date '+%H:%M:%S'
}

# Generate indent string based on current level
_log_indent() {
    printf "%*s" $((LOG_INDENT_LEVEL * 2)) ""
}

# Main section header - highest level visual break
log_section() {
    local message="$1"
    local timestamp=$(_log_timestamp)
    
    echo
    _log_color "${LOG_BOLD}${LOG_BLUE}" "$(_log_indent)${message}"
    _log_color "${LOG_BLUE}" "$(_log_indent)$(printf '─%.0s' {1..20})"
}

# Subsection header - secondary level grouping
log_subsection() {
    local message="$1"
    
    echo
    _log_color "${LOG_BOLD}${LOG_CYAN}" "$(_log_indent)${message}"
}

# Success message - operations completed successfully
log_success() {
    local message="$1"
    
    _log_color "${LOG_GREEN}" "$(_log_indent)${ICON_SUCCESS} ${message}"
}

# Error message - critical failures (goes to stderr)
log_error() {
    local message="$1"
    
    _log_color "${LOG_BOLD}${LOG_RED}" "$(_log_indent)${ICON_ERROR} ERROR: ${message}" >&2
}

# Warning message - non-critical issues
log_warning() {
    local message="$1"
    
    _log_color "${LOG_YELLOW}" "$(_log_indent)${ICON_WARNING} Warning: ${message}"
}

# Info message - general information
log_info() {
    local message="$1"
    
    [[ "${LOG_QUIET}" == "true" ]] && return
    _log_color "${LOG_WHITE}" "$(_log_indent)${ICON_INFO} ${message}"
}

# Debug message - detailed troubleshooting info
log_debug() {
    local message="$1"
    
    [[ "${LOG_DEBUG:-false}" != "true" ]] && return
    _log_color "${LOG_DIM}${LOG_GRAY}" "$(_log_indent)${ICON_DEBUG} ${message}"
}

# Dry-run specific messages
log_dry_run() {
    local message="$1"
    
    _log_color "${LOG_MAGENTA}" "$(_log_indent)${ICON_DRY_RUN} Would: ${message}"
}

# Progress indicator for long operations
log_progress() {
    local current="$1"
    local total="$2"
    local item="$3"
    
    _log_color "${LOG_CYAN}" "$(_log_indent)(${current}/${total}) ${item}"
}

# Indent management for nested operations
log_indent() {
    ((LOG_INDENT_LEVEL++))
}

log_unindent() {
    ((LOG_INDENT_LEVEL > 0)) && ((LOG_INDENT_LEVEL--))
}

# Scoped indentation - auto-unindent after command
log_with_indent() {
    log_indent
    "$@"
    log_unindent
}

# Summary functions for script completion
log_summary_start() {
    local title="$1"
    echo
    _log_color "${LOG_BOLD}${LOG_WHITE}" "┌─ ${title} Summary"
}

log_summary_item() {
    local status="$1"  # success, warning, error, info
    local message="$2"
    
    local icon color
    case "$status" in
        success) icon="${ICON_SUCCESS}" color="${LOG_GREEN}" ;;
        warning) icon="${ICON_WARNING}" color="${LOG_YELLOW}" ;;
        error)   icon="${ICON_ERROR}"   color="${LOG_RED}" ;;
        info)    icon="${ICON_INFO}"    color="${LOG_WHITE}" ;;
        *)       icon="•"               color="${LOG_WHITE}" ;;
    esac
    
    _log_color "${color}" "├─ ${icon} ${message}"
}

log_summary_end() {
    _log_color "${LOG_GRAY}" "└─"
    echo
}

# Timer functions for performance tracking
declare -A LOG_TIMERS

log_timer_start() {
    local name="$1"
    LOG_TIMERS["$name"]=$(date +%s)
}

log_timer_end() {
    local name="$1"
    local message="$2"
    
    if [[ -n "${LOG_TIMERS[$name]}" ]]; then
        local start_time="${LOG_TIMERS[$name]}"
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        unset LOG_TIMERS["$name"]
        
        if [[ -n "$message" ]]; then
            log_info "${message} (${duration}s)"
        else
            log_info "Completed ${name} in ${duration}s"
        fi
    fi
}

# Specialized logging for common operations
log_package_install() {
    local manager="$1"
    local packages="$2"
    local dry_run="$3"
    
    if [[ "$dry_run" == "true" ]]; then
        log_dry_run "Install via ${manager}: ${packages}"
    else
        log_info "Installing via ${manager}: ${packages}"
    fi
}

log_symlink() {
    local target="$1"
    local source="$2"
    local dry_run="$3"
    
    if [[ "$dry_run" == "true" ]]; then
        log_dry_run "Link ${target} → ${source}"
    else
        log_success "Linked ${target}"
    fi
}

log_script_result() {
    local script="$1"
    local success="$2"
    
    if [[ "$success" == "true" ]]; then
        log_success "Script ${script} completed"
    else
        log_error "Script ${script} failed"
    fi
}

# Security event logging (enhanced version of existing function)
log_security_event() {
    local event_type="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Always log security events as errors (they go to stderr)
    log_error "SECURITY[${timestamp}]: ${event_type} - ${message}"
    
    # Also log to system log if available
    if command -v logger >/dev/null 2>&1; then
        logger -t "laingville-setup" "SECURITY: $event_type - $message"
    fi
}

# Cleanup function - call at script end
log_finish() {
    local exit_code="${1:-0}"
    local script_name=$(basename "${0}")
    
    echo
    if [[ "$exit_code" -eq 0 ]]; then
        log_success "Completed ${script_name} successfully"
    else
        log_error "Failed ${script_name} with exit code ${exit_code}"
    fi
    
    # Clean up any remaining timers
    for timer in "${!LOG_TIMERS[@]}"; do
        log_timer_end "$timer"
    done
}

# Trap to ensure cleanup happens
trap 'log_finish $?' EXIT