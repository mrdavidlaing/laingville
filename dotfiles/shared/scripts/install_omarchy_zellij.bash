#!/usr/bin/env bash

set -e

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
  git pull origin main 2>/dev/null || true
else
  echo "Cloning omarchy-zellij repository..."
  git clone https://github.com/cedricwider/omarchy-zellij "$OMARCHY_ZELLIJ_DIR" 2>/dev/null || {
    echo "[ERROR] Failed to clone omarchy-zellij repository"
    exit 1
  }
  cd "$OMARCHY_ZELLIJ_DIR"
fi

# Install hook script
echo "Installing hook script..."
cp "$OMARCHY_ZELLIJ_DIR/scripts/omarchy-zellij-hook" "$HOOK_DEST"
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
      if python3 "$OMARCHY_ZELLIJ_DIR/scripts/convert_theme.py" "$theme_name" "$theme_dir/kitty.conf" > "$output_file" 2>/dev/null; then
        ((theme_count++))
      else
        echo "[omarchy-zellij] [WARN] Failed to convert theme: $theme_name"
      fi
    fi
  fi
done

# Also convert current theme if it exists
if [[ -f "$HOME/.config/omarchy/current/theme/kitty.conf" ]]; then
  current_theme_name=$(basename "$(readlink -f "$HOME/.config/omarchy/current/theme" | xargs dirname)")
  if [[ -z "$current_theme_name" ]]; then
    current_theme_name="current"
  fi
  
  output_file="$THEMES_DIR/${current_theme_name}.kdl"
  if [[ ! -f "$output_file" ]]; then
    echo "  Converting current Omarchy theme..."
    if python3 "$OMARCHY_ZELLIJ_DIR/scripts/convert_theme.py" "$current_theme_name" "$HOME/.config/omarchy/current/theme/kitty.conf" > "$output_file" 2>/dev/null; then
      ((theme_count++))
    fi
  fi
fi

echo "[omarchy-zellij] [OK] Installation complete!"
echo "[omarchy-zellij] Generated $theme_count Zellij themes"
echo "[omarchy-zellij] Hook: $HOOK_DEST"
echo "[omarchy-zellij] Themes: $THEMES_DIR"
echo "[omarchy-zellij] Usage: Change Omarchy theme and Zellij will automatically sync"
