#!/usr/bin/env bash
#
# WHY: Generate Claude Code settings.json from platform-appropriate templates
# WHAT:
#   1. Detect platform (Windows/Mac/Linux)
#   2. Choose appropriate template (settings.template.json or settings.windows.json)
#   3. Substitute {{USERNAME}} with current user
#   4. Create ~/.claude/settings.json if missing, or show diff if different
# HOW:
#   ./generate-settings.sh
# NOTES:
#   - Won't overwrite existing settings - shows diff instead
#   - Windows: Uses settings.windows.json if bash not in PATH
#   - Mac/Linux: Always uses settings.template.json

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
readonly TEMPLATE_FILE="${SCRIPT_DIR}/settings.template.json"
readonly WINDOWS_TEMPLATE="${SCRIPT_DIR}/settings.windows.json"
readonly TARGET_DIR="${HOME}/.claude"
readonly TARGET_FILE="${TARGET_DIR}/settings.json"

# Source shared functions
source "${PROJECT_ROOT}/lib/logging.functions.bash"
source "${PROJECT_ROOT}/lib/platform.functions.bash"

main() {
  log_info "Generating Claude Code settings from template"

  # Choose template based on platform
  local platform="${PLATFORM:-$(detect_platform)}"
  local source_template="${TEMPLATE_FILE}"

  if [[ "${platform}" = "windows" ]] && ! command -v bash > /dev/null 2>&1; then
    source_template="${WINDOWS_TEMPLATE}"
    log_info "Using Windows-specific template (bash not in PATH)"
  fi

  # Substitute {{USERNAME}} with current user
  local username="${USER:-${USERNAME:-$(whoami)}}"
  local temp_file
  temp_file=$(mktemp)
  trap 'rm -f "${temp_file}"' EXIT

  sed "s/{{USERNAME}}/${username}/g" "${source_template}" > "${temp_file}"

  # Create target directory if needed
  mkdir -p "${TARGET_DIR}"

  # Check if target exists and differs
  if [[ -f "${TARGET_FILE}" ]]; then
    if diff -q "${temp_file}" "${TARGET_FILE}" > /dev/null 2>&1; then
      log_success "Settings file is already up to date"
      exit 0
    fi

    log_warning "Settings file exists and differs from template"
    echo ""
    echo "Differences (template → current):"
    echo "-----------------------------------"
    diff -u "${temp_file}" "${TARGET_FILE}" || true
    echo ""
    log_info "To update settings, run: rm ${TARGET_FILE} && $0"
    exit 0
  fi

  # Create new settings file
  cp "${temp_file}" "${TARGET_FILE}"
  log_success "Created ${TARGET_FILE}"
}

main
