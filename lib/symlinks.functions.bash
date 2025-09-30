#!/usr/bin/env bash

# Functions for handling symlinks configuration from packages.yaml

# Parse symlinks configuration from symlinks.yaml for a specific platform
# Args: $1 - path to symlinks.yaml, $2 - platform name
# Output: List of symlinks in format "source|target" (target is optional)
parse_symlinks_from_yaml() {
  local yaml_file="$1"
  local platform="$2"

  # Check if file exists
  if [[ ! -f "${yaml_file}" ]]; then
    return 1
  fi

  # Extract the platform section using sed/awk (simpler now without nested packages structure)
  local in_platform=0
  local current_entry=""
  local is_object=0

  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    # Check if we're entering the platform section
    if [[ "${line}" =~ ^${platform}: ]]; then
      in_platform=1
      continue
    fi

    # If we're in the platform section
    if [[ ${in_platform} -eq 1 ]]; then
      # If we hit a top-level key (no indentation), we're done with this platform
      if [[ "${line}" =~ ^[^[:space:]] ]]; then
        break
      fi

      # Process symlink entries (all entries in platform are symlinks now)
      if [[ "${line}" =~ ^[[:space:]]+-[[:space:]](.+) ]]; then
        # Flush previous entry if exists
        if [[ -n "${current_entry}" ]]; then
          echo "${current_entry}"
        fi

        # Start new entry
        local value="${BASH_REMATCH[1]}"

        # Strip comments from value
        value="${value%%#*}"
        # Strip trailing whitespace
        value="${value%"${value##*[![:space:]]}"}"

        # Check if it's an object (has source: prefix)
        if [[ "${value}" =~ ^source: ]]; then
          is_object=1
          current_entry="${value#source:}"
          current_entry="${current_entry# }" # Trim leading space
          current_entry="${current_entry}|"
        else
          is_object=0
          current_entry="${value}|"
        fi
      elif [[ "${line}" =~ ^[[:space:]]+source:[[:space:]](.+) && ${is_object} -eq 0 ]]; then
        # Object format starting on new line
        is_object=1
        current_entry="${BASH_REMATCH[1]}|"
      elif [[ "${line}" =~ ^[[:space:]]+target:[[:space:]](.+) && ${is_object} -eq 1 ]]; then
        # Add target to current entry
        current_entry="${current_entry%|*}|${BASH_REMATCH[1]}"
      fi
    fi
  done < "${yaml_file}"

  # Flush last entry
  if [[ -n "${current_entry}" ]]; then
    echo "${current_entry}"
  fi
}

# Process a single symlink entry from YAML
# Args: $1 - symlink entry (either string or "source:X target:Y" format)
# Output: "source|target" format
process_symlink_entry() {
  local entry="$1"

  # Check if it's an object format
  if echo "${entry}" | grep -q "source:"; then
    local source target
    source=$(echo "${entry}" | sed -n 's/.*source:\([^ ]*\).*/\1/p')
    target=$(echo "${entry}" | sed -n 's/.*target:\([^ ]*\).*/\1/p')

    # Expand environment variables in target
    if [[ -n "${target}" ]]; then
      target=$(eval echo "${target}")
    fi

    echo "${source}|${target}"
  else
    # Simple string format
    echo "${entry}|"
  fi
}

# Create a symlink with optional custom target
# Args:
#   $1 - source file path (in dotfiles)
#   $2 - custom target path (optional, can contain env vars)
#   $3 - default destination directory (e.g., ${HOME})
#   $4 - dry_run flag (true/false)
create_symlink_with_target() {
  local source="$1"
  local custom_target="$2"
  local dest_dir="$3"
  local dry_run="${4:-true}" # Default to true for safety

  local target
  if [[ -n "${custom_target}" ]]; then
    # Use custom target, expanding environment variables
    target=$(eval echo "${custom_target}")
  else
    # Use default target based on source path
    local filename
    filename=$(basename "${source}")

    # Construct default target path
    if [[ "${source}" == */.config/* ]]; then
      target="${dest_dir}/.config/${source##*/.config/}"
    elif [[ "${source}" == */.local/* ]]; then
      target="${dest_dir}/.local/${source##*/.local/}"
    else
      target="${dest_dir}/${filename}"
    fi
  fi

  # Create parent directory if needed
  local target_dir
  target_dir=$(dirname "${target}")

  # Check if target exists as a directory (but not a symlink) - problematic case
  if [[ -d "${target}" && ! -L "${target}" ]]; then
    echo "Error: Target '${target}' already exists as a directory. Cannot create symlink." >&2
    echo "This would result in a symlink being created inside the directory instead of replacing it." >&2
    echo "Please remove or rename the existing directory first." >&2
    return 1
  fi

  if [[ "${dry_run}" = "true" ]] || [[ "${dry_run}" = "false" ]]; then
    # Ensure dry_run is true for testing
    if [[ "${dry_run}" != "false" ]]; then
      echo "Would: create: ${target} -> ${source}"
    else
      mkdir -p "${target_dir}" 2> /dev/null
      create_symlink_force "${source}" "${target}"
      echo "Created: ${target} -> ${source}"
    fi
  else
    # Handle boolean values passed as 0/1
    if [[ "${dry_run}" -eq 0 ]]; then
      mkdir -p "${target_dir}" 2> /dev/null
      create_symlink_force "${source}" "${target}"
      echo "Created: ${target} -> ${source}"
    else
      echo "Would: create: ${target} -> ${source}"
    fi
  fi
}

# Process symlinks from symlinks.yaml for current platform
# Args:
#   $1 - symlinks.yaml path
#   $2 - platform
#   $3 - source dotfiles directory
#   $4 - destination directory (e.g., ${HOME})
#   $5 - dry_run flag
process_platform_symlinks() {
  local yaml_file="$1"
  local platform="$2"
  local src_dir="$3"
  local dest_dir="$4"
  local dry_run="${5:-false}"

  # Get symlinks configuration for platform
  local symlinks
  symlinks=$(parse_symlinks_from_yaml "${yaml_file}" "${platform}")

  if [[ -z "${symlinks}" ]]; then
    return 0
  fi

  # Process each symlink
  while IFS= read -r symlink_entry; do
    [[ -z "${symlink_entry}" ]] && continue

    # Split source and target
    local source="${symlink_entry%%|*}"
    local target="${symlink_entry#*|}"

    # Build full source path (remove trailing slash from src_dir)
    local full_source="${src_dir%/}/${source}"

    # Skip if source doesn't exist
    if [[ ! -e "${full_source}" ]]; then
      if [[ "${dry_run}" = "true" ]]; then
        echo "Would skip (not found): ${source}"
      fi
      continue
    fi

    # Create the symlink
    create_symlink_with_target "${full_source}" "${target}" "${dest_dir}" "${dry_run}"
  done <<< "${symlinks}"
}

# Get all unique symlinks across all platforms (for cleanup)
# Args: $1 - symlinks.yaml path
# Output: List of all possible symlink sources
get_all_symlinks() {
  local yaml_file="$1"
  local platforms="arch wsl windows macos"

  for platform in ${platforms}; do
    parse_symlinks_from_yaml "${yaml_file}" "${platform}" | cut -d'|' -f1 || true
  done | sort -u
}

# Parse cleanup symlinks configuration from symlinks.yaml for a specific platform
# Args: $1 - path to symlinks.yaml, $2 - platform name
# Output: List of symlinks in format "source|target" (target is optional)
parse_cleanup_symlinks_from_yaml() {
  local yaml_file="$1"
  local platform="$2"

  # Check if file exists
  if [[ ! -f "${yaml_file}" ]]; then
    return 1
  fi

  # Look for <platform>_cleanup as a top-level key
  local cleanup_platform="${platform}_cleanup"

  # Reuse the same parser as parse_symlinks_from_yaml, just with different platform name
  parse_symlinks_from_yaml "${yaml_file}" "${cleanup_platform}"
}

# Remove a symlink
# Args:
#   $1 - target path (symlink to remove)
#   $2 - dry_run flag (true/false)
remove_symlink() {
  local target="$1"
  local dry_run="${2:-true}"

  # Check if target is a symlink (works for both valid and broken symlinks)
  if [[ ! -L "${target}" ]]; then
    # Check if it exists as something else
    if [[ -e "${target}" ]]; then
      echo "Skipped (not a symlink): ${target}"
    else
      echo "Skipped (not found): ${target}"
    fi
    return 0
  fi

  # Remove the symlink
  if [[ "${dry_run}" = "true" ]]; then
    echo "Would remove: ${target}"
  else
    rm -f "${target}"
    echo "Removed: ${target}"
  fi
}

# Process cleanup symlinks from symlinks.yaml for current platform
# Args:
#   $1 - symlinks.yaml path
#   $2 - platform
#   $3 - source dotfiles directory (not used for cleanup, but kept for consistency)
#   $4 - destination directory (e.g., ${HOME})
#   $5 - dry_run flag
process_cleanup_symlinks() {
  local yaml_file="$1"
  local platform="$2"
  local src_dir="$3"
  local dest_dir="$4"
  local dry_run="${5:-false}"

  # Get cleanup symlinks configuration for platform
  local cleanup_symlinks
  cleanup_symlinks=$(parse_cleanup_symlinks_from_yaml "${yaml_file}" "${platform}")

  if [[ -z "${cleanup_symlinks}" ]]; then
    return 0
  fi

  # Process each cleanup symlink
  while IFS= read -r symlink_entry; do
    [[ -z "${symlink_entry}" ]] && continue

    # Split source and target
    local source="${symlink_entry%%|*}"
    local target="${symlink_entry#*|}"

    # Determine the target path
    local target_path
    if [[ -n "${target}" ]]; then
      # Use custom target, expanding environment variables
      target_path=$(eval echo "${target}")
    else
      # Use default target based on source path
      local filename
      filename=$(basename "${source}")

      # Construct default target path
      if [[ "${source}" == .config/* || "${source}" == */.config/* ]]; then
        target_path="${dest_dir}/.config/${source##*/.config/}"
        # Handle case where source starts with .config/
        if [[ "${source}" == .config/* ]]; then
          target_path="${dest_dir}/${source}"
        fi
      elif [[ "${source}" == .local/* || "${source}" == */.local/* ]]; then
        target_path="${dest_dir}/.local/${source##*/.local/}"
        # Handle case where source starts with .local/
        if [[ "${source}" == .local/* ]]; then
          target_path="${dest_dir}/${source}"
        fi
      else
        target_path="${dest_dir}/${filename}"
      fi
    fi

    # Remove the symlink
    remove_symlink "${target_path}" "${dry_run}"
  done <<< "${cleanup_symlinks}"
}
