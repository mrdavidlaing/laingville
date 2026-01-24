#!/usr/bin/env bash

DRY_RUN="${1:-false}"

if [[ "${DRY_RUN}" = "true" ]]; then
  echo "[omarchy-zellij] [DRY RUN] Would clone omarchy-zellij repo"
  echo "[omarchy-zellij] [DRY RUN] Would run omarchy-zellij installer"
  echo "[omarchy-zellij] [DRY RUN] Would convert themes"
  exit 0
fi

echo -n "[omarchy-zellij] "

# Check prerequisites
if ! command -v zellij &> /dev/null; then
  echo "[SKIP] zellij not installed (skipping omarchy-zellij installation)"
  exit 0
fi

if ! command -v python3 &> /dev/null; then
  echo "[ERROR] Python 3 is required but not installed"
  exit 1
fi

if [[ ! -d "$HOME/.config/omarchy" ]]; then
  echo "[SKIP] Omarchy not installed (skipping omarchy-zellij installation)"
  exit 0
fi

OMARCHY_ZELLIJ_DIR="$HOME/.config/omarchy-zellij"
THEMES_DIR="$HOME/.config/zellij/themes"
HOOK_DEST="$HOME/.local/bin/omarchy-zellij-hook"

# Create themes directory
mkdir -p "$THEMES_DIR"
mkdir -p "$HOME/.local/bin"

# Clone or update omarchy-zellij repository
if [[ -d "$OMARCHY_ZELLIJ_DIR" ]]; then
  echo "Updating omarchy-zellij repository..."
  cd "$OMARCHY_ZELLIJ_DIR"
  git pull origin main 2> /dev/null || true
else
  echo "Cloning omarchy-zellij repository..."
  git clone https://github.com/cedricwider/omarchy-zellij "$OMARCHY_ZELLIJ_DIR" 2> /dev/null || {
    echo "[ERROR] Failed to clone omarchy-zellij repository"
    exit 1
  }
  cd "$OMARCHY_ZELLIJ_DIR"
fi

# Install wrapper hook script that handles missing theme directories
echo "Installing hook script..."
cat > "$HOOK_DEST" << 'EOFHOOK'
#!/bin/bash
set -euo pipefail

readonly THEME_SNAKE="$1"
readonly THEME="${THEME_SNAKE//_/-}"
readonly THEME_DIR="$HOME/.config/omarchy/themes/$THEME"
readonly CURRENT_THEME_DIR="$HOME/.config/omarchy/current/theme"
readonly ZELLIJ_CONF="$HOME/.config/zellij/config.kdl"
readonly THEMES_DIR="$HOME/.config/zellij/themes"
readonly CONVERTER="$HOME/.config/omarchy-zellij/scripts/convert_theme.py"

# Validate zellij config exists
if [[ ! -f "$ZELLIJ_CONF" ]]; then
  echo "Error: Zellij config not found at $ZELLIJ_CONF" >&2
  exit 1
fi

# If theme directory doesn't exist, create it from current/theme
if [[ ! -d "$THEME_DIR" ]]; then
  if [[ -d "$CURRENT_THEME_DIR" ]] && [[ -f "$CURRENT_THEME_DIR/kitty.conf" ]]; then
    echo "[omarchy-zellij] Creating missing theme directory: $THEME"
    mkdir -p "$THEME_DIR"
    cp "$CURRENT_THEME_DIR"/* "$THEME_DIR/" 2>/dev/null || true
    
    # Also convert to zellij theme if converter exists
    if [[ -f "$CONVERTER" ]]; then
      mkdir -p "$THEMES_DIR"
      output_file="$THEMES_DIR/${THEME}.kdl"
      if python3 "$CONVERTER" "$THEME" "$CURRENT_THEME_DIR/kitty.conf" > "$output_file" 2>/dev/null; then
        echo "[omarchy-zellij] Successfully converted theme: $THEME"
      fi
    fi
  else
    echo "Error: Theme directory not found at $THEME_DIR and current/theme is not available" >&2
    exit 1
  fi
fi

# Update the theme line in zellij config by pattern matching
sed -i "s/^theme \"[^\"]*\"/theme \"$THEME\"/" "$ZELLIJ_CONF"
EOFHOOK
chmod +x "$HOOK_DEST"

# Register hook in Omarchy
echo "Registering hook with Omarchy..."
OMARCHY_HOOK_DIR="$HOME/.config/omarchy/hooks"
mkdir -p "$OMARCHY_HOOK_DIR"

OMARCHY_HOOK="$OMARCHY_HOOK_DIR/theme-set"

# Check if hook file exists and doesn't already contain our hook
if [[ -f "$OMARCHY_HOOK" ]]; then
  if ! grep -q "omarchy-zellij-hook" "$OMARCHY_HOOK"; then
    # Append our hook call to existing hook file
    echo "$HOOK_DEST \"\$1\"" >> "$OMARCHY_HOOK"
    echo "[omarchy-zellij] [OK] Hook registered in existing theme-set hook"
  else
    echo "[omarchy-zellij] [OK] Hook already registered"
  fi
else
  # Create new hook file with shebang
  cat > "$OMARCHY_HOOK" << EOFHOOK
#!/bin/bash
$HOOK_DEST "\$1"
EOFHOOK
  chmod +x "$OMARCHY_HOOK"
  echo "[omarchy-zellij] [OK] Created new theme-set hook with omarchy-zellij"
fi

# Convert themes from Omarchy to Zellij format
echo "Generating Zellij themes from Omarchy themes..."
theme_count=0

# Iterate over available Omarchy themes
for theme_dir in "$HOME/.config/omarchy/themes"/*/; do
  if [[ -f "$theme_dir/kitty.conf" ]]; then
    theme_name=$(basename "$theme_dir")
    output_file="$THEMES_DIR/${theme_name}.kdl"

    # Only regenerate if theme file doesn't exist
    if [[ ! -f "$output_file" ]]; then
      echo "  Converting $theme_name theme..."
      if python3 "$OMARCHY_ZELLIJ_DIR/scripts/convert_theme.py" "$theme_name" "$theme_dir/kitty.conf" > "$output_file" 2> /dev/null; then
        ((theme_count++))
      else
        echo "[omarchy-zellij] [WARN] Failed to convert theme: $theme_name"
      fi
    fi
  fi
done

# Also convert current theme if it exists and wasn't already converted above
if [[ -f "$HOME/.config/omarchy/current/theme/kitty.conf" ]]; then
  # Try to get theme name from current symlink, fallback to "current"
  if [[ -L "$HOME/.config/omarchy/current/theme" ]]; then
    current_theme_name=$(basename "$(readlink "$HOME/.config/omarchy/current/theme" | xargs dirname)" 2> /dev/null)
  fi

  if [[ -z "$current_theme_name" ]]; then
    # Fallback: check if there's a single theme in ~/.config/omarchy/themes/
    theme_dirs=("$HOME/.config/omarchy/themes"/*)
    if [[ ${#theme_dirs[@]} -eq 1 ]]; then
      current_theme_name=$(basename "${theme_dirs[0]}")
    else
      current_theme_name="current"
    fi
  fi

  output_file="$THEMES_DIR/${current_theme_name}.kdl"
  if [[ ! -f "$output_file" ]]; then
    echo "  Converting current Omarchy theme ($current_theme_name)..."
    if python3 "$OMARCHY_ZELLIJ_DIR/scripts/convert_theme.py" "$current_theme_name" "$HOME/.config/omarchy/current/theme/kitty.conf" > "$output_file" 2> /dev/null; then
      ((theme_count++))
    else
      echo "[omarchy-zellij] [WARN] Failed to convert current theme"
    fi
  fi
fi

echo "[omarchy-zellij] [OK] Installation complete!"
echo "[omarchy-zellij] Generated $theme_count Zellij themes"
echo "[omarchy-zellij] Hook: $HOOK_DEST"
echo "[omarchy-zellij] Themes: $THEMES_DIR"
echo "[omarchy-zellij] Usage: Change Omarchy theme and Zellij will automatically sync"
