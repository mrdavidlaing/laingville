# CLAUDE.md - Lazygit Configuration

This file explains the rationale behind the lazygit configuration for mrdavidlaing and how it's implemented to optimize monitoring AI assistant changes in a WezTerm/tmux environment.

## Configuration Philosophy

The lazygit configuration is designed around the primary use case of **monitoring AI assistant changes** while maintaining the ability to quickly "jump in" and make edits or corrections. This workflow assumes:

1. **Real-time monitoring**: You want to see changes as they happen
2. **Quick intervention**: Ability to edit files or adjust commits rapidly
3. **Submodule awareness**: Many repos use submodules extensively
4. **Seamless integration**: Works naturally with existing WezTerm/nvim setup

## Key Design Decisions

### Auto-Refresh Strategy
```yaml
git:
  autoRefresh: true
  refresher:
    refreshInterval: 2  # Refresh every 2 seconds
    fetchInterval: 60   # Fetch from remote every minute
```

**Rationale**: AI assistants can make rapid changes. The 2-second refresh ensures you see changes almost immediately without being too aggressive on system resources.

### Theme Configuration
```yaml
gui:
  theme:
    activeBorderColor:
      - cyan
      - bold
    # ... matches Solarized Dark
```

**Rationale**: Matches your WezTerm Solarized Dark theme for visual consistency. Cyan active borders provide clear focus indication when switching between panes.

### Submodule Priority
```yaml
git:
  submodules:
    recurse: true

customCommands:
  - key: 'u'
    context: 'submodules'
    command: 'git submodule update --init --recursive'
```

**Rationale**: Given your extensive submodule usage, submodule support is first-class with recursive operations by default and dedicated update commands.

### Editor Integration
```yaml
os:
  edit: 'nvim {{filename}}'
  editAtLine: 'nvim +{{line}} {{filename}}'
  editAtLineAndWait: 'nvim +{{line}} {{filename}}'

customCommands:
  - key: 'e'
    context: 'files'
    command: 'nvim {{.SelectedFile.Name}}'
    description: 'Edit file in nvim'
    output: terminal
```

**Rationale**: Seamless nvim integration allows quick edits from lazygit. The `e` key provides immediate access to edit any file, while lazygit's built-in editor settings handle commit messages and interactive operations.

## Custom Commands for AI Workflow

### Quick Staging and Committing
```yaml
customCommands:
  - key: 'S'
    context: 'files'
    command: 'git add -A'
    description: 'Stage all changes'
    
  - key: 'C'
    context: 'files'
    prompts:
      - type: 'input'
        title: 'Commit message:'
        key: 'CommitMessage'
        initialValue: 'AI: '
    command: 'git add -A && git commit -m "{{.Form.CommitMessage}}"'
    description: 'Stage all and commit with message'
```

**Rationale**: AI assistants often make multiple file changes that should be committed together. `S` stages everything, while `C` provides a quick commit flow with "AI: " prefix for tracking AI-generated changes.

### Safe Operations
```yaml
customCommands:
  - key: 'P'
    context: 'status'
    command: 'git push --force-with-lease'
    description: 'Force push with lease'
    
  - key: 'A'
    context: 'commits'
    command: 'git commit --amend --no-edit'
    description: 'Amend last commit (no edit)'
```

**Rationale**: `--force-with-lease` is safer than `--force` when AI assistants might be working on shared branches. Quick amend allows fixing AI commits without opening an editor.

## UI Optimizations

### Layout for Monitoring
```yaml
gui:
  showFileTree: true
  showListFooter: true
  showBranchCommitHash: true
  sidePanelWidth: 0.3333
  expandFocusedSidePanel: false
  mainPanelSplitMode: flexible
```

**Rationale**: File tree view helps understand AI changes across directory structures. Fixed side panel width (33%) ensures consistent layout when monitoring in a split pane.

### Performance Settings
```yaml
gui:
  scrollHeight: 2
  scrollPastBottom: true
  mouseEvents: true
```

**Rationale**: Smooth scrolling for reviewing AI changes. Mouse support allows quick navigation when monitoring from a split pane.

## WezTerm Integration Points

The configuration works with these WezTerm keybindings:

- **`Ctrl+b, g`**: Opens lazygit in new pane for focused work
- **`Ctrl+b, Ctrl+g`**: Opens lazygit in 40% right split for monitoring
- **`Ctrl+b, Shift+G`**: Opens lazygit in new tab for full-screen operation

**Rationale**: Different access methods for different workflows - monitoring (split), focused work (pane), or comprehensive review (tab).

## Nvim Integration Points

The configuration supports the lazygit.nvim plugin with:

- **`<leader>lg`**: Floating lazygit window for quick checks
- **`<leader>lG`**: File-specific lazygit for targeted operations
- **neovim-remote support**: Commit editing stays within nvim session

**Rationale**: Provides multiple access patterns depending on whether you're already in nvim or need to switch contexts.

## Configuration Maintenance

### Location
- Global config: `~/.config/lazygit/config.yml`
- Repo-specific overrides: `<repo>/.git/lazygit.yml` (if needed)
- Parent directory configs: `.lazygit.yml` in parent dirs

### Customization Points
1. **Refresh intervals**: Adjust `refreshInterval` if 2 seconds is too frequent/slow
2. **Theme colors**: Modify theme section to match different colorschemes
3. **Custom commands**: Add repo-specific workflows as needed
4. **Keybindings**: Override any default keys that conflict with muscle memory

### JSON Schema Support
The config includes JSON schema support for VS Code IntelliSense:
```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/jesseduffield/lazygit/master/schema/config.json
```

This enables auto-completion and validation when editing the config file.

## Workflow Examples

### Monitoring AI Assistant Session
1. Start work session with AI assistant in main pane
2. Use `Ctrl+b, Ctrl+g` to open lazygit monitoring in right pane
3. Watch real-time changes every 2 seconds
4. Press `e` on any file to quickly edit in nvim
5. Use `C` to commit AI changes with descriptive messages
6. Use `u` to update submodules after AI modifications

### Quick Review and Fixes
1. Use `<leader>lg` from nvim for floating lazygit
2. Review AI changes in main panel
3. Press `D` to view detailed diffs in nvim
4. Use `A` to amend commits or `C` to create new ones
5. Press `P` to safely push changes

This configuration balances monitoring capabilities with intervention speed, making it ideal for AI-assisted development workflows.