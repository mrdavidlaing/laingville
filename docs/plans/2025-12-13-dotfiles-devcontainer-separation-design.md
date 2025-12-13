# Dotfiles and Devcontainer Separation Design

**Date:** 2025-12-13
**Author:** mrdavidlaing
**Status:** Design

## Problem

The current dotfiles mix "computer UX" configuration (window manager, terminal, shell experience) with "project development" tools (language servers, build tools, project CLI tools). This creates several problems:

1. **Inconsistent environments** - Development tools installed on host may differ from CI/production environments
2. **Cluttered host system** - Every project's tools installed globally, even when not needed
3. **Poor agent isolation** - Implementing agents need full dev tooling, but run in containers separate from host tools
4. **Omarchy defaults ignored** - Omarchy Linux provides excellent UX defaults, but dotfiles override everything instead of extending selectively

## Solution

Separate computer UX from project development by establishing clear boundaries:

**Host (dotfiles):**
- Window management and desktop environment
- Terminal emulator and shell experience
- Orchestrating agent with full personal configuration
- Swiss army knife tools (gh, jq, ripgrep, fd, fzf)

**Devcontainer (per-project):**
- Language servers
- Build tools and runtimes
- Project-specific CLI tools
- Implementing agents with minimal configuration

**Philosophy:** Omarchy becomes the reference UX. Other platforms (macOS, WSL) adopt Omarchy's defaults through a portable compatibility layer, then add personal customizations on top.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         HOST MACHINE                             │
├─────────────────────────────────────────────────────────────────┤
│  Computer UX (laingville dotfiles)                              │
│  ├── Platform defaults: Omarchy provides hyprland, ghostty,     │
│  │   neovim, lazygit, starship                                  │
│  ├── Personal overrides: Hyprland input/bindings, shell         │
│  │   functions (lg, direnv), API keys                           │
│  └── Mac/WSL: Use omarchy-compat for same UX as Omarchy         │
│                                                                  │
│  Orchestrator (Claude Code)                                     │
│  ├── Full config: commands, settings, API keys                  │
│  └── Spawns implementing agents in devcontainers                │
│                                                                  │
│  Swiss Army Knife (host AND devcontainers)                      │
│  └── gh, jq, ripgrep, fd, fzf                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PROJECT DEVCONTAINERS                         │
├─────────────────────────────────────────────────────────────────┤
│  Defined per-project (flake.nix / devcontainer.json)            │
│  ├── Language servers (gopls, terraform-ls, lua-ls)             │
│  ├── Build tools (go, nodejs, bun, yarn, pnpm)                  │
│  ├── Project CLI (kubectl, k9s, shellspec, shfmt)               │
│  ├── Swiss army knife (gh, jq, ripgrep, fd, fzf)                │
│  └── Implementing agent (API key via env var)                   │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
dotfiles/
├── shared/
│   └── omarchy-compat/              # Portable Omarchy defaults
│       ├── shell/
│       │   ├── rc                   # Entry point - sources others
│       │   ├── aliases.bash         # eza, zoxide, git shortcuts
│       │   ├── functions.bash       # n, open, etc.
│       │   └── init.bash            # starship, zoxide, fzf init
│       ├── ghostty/
│       │   └── config               # Omarchy ghostty defaults
│       ├── lazygit/
│       │   └── config.yml           # Omarchy lazygit defaults
│       └── starship.toml            # Omarchy prompt config
│
└── mrdavidlaing/
    ├── packages.yaml                # Platform-specific packages
    ├── symlinks.yaml                # Platform-specific symlinks
    │
    ├── .bashrc                      # Sources omarchy defaults + personal
    ├── .profile                     # PATH and script-critical env vars
    ├── .gitconfig                   # Personal git identity
    ├── .gitmessage
    │
    ├── .config/
    │   ├── hypr/                    # Omarchy overrides (Omarchy only)
    │   │   ├── input.conf
    │   │   ├── bindings.conf
    │   │   ├── monitors.conf
    │   │   ├── looknfeel.conf
    │   │   └── autostart.conf
    │   ├── ghostty/
    │   │   └── config               # Omarchy overrides
    │   ├── lazygit/
    │   │   └── config.yml           # Personal overrides
    │   ├── nvim/
    │   │   └── lua/plugins/         # LazyVim extensions
    │   ├── starship.toml
    │   └── wezterm/                 # Fallback terminal
    │
    ├── .claude/                     # Orchestrator config
    │   ├── commands/
    │   ├── settings.template.json
    │   └── scripts/
    │
    └── .local/bin/                  # Personal scripts
        ├── git-identity
        └── fetch-api-key
```

## Platform-Specific Packages

### Omarchy

Omarchy provides almost everything. Install only extras:

```yaml
omarchy:
  yay:
    - 1password-cli
    - direnv
  custom:
    - install_claude_code
    - install_happy_cli
    - install_beads
    - configure_tailscale
```

### macOS

Omarchy-like shell experience plus native apps:

```yaml
macos:
  homebrew:
    # Shell experience (omarchy-compat needs these)
    - eza
    - zoxide
    - starship
    - fzf
    - direnv
    # Swiss army knife
    - gh
    - jq
    - ripgrep
    - fd
    # Git UX
    - lazygit
    - git
    - git-lfs
  cask:
    - ghostty
  custom:
    - install_claude_code
    - install_happy_cli
    - install_beads
    - configure_tailscale
```

### WSL

Terminal-focused, no GUI packages:

```yaml
wsl:
  pacman:
    # Shell experience
    - eza
    - zoxide
    - starship
    - fzf
    - direnv
    # Swiss army knife
    - gh
    - jq
    - ripgrep
    - fd
    # Git UX + editor
    - lazygit
    - git
    - git-lfs
    - neovim
  custom:
    - install_claude_code
    - install_happy_cli
    - install_beads
    - configure_tailscale
```

### Windows

Keep existing wezterm setup:

```yaml
windows:
  winget:
    - Mozilla.Firefox
    - Microsoft.PowerToys
    - Tailscale.Tailscale
  scoop:
    - versions/wezterm-nightly
    - lazygit
    - git-lfs
    - direnv
  custom:
    - install_claude_code_windows
    - install_beads
    - configure_tailscale_windows
```

## Shell Configuration

### .bashrc

Single file with platform detection, symlinked across all platforms:

```bash
# dotfiles/mrdavidlaing/.bashrc

[[ $- != *i* ]] && return

# Source omarchy defaults (real or compat based on platform)
if [ -f ~/.local/share/omarchy/default/bash/rc ]; then
  # Real Omarchy
  source ~/.local/share/omarchy/default/bash/rc
elif [ -f ~/.local/share/omarchy-compat/shell/rc ]; then
  # Mac/WSL with omarchy-compat
  source ~/.local/share/omarchy-compat/shell/rc
fi

# === Personal customizations (interactive-only) ===

# Terminal color support
[ -z "$COLORTERM" ] && export COLORTERM=truecolor

# Direnv (critical for devcontainer workflow)
command -v direnv &>/dev/null && eval "$(direnv hook bash)"

# Lazygit with 1Password SSH agent
lg() {
  local op_sock=$(ssh -G github.com | awk '/^identityagent / { print $2 }')
  SSH_AUTH_SOCK="${op_sock:-$SSH_AUTH_SOCK}" command lazygit "$@"
}
```

### .profile

Script-critical environment variables only:

```bash
# dotfiles/mrdavidlaing/.profile

# PATH additions (platform-detected)
export PATH="$HOME/.local/bin:$PATH"

[ -d "$HOME/.nix-profile/bin" ] && export PATH="$HOME/.nix-profile/bin:$PATH"
[ -d "$HOME/.cargo/bin" ] && export PATH="$HOME/.cargo/bin:$PATH"
[ -d "$HOME/scoop/shims" ] && export PATH="$HOME/scoop/shims:$PATH"
[ -f "/opt/homebrew/bin/brew" ] && eval "$(/opt/homebrew/bin/brew shellenv)"

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Editor (needed by git, scripts)
export EDITOR=nvim

# Personal environment
export HAPPY_SERVER_URL="https://baljeet-tailnet.cyprus-macaroni.ts.net"
[ -f "$HOME/.config/env.secrets.local" ] && . "$HOME/.config/env.secrets.local"

# WSL-specific (script-critical)
if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
  command -v ssh.exe >/dev/null 2>&1 && export GIT_SSH_COMMAND="ssh.exe"
  command -v wslview >/dev/null 2>&1 && export BROWSER=wslview
fi
```

### Why This Split?

**Interactive check `[[ $- != *i* ]] && return`** exits .bashrc early for non-interactive contexts (scripts, rsync, ssh commands). This prevents aliases and prompts from breaking automation.

**.profile** runs for all shells (interactive and scripts), so it contains only variables that scripts need: PATH, EDITOR, GIT_SSH_COMMAND, API keys.

**.bashrc** runs only for interactive shells, so it contains aliases, functions, prompts, and terminal-specific settings.

## Symlinks

### Omarchy

```yaml
omarchy:
  # Shell (sources real Omarchy defaults)
  - .bashrc
  - .profile

  # Git identity
  - .gitconfig
  - .gitmessage

  # Hyprland overrides only
  - .config/hypr/input.conf
  - .config/hypr/bindings.conf
  - .config/hypr/monitors.conf
  - .config/hypr/looknfeel.conf
  - .config/hypr/autostart.conf

  # Tool overrides
  - .config/ghostty/config
  - .config/lazygit/config.yml
  - .config/starship.toml
  - .config/nvim/lua/plugins/

  # Claude Code orchestrator
  - source: .claude/CLAUDE.md
    target: ~/.claude/CLAUDE.md
  - source: .claude/commands
    target: ~/.claude/commands
  - source: .claude/scripts/claude-code-bash-direnv-wrapper.bash
    target: ~/.local/bin/claude-code-bash-direnv-wrapper
  - source: .claude/wrappers
    target: ~/.claude/wrappers

  # Personal scripts
  - source: .local/bin/git-identity
    target: ~/.local/bin/git-identity
  - source: .local/bin/fetch-api-key
    target: ~/.local/bin/fetch-api-key
```

### macOS

```yaml
macos:
  # Shell (sources omarchy-compat)
  - .bashrc
  - .profile
  - source: shared/omarchy-compat/shell
    target: ~/.local/share/omarchy-compat/shell

  # Git identity
  - .gitconfig
  - .gitmessage

  # Tool configs (from omarchy-compat)
  - source: shared/omarchy-compat/starship.toml
    target: ~/.config/starship.toml
  - source: shared/omarchy-compat/ghostty/config
    target: ~/.config/ghostty/config
  - source: shared/omarchy-compat/lazygit/config.yml
    target: ~/.config/lazygit/config.yml
  - .config/wezterm

  # Claude Code orchestrator
  - source: .claude/CLAUDE.md
    target: ~/.claude/CLAUDE.md
  - source: .claude/commands
    target: ~/.claude/commands
  - source: .claude/scripts/claude-code-bash-direnv-wrapper.bash
    target: ~/.local/bin/claude-code-bash-direnv-wrapper
  - source: .claude/wrappers
    target: ~/.claude/wrappers

  # Personal scripts
  - source: .local/bin/git-identity
    target: ~/.local/bin/git-identity
  - source: .local/bin/fetch-api-key
    target: ~/.local/bin/fetch-api-key
```

### WSL

```yaml
wsl:
  # Shell (sources omarchy-compat)
  - .bashrc
  - .profile
  - source: shared/omarchy-compat/shell
    target: ~/.local/share/omarchy-compat/shell

  # Git identity
  - .gitconfig
  - .gitmessage

  # Tool configs
  - source: shared/omarchy-compat/starship.toml
    target: ~/.config/starship.toml
  - source: shared/omarchy-compat/lazygit/config.yml
    target: ~/.config/lazygit/config.yml
  - source: shared/omarchy-compat/nvim
    target: ~/.config/nvim

  # Claude Code orchestrator
  - source: .claude/CLAUDE.md
    target: ~/.claude/CLAUDE.md
  - source: .claude/commands
    target: ~/.claude/commands
  - source: .claude/scripts/claude-code-bash-direnv-wrapper.bash
    target: ~/.local/bin/claude-code-bash-direnv-wrapper
  - source: .claude/wrappers
    target: ~/.claude/wrappers

  # Personal scripts
  - source: .local/bin/git-identity
    target: ~/.local/bin/git-identity
  - source: .local/bin/fetch-api-key
    target: ~/.local/bin/fetch-api-key
```

## Migration Strategy

### Phase 1: Prepare

Create new files in dotfiles repo without changing live systems:

1. `shared/omarchy-compat/shell/rc` and related files
2. `shared/omarchy-compat/starship.toml`
3. `shared/omarchy-compat/lazygit/config.yml`
4. `shared/omarchy-compat/ghostty/config`
5. Updated `.bashrc` with platform detection
6. Updated `.profile` with script-critical vars only
7. New `omarchy` platform in `packages.yaml` and `symlinks.yaml`
8. Trimmed `macos` platform (remove dev tools)

### Phase 2: Omarchy (this machine)

**Risk:** Low - new platform, no existing config to break

**Steps:**
1. `./setup-user --dry-run` - verify changes
2. Backup: `cp ~/.bashrc ~/.bashrc.backup`
3. `./setup-user`
4. Open new terminal, verify shell works
5. Verify Hyprland works (overrides are additive)

**Rollback:** Restore `~/.bashrc.backup` and run previous setup-user

### Phase 3: macOS

**Risk:** Medium - removes dev tools, adds omarchy-compat

**Steps:**
1. `./setup-user --dry-run`
2. Backup: `cp ~/.bashrc ~/.bashrc.backup`
3. `./setup-user`
4. Install ghostty: `brew install --cask ghostty`
5. Test shell and terminals

**Expected:** Dev tools removed from host (language servers, build tools). Use devcontainers for development work.

**Rollback:** Restore backup and reinstall dev tools via homebrew

### Phase 4: Baljeet (deferred)

**Decision point:** After validating Omarchy and macOS

**Options:**
- **A:** Use omarchy-compat for consistent UX
- **B:** Keep simpler config for server administration

Defer decision until Omarchy/macOS patterns validated.

### Phase 5: WSL/Windows (deferred)

Lower priority. Migrate when confident in the pattern.

## Implementation Checklist

- [ ] Create `shared/omarchy-compat/shell/` directory structure
- [ ] Port Omarchy's bash defaults to omarchy-compat (aliases, functions, init)
- [ ] Create `shared/omarchy-compat/starship.toml`
- [ ] Create `shared/omarchy-compat/lazygit/config.yml`
- [ ] Create `shared/omarchy-compat/ghostty/config`
- [ ] Update `.bashrc` with platform detection
- [ ] Update `.profile` with script-critical split
- [ ] Add `omarchy` platform to `packages.yaml`
- [ ] Add `omarchy` platform to `symlinks.yaml`
- [ ] Update `macos` platform in `packages.yaml` (remove dev tools)
- [ ] Update `macos` platform in `symlinks.yaml` (add omarchy-compat)
- [ ] Add platform detection to `setup-user` script
- [ ] Test on Omarchy
- [ ] Test on macOS
- [ ] Document baljeet decision
- [ ] Migrate WSL/Windows (future)

## Future Enhancements

### macOS Tiling Window Manager

Add Omarchy-like tiling to macOS using:
- **AeroSpace** - i3-like tiling window manager (no SIP disabling needed)
- **Sketchybar** - Status bar replacement
- **JankyBorders** - Active window borders
- **Karabiner-Elements** - HYPER key (Caps Lock → Super)

Reference: [My mac tiling setup inspired by Omarchy](https://www.eddiedale.com/blog/my-mac-tiling-setup-inspired-by-omarchy)

**Decision:** Defer until core separation validated. Add as enhancement when desired.

## Success Criteria

1. **Omarchy** - Shell experience works, Hyprland customizations apply, no dev tools installed
2. **macOS** - Shell feels like Omarchy, ghostty works, dev tools removed
3. **Devcontainers** - Projects have all needed tools, implementing agents work with API keys
4. **Git tracking** - All config changes tracked in dotfiles repo
5. **Rollback** - Can restore previous setup from backups if needed

## References

- [Omarchy Linux](https://learn.omacom.io/2/the-omarchy-manual)
- [AeroSpace Tiling WM](https://github.com/nikitabobko/AeroSpace)
- [Ghostty Terminal](https://ghostty.org/)
- [My mac tiling setup inspired by Omarchy](https://www.eddiedale.com/blog/my-mac-tiling-setup-inspired-by-omarchy)
