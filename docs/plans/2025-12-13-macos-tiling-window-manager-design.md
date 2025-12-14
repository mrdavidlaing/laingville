# macOS Tiling Window Manager Design

**Date:** 2025-12-13
**Author:** mrdavidlaing
**Status:** Design
**Related:** [Dotfiles and Devcontainer Separation Design](2025-12-13-dotfiles-devcontainer-separation-design.md)

## Problem

Omarchy Linux provides an excellent tiling window manager experience with Hyprland. Moving between Omarchy and macOS creates workflow friction due to different window management paradigms:

- **Omarchy:** Keyboard-driven tiling with Hyprland, workspace management, move windows between monitors
- **macOS:** Traditional floating windows, limited keyboard navigation, no built-in tiling

## Goal

Replicate Omarchy's keyboard-driven tiling window management experience on macOS to maintain consistent workflow across platforms.

## Solution: AeroSpace + Sketchybar Stack

Based on research and community recommendations, the macOS equivalent of Omarchy's Hyprland setup is:

| Omarchy (Linux) | macOS Equivalent | Purpose |
|-----------------|------------------|---------|
| Hyprland | **AeroSpace** | Tiling window manager |
| Waybar | **Sketchybar** | Status bar replacement |
| (built-in) | **JankyBorders** | Visual borders for active window |
| (built-in) | **Karabiner-Elements** | HYPER key (Caps Lock → Super) |

## Why AeroSpace Over Yabai?

**AeroSpace advantages:**
- Works without disabling System Integrity Protection (SIP)
- i3-inspired configuration (similar to Hyprland's approach)
- Great multi-monitor support with workspace movement
- Declarative config
- "Closest thing to Hyprland on Mac" per community feedback

**Yabai drawbacks:**
- Requires disabling SIP for full functionality
- Users report "fighting against SIP and macOS updates"
- More complex to maintain across macOS versions

## Architecture

### AeroSpace (Window Manager)

**What it does:**
- i3-like tiling window manager for macOS
- Uses virtual "workspaces" (not the same as macOS Spaces/Desktops)
- Keyboard-driven window placement and navigation
- Multi-monitor workspace movement

**Key features:**
- No SIP disabling required
- Windows positioned slightly out of view (you see a sliver at viewport edge)
- Solves macOS window management limitations without fighting the OS

**Configuration:**
- Declarative config file (similar to i3/Hyprland)
- Organize workspaces by function (browser, design, code, mail, music, etc.)
- Keyboard shortcuts like `cmd + [1-9]` for workspace switching
- Directional keys for window focus

### Sketchybar (Status Bar)

**What it does:**
- Customizable status bar replacement for macOS menu bar
- Displays workspace indicators, system info, custom widgets

**Integration with AeroSpace:**
- Shows current workspace
- Indicates which workspaces have windows
- Can be configured to match Omarchy's waybar appearance

**Challenges:**
- Lives at top of each screen but macOS doesn't reserve space
- Need different gap settings for different displays:
  - MacBook: 10px (for the notch)
  - External displays: 50px (to prevent window overlap)

### JankyBorders (Visual Feedback)

**What it does:**
- Draws visible borders around the active window
- Makes it clear which window has focus

**Why needed:**
- In tiling mode, windows are edge-to-edge
- Visual indicator helps track focus during keyboard navigation

### Karabiner-Elements (Keyboard Customization)

**What it does:**
- Powerful keyboard remapping for macOS
- Primary use: Create HYPER key from Caps Lock

**HYPER key:**
- Caps Lock → Shift + Control + Command + Option simultaneously
- Provides a dedicated modifier key for window management shortcuts
- Prevents conflicts with application shortcuts

## Configuration Strategy

### Phase 1: Core Setup (Minimal Viable Experience)

1. **Install AeroSpace**
   ```bash
   brew install --cask aerospace
   ```

2. **Install Karabiner-Elements**
   ```bash
   brew install --cask karabiner-elements
   ```
   Configure Caps Lock → HYPER key

3. **Basic AeroSpace Config**
   - Define 9 workspaces by function
   - Set up basic keybindings (HYPER + number for workspaces, HYPER + hjkl for navigation)
   - Configure tiling behavior

4. **Test and iterate**
   - Use for daily work
   - Adjust keybindings to match Hyprland muscle memory
   - Tune tiling behavior

### Phase 2: Visual Polish

1. **Install JankyBorders**
   ```bash
   brew install jankyborders
   ```
   Configure border colors/thickness

2. **Install Sketchybar**
   ```bash
   brew install sketchybar
   ```
   Basic config showing workspaces

3. **Refinement**
   - Match Omarchy's color scheme
   - Add custom widgets as needed

## Reference Implementation

[Eddie Dale's "My mac tiling setup inspired by Omarchy"](https://www.eddiedale.com/blog/my-mac-tiling-setup-inspired-by-omarchy) provides a complete working example:

- 9 workspaces organized by function
- Keyboard-driven workflow (minimal mouse use)
- Configs available on GitHub
- Focus on AeroSpace as the core component

## Dotfiles Integration

### packages.yaml

```yaml
macos:
  cask:
    - aerospace
    - karabiner-elements
  homebrew:
    - sketchybar
    - jankyborders
```

### symlinks.yaml

```yaml
macos:
  # AeroSpace config
  - source: .config/aerospace/aerospace.toml
    target: ~/.config/aerospace/aerospace.toml

  # Karabiner config
  - source: .config/karabiner/karabiner.json
    target: ~/.config/karabiner/karabiner.json

  # Sketchybar config (optional - Phase 2)
  - source: .config/sketchybar
    target: ~/.config/sketchybar
```

### Config Files to Create

1. **`.config/aerospace/aerospace.toml`**
   - Workspace definitions (1-9)
   - Keybindings (match Hyprland as much as possible)
   - Window placement rules
   - Multi-monitor behavior

2. **`.config/karabiner/karabiner.json`**
   - Caps Lock → HYPER key mapping
   - Any other custom key mappings

3. **`.config/sketchybar/` (Phase 2)**
   - Workspace indicators
   - System stats
   - Theme matching Omarchy

## Implementation Approach

### Incremental Adoption

**Don't try to replicate everything at once:**

1. Start with AeroSpace + HYPER key only
2. Use for 1-2 weeks, tune keybindings
3. Add JankyBorders when missing visual feedback
4. Add Sketchybar only if needed (macOS menu bar might be sufficient)

**Key principle:** Match Hyprland's *workflow* (keyboard-driven, workspace-based), not necessarily its exact appearance.

### Keybinding Strategy

**Map to Hyprland muscle memory:**

| Action | Hyprland | AeroSpace (proposed) |
|--------|----------|----------------------|
| Switch workspace | Super + [1-9] | HYPER + [1-9] |
| Move window to workspace | Super + Shift + [1-9] | HYPER + Shift + [1-9] |
| Focus window | Super + hjkl | HYPER + hjkl |
| Move window | Super + Shift + hjkl | HYPER + Shift + hjkl |
| Toggle fullscreen | Super + f | HYPER + f |

**Note:** "Super" on Omarchy is the Windows/Meta key. "HYPER" on macOS is Caps Lock remapped.

## Success Criteria

1. **Keyboard workflow** - Can navigate workspaces and manage windows without mouse
2. **Multi-monitor** - Can move windows/workspaces between displays
3. **Muscle memory** - Hyprland keybindings work on macOS (via HYPER key)
4. **Stability** - Works reliably across macOS updates (no SIP issues)
5. **Integration** - Doesn't break macOS native apps or workflows

## Deferred Features

These can be added later if needed:

- **Advanced Sketchybar widgets** - Start simple, add complexity as needed
- **Custom window rules** - Add as you discover patterns
- **Theming** - Function over form initially
- **Automation** - Add scripting/automation once core workflow is stable

## Resources

- [AeroSpace GitHub](https://github.com/nikitabobko/AeroSpace)
- [AeroSpace Guide](https://nikitabobko.github.io/AeroSpace/guide)
- [AeroSpace + Sketchybar Setup Guide](https://zackreed.me/posts/aerospace_and_sketchybar_setup_on_macos/)
- [Eddie Dale's Omarchy-inspired macOS setup](https://www.eddiedale.com/blog/my-mac-tiling-setup-inspired-by-omarchy)
- [Sketchybar + AeroSpace Integration](https://github.com/FelixKratz/SketchyBar/discussions/598)

## Next Steps

1. Review this design
2. Install AeroSpace and Karabiner-Elements
3. Create basic AeroSpace config matching Hyprland workflow
4. Use for 1-2 weeks, iterate on config
5. Add visual polish (JankyBorders, Sketchybar) as needed
6. Document final configs in dotfiles repo
