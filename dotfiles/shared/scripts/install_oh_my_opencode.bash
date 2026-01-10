#!/usr/bin/env bash

set -e

DRY_RUN="${1:-false}"
OMO_VERSION="${2:-beta}"

OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OPENCODE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
OPENCODE_JSON="$OPENCODE_CONFIG_DIR/opencode.json"
OMO_JSON="$OPENCODE_CONFIG_DIR/oh-my-opencode.json"
PROFILES_DIR="$OPENCODE_CONFIG_DIR/profiles"

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[oh-my-opencode] [DRY RUN] Would register oh-my-opencode@${OMO_VERSION} plugin in opencode.json"
  echo "[oh-my-opencode] [DRY RUN] Would symlink oh-my-opencode.json to profiles/value.json"
  echo "[oh-my-opencode] [DRY RUN] Would run 'bun install' in opencode cache directory"
  exit 0
fi

echo -n "[oh-my-opencode] "

if ! command -v opencode &> /dev/null; then
  echo "[SKIP] opencode not installed"
  exit 0
fi

if ! command -v jq &> /dev/null; then
  echo "[ERROR] jq is required but not installed"
  exit 1
fi

# Check for bun (required for plugin installation)
if ! command -v bun &> /dev/null; then
  echo "[ERROR] bun is required but not installed"
  exit 1
fi

mkdir -p "$OPENCODE_CONFIG_DIR"

# Step 1: Register plugin in opencode.json
echo "Registering oh-my-opencode@${OMO_VERSION} plugin..."
if [[ -f "$OPENCODE_JSON" ]]; then
  if jq -e '.plugin | index("oh-my-opencode")' "$OPENCODE_JSON" > /dev/null 2>&1; then
    echo "[oh-my-opencode] [OK] oh-my-opencode already in opencode.json"
  else
    tmp=$(mktemp)
    jq '.plugin = ((.plugin // []) + ["oh-my-opencode"] | unique)' "$OPENCODE_JSON" > "$tmp"
    mv "$tmp" "$OPENCODE_JSON"
    echo "[oh-my-opencode] [OK] Added oh-my-opencode to opencode.json"
  fi
else
  echo "Creating opencode.json with oh-my-opencode plugin..."
  mkdir -p "$OPENCODE_CONFIG_DIR"
  cat > "$OPENCODE_JSON" << 'EOFCONFIG'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["oh-my-opencode"]
}
EOFCONFIG
  echo "[oh-my-opencode] [OK] Created opencode.json"
fi

# Step 2: Setup oh-my-opencode.json symlink to custom profile
echo "Setting up oh-my-opencode.json symlink..."
if [[ ! -L "$OMO_JSON" ]] && [[ ! -f "$OMO_JSON" ]]; then
  if [[ -d "$PROFILES_DIR" ]] && [[ -f "$PROFILES_DIR/value.json" ]]; then
    ln -s "profiles/value.json" "$OMO_JSON"
    echo "[oh-my-opencode] [OK] Created symlink: oh-my-opencode.json -> profiles/value.json"
  else
    echo "[oh-my-opencode] [WARN] No profiles found, skipping oh-my-opencode.json symlink"
  fi
elif [[ -L "$OMO_JSON" ]]; then
  current_target=$(readlink "$OMO_JSON")
  echo "[oh-my-opencode] [OK] oh-my-opencode.json symlink already exists: $current_target"
elif [[ -f "$OMO_JSON" ]]; then
  echo "[oh-my-opencode] [OK] oh-my-opencode.json file already exists (not a symlink)"
fi

# Step 3: Install oh-my-opencode in opencode cache directory (where opencode loads plugins from)
echo "Installing plugins via bun in $OPENCODE_CACHE_DIR..."
mkdir -p "$OPENCODE_CACHE_DIR"
cd "$OPENCODE_CACHE_DIR"

# Check if package.json exists in cache dir
if [[ ! -f "package.json" ]]; then
  # Create minimal package.json for oh-my-opencode
  echo "Creating package.json with oh-my-opencode dependency..."
  cat > "package.json" << EOFPKG
{
  "dependencies": {
    "oh-my-opencode": "${OMO_VERSION}"
  }
}
EOFPKG
else
  # Check if oh-my-opencode is already in package.json
  if grep -q '"oh-my-opencode"' package.json; then
    current_version=$(grep -oP '"oh-my-opencode":\s*"\K[^"]+' package.json || echo "unknown")
    if [[ "$current_version" == "$OMO_VERSION" ]]; then
      echo "[oh-my-opencode] [OK] oh-my-opencode@${OMO_VERSION} already in package.json"
    else
      echo "[oh-my-opencode] Updating oh-my-opencode from $current_version to ${OMO_VERSION}..."
      tmp=$(mktemp)
      jq --arg version "$OMO_VERSION" '.dependencies."oh-my-opencode" = $version' package.json > "$tmp"
      mv "$tmp" package.json
    fi
  else
    # Add oh-my-opencode to existing package.json
    echo "Adding oh-my-opencode@${OMO_VERSION} to package.json..."
    tmp=$(mktemp)
    jq --arg version "$OMO_VERSION" '.dependencies."oh-my-opencode" = $version' package.json > "$tmp"
    mv "$tmp" package.json
  fi
fi

# Run bun install to resolve dependencies
if bun install; then
  echo "[oh-my-opencode] [OK] Installed oh-my-opencode@${OMO_VERSION} via bun"
else
  echo "[oh-my-opencode] [ERROR] bun install failed"
  exit 1
fi

echo "[oh-my-opencode] [OK] Installation complete!"
echo "[oh-my-opencode] Version: ${OMO_VERSION}"
echo "[oh-my-opencode] Config: $OPENCODE_JSON"
echo "[oh-my-opencode] Cache: $OPENCODE_CACHE_DIR/node_modules/oh-my-opencode"
echo "[oh-my-opencode] Profile: $(readlink "$OMO_JSON" 2> /dev/null || echo 'not symlinked')"
