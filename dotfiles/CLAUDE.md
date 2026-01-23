# Dotfiles Package Management

This directory contains user-specific dotfiles and shared configurations managed by the `setup-user` script.

## Package Configuration Structure

Each user has a `packages.yaml` file that defines packages to install across different platforms. The structure includes:

### Package Categories

- **Platform package managers**: `pacman`, `yay`, `homebrew`, `cask`, `winget`, `scoop`, `psmodule`, `nixpkgs-25.05`, `nixpkgs-unstable`
- **Custom scripts**: `custom` - runs bash scripts from `dotfiles/shared/scripts/`
- **Cleanup sections**: `*_cleanup` - removes packages that have been replaced or are no longer needed

### Cleanup Mechanism

The `*_cleanup` sections (e.g., `pacman_cleanup`, `yay_cleanup`, `winget_cleanup`, `cask_cleanup`) allow temporary tracking of packages that need to be uninstalled during the transition period when users are migrating their systems.

**Important**: Once packages have been successfully removed across all target systems, the cleanup entries should be deleted from `packages.yaml`. These are temporary migration helpers, not permanent configuration.

## Package Change History

**Before adding or removing packages**, review git history to understand the context:

```bash
# View package change history with context
git log -p -- dotfiles/*/packages.yaml

# Search for specific package mentions
git log --all --grep="package-name" -- dotfiles/

# See when a package was added/removed
git log -S "package-name" -- dotfiles/*/packages.yaml
```

Git history contains inline comments explaining why packages were removed (with dates and reasons), which packages replaced them, and the rationale for additions.

## Custom Scripts

Custom installation scripts in `dotfiles/shared/scripts/` follow the naming convention:
- `install_*.bash` - Installation scripts (e.g., `install_claude_code.bash`, `install_beads.bash`)
- `configure_*.bash` - Configuration scripts (e.g., `configure_tailscale.bash`)

Scripts receive a dry-run parameter (`true`/`false`) and should:
- Check if already installed before attempting installation
- Log with `[Tool Name]` prefix for clarity
- Support `--dry-run` mode
- Be executable (`chmod +x`)

## Example Package Configuration

```yaml
macos:
  homebrew:
    - git
    - neovim
  cask:
    - wezterm@nightly
  custom:
    - install_claude_code
    - install_beads
  cask_cleanup:  # Temporary - remove once uninstalled everywhere
    - old-terminal-app  # Removed YYYY-MM-DD, reason for removal
```
