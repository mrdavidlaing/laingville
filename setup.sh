#!/usr/bin/env bash

# A simple dispatcher for the main setup scripts.
# It ensures scripts are executed from the project root
# and passes all arguments to the target script.

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Check if we have any arguments
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 {user|server|secrets} [args...]" >&2
  echo "  user    : Run user dotfile setup" >&2
  echo "  server  : Run server configuration" >&2
  exit 1
fi

COMMAND="${1}"
shift # Remove the command from the argument list

case "${COMMAND}" in
  user)
    exec "${SCRIPT_DIR}/bin/setup-user" "$@"
    ;;
  server)
    exec "${SCRIPT_DIR}/bin/setup-server" "$@"
    ;;
  secrets)
    exec "${SCRIPT_DIR}/setup-secrets" "$@"
    ;;
  *)
    echo "Usage: $0 {user|server|secrets} [args...]" >&2
    echo "  user    : Run user dotfile setup" >&2
    echo "  server  : Run server configuration" >&2
    exit 1
    ;;
esac
