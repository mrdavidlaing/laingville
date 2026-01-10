#!/usr/bin/env bash

set -e

DRY_RUN="${1:-false}"

OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OPENCODE_JSON="$OPENCODE_CONFIG_DIR/opencode.json"
OMO_JSON="$OPENCODE_CONFIG_DIR/oh-my-opencode.json"
PROFILES_DIR="$OPENCODE_CONFIG_DIR/profiles"

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[oh-my-opencode] [DRY RUN] Would install oh-my-opencode plugin"
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

mkdir -p "$OPENCODE_CONFIG_DIR"

if [[ -f "$OPENCODE_JSON" ]]; then
  if jq -e '.plugin | index("oh-my-opencode")' "$OPENCODE_JSON" > /dev/null 2>&1; then
    echo "[OK] oh-my-opencode already configured"
  else
    echo "Adding oh-my-opencode to plugin list..."
    tmp=$(mktemp)
    jq '.plugin = ((.plugin // []) + ["oh-my-opencode"] | unique)' "$OPENCODE_JSON" > "$tmp"
    mv "$tmp" "$OPENCODE_JSON"
    echo "[oh-my-opencode] [OK] Added to opencode.json"
  fi
else
  echo "Creating opencode.json with oh-my-opencode..."
  cat > "$OPENCODE_JSON" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["oh-my-opencode"]
}
EOF
  echo "[oh-my-opencode] [OK] Created opencode.json"
fi

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
