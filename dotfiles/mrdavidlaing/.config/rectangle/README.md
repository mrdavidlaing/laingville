# Rectangle Configuration

This directory contains Rectangle window manager configurations for macOS.

## Files

- `com.knollsoft.Rectangle.plist` - Current active configuration (symlinked to system preferences)
- `RectangleConfig.json` - Exported JSON of current configuration  
- `RectangleConfig-windows-like.json` - Windows-like configuration using Command keys
- `windows-like-config.json` - Human-readable shortcut reference

## Current Configuration Analysis

Your current Rectangle setup uses **Control + Option** as the primary modifier combination (modifier flag `786432`).

### Current Shortcuts
- **Basic Window Management**: Control + Option + Arrow keys
- **Quarter Positioning**: Control + Option + hjkl (vim-style)
- **Thirds**: Control + Option + D/F/G  
- **Claude Integration**: Control + Option + B (toggle), Control + Option + N (reflow)

## Windows-Like Alternative 

The `RectangleConfig-windows-like.json` provides a Windows-style experience:

### Primary Shortcuts (⌘ + Arrow)
- `⌘ + Left/Right Arrow` - Snap left/right half (like Win + Left/Right)
- `⌘ + Up Arrow` - Maximize (like Win + Up)
- `⌘ + Down Arrow` - Restore (like Win + Down)

### Text Editor Friendly (⌘ + Option + hjkl)
- `⌘ + Option + H` - Left half (no vim conflict)
- `⌘ + Option + J` - Bottom half (no vim conflict) 
- `⌘ + Option + K` - Top half (no vim conflict)
- `⌘ + Option + L` - Right half (no vim conflict)

### Advanced Features
- `⌘ + Shift + Arrow` - Quarter screen positioning
- `⌘ + Option + Control + Arrow` - Multi-monitor movement
- `⌘ + D/F/G` - Screen thirds

### Preserved Features
- Claude Desktop integration shortcuts remain unchanged
- All snap areas and visual feedback preserved

## Text Editor Compatibility

### Why hjkl with Modifiers is Safe
Using `⌘ + Option + hjkl` avoids conflicts because:
1. **Vim/Neovim** uses bare `hjkl` for navigation
2. **Terminal vim** uses `hjkl` without modifiers
3. **IDE vim modes** typically don't use Command key combinations
4. **tmux** uses its own prefix (typically `Control + B`) before hjkl

### Recommended for Vim Users
The Windows-like config is actually **more** text editor friendly than your current setup because:
- Single modifier (`⌘`) vs dual modifier (`Control + Option`)
- Follows macOS conventions (Command for global actions)
- hjkl shortcuts are clearly separated with different modifier combo

## Switching Configurations

To use the Windows-like configuration:
1. Import `RectangleConfig-windows-like.json` through Rectangle's preferences
2. Or replace the plist file and restart Rectangle
3. Or modify specific shortcuts through Rectangle's GUI

## Benefits of Windows-Like Setup

1. **Familiarity**: Matches Windows muscle memory
2. **Simplicity**: Single modifier vs dual modifier  
3. **Consistency**: Command key for global actions (macOS standard)
4. **Text Editor Safe**: No conflicts with vim/neovim navigation
5. **Arrow Key Logic**: Directional arrows match window placement