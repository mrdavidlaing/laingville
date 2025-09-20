#!/usr/bin/env bash

# Platform and OS detection functions
# Note: Do not set -e here as functions need to handle their own error cases

# Detect the current operating system
# Returns: "macos", "linux", or "unknown"
detect_os() {
  # Use full path to uname for reliability in restricted environments
  local uname_cmd
  if command -v uname > /dev/null 2>&1; then
    uname_cmd="uname"
  elif [[ -x "/usr/bin/uname" ]]; then
    uname_cmd="/usr/bin/uname"
  elif [[ -x "/bin/uname" ]]; then
    uname_cmd="/bin/uname"
  else
    echo "unknown"
    return
  fi

  case "$(${uname_cmd} -s)" in
    "Darwin") echo "macos" ;;
    "Linux") echo "linux" ;;
    *) echo "unknown" ;;
  esac
}

# Platform detection (builds on detect_os for sub-platform identification)
detect_platform() {
  local base_os
  base_os=$(detect_os)

  case "${base_os}" in
    "macos")
      # For macOS, platform equals OS
      echo "${base_os}"
      ;;
    "linux")
      # For Linux, detect the specific distribution/environment
      if [[ -f /usr/sbin/httpd ]] && [[ -d /www ]] && [[ -d /jffs ]]; then
        # ASUS router with FreshTomato firmware
        echo "freshtomato"
      elif grep -qi "microsoft\|wsl" /proc/version 2> /dev/null; then
        echo "wsl"
      elif command -v pacman > /dev/null 2>&1; then
        echo "arch"
      elif command -v nix > /dev/null 2>&1; then
        echo "nix"
      else
        echo "linux" # Generic Linux
      fi
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Map system username to dotfiles directory name
map_system_user_to_dotfiles_user() {
  local system_user
  system_user=$(whoami)
  case "${system_user}" in
    "david" | "mrdavidlaing" | "coder" | *"DavidLaing"*)
      echo "mrdavidlaing"
      ;;
    "timmy")
      echo "timmmmmmer"
      ;;
    *)
      echo "shared"
      ;;
  esac
}
