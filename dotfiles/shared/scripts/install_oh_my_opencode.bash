#!/usr/bin/env bash

set -e

DRY_RUN="${1:-false}"
OMO_VERSION="${2:-latest}"

OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OPENCODE_JSON="$OPENCODE_CONFIG_DIR/opencode.json"
OMO_JSON="$OPENCODE_CONFIG_DIR/oh-my-opencode.json"
PROFILES_DIR="$OPENCODE_CONFIG_DIR/profiles"
OPENCODE_BIN_DIR="$HOME/.local/share/opencode/bin"

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[oh-my-opencode] [DRY RUN] Would register oh-my-opencode@${OMO_VERSION} plugin"
  echo "[oh-my-opencode] [DRY RUN] Would npm install oh-my-opencode@${OMO_VERSION} in opencode's node_modules"
  exit 0
fi

echo -n "[oh-my-opencode] "

if ! command -v opencode &>/dev/null; then
  echo "[SKIP] opencode not installed"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "[ERROR] jq is required but not installed"
  exit 1
fi

# Check for npm-compatible package manager
if ! command -v npm &>/dev/null && ! command -v bun &>/dev/null; then
  echo "[ERROR] npm or bun is required but not installed"
  exit 1
fi

mkdir -p "$OPENCODE_CONFIG_DIR"

# Step 1: Register plugin in opencode.json
if [[ -f "$OPENCODE_JSON" ]]; then
  if jq -e '.plugin | index("oh-my-opencode")' "$OPENCODE_JSON" >/dev/null 2>&1; then
    echo "[OK] oh-my-opencode already in opencode.json"
  else
    echo "Adding oh-my-opencode to plugin list..."
    tmp=$(mktemp)
    jq '.plugin = ((.plugin // []) + ["oh-my-opencode"] | unique)' "$OPENCODE_JSON" >"$tmp"
    mv "$tmp" "$OPENCODE_JSON"
    echo "[oh-my-opencode] [OK] Added to opencode.json"
  fi
else
  echo "Creating opencode.json with oh-my-opencode..."
  cat >"$OPENCODE_JSON" <<'EOFCONFIG'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["oh-my-opencode"]
}
EOFCONFIG
  echo "[oh-my-opencode] [OK] Created opencode.json"
fi

# Step 2: npm install oh-my-opencode in opencode's local node_modules
if [[ -d "$OPENCODE_BIN_DIR" ]]; then
  if [[ -f "$OPENCODE_BIN_DIR/package.json" ]]; then
    cd "$OPENCODE_BIN_DIR"
    
    # Choose installer (prefer bun over npm)
    if command -v bun &>/dev/null; then
      installer="bun"
    else
      installer="npm"
    fi
    
    # Check current version
    current_version=$(grep -oP '"oh-my-opencode":\s*"\K[^"]+' "$OPENCODE_BIN_DIR/package.json" || echo "not installed")
    
    if [[ "$current_version" != "not installed" ]] && [[ "$current_version" == "^${OMO_VERSION}" || "$current_version" == "$OMO_VERSION" ]]; then
      echo "[OK] oh-my-opencode@${OMO_VERSION} already installed"
    else
      echo "Installing oh-my-opencode@${OMO_VERSION} via ${installer}..."
      ${installer} install oh-my-opencode@${OMO_VERSION}
      echo "[oh-my-opencode] [OK] Installed oh-my-opencode@${OMO_VERSION}"
    fi
  else
    echo "[WARN] No package.json found in $OPENCODE_BIN_DIR"
  fi
else
  echo "[WARN] $OPENCODE_BIN_DIR not found - opencode may not be fully installed"
fi

# Step 3: Set up oh-my-opencode.json symlink if not present
if [[ ! -L "$OMO_JSON" ]] && [[ ! -f "$OMO_JSON" ]]; then
  if [[ -d "$PROFILES_DIR" ]] && [[ -f "$PROFILES_DIR/value.json" ]]; then
    ln -s "profiles/value.json" "$OMO_JSON"
    echo "[oh-my-opencode] [OK] Set default profile to 'value'"
  else
    echo "[oh-my-opencode] [WARN] No profiles found, skipping default profile"
  fi
elif [[ -L "$OMO_JSON" ]]; then
  current_profile=$(basename "$(readlink "$OMO_JSON")" .json)
  echo "[oh-my-opencode] [OK] Profile already set: $current_profile"
fi
