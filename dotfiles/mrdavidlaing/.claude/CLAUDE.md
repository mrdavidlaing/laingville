# CLAUDE.md

This directory contains user-level Claude Code configuration for mrdavidlaing.

## Files

- `settings.json` - User settings (symlinked to ~/.claude/settings.json)
- `commands/` - Custom slash commands (symlinked to ~/.claude/commands)
- `scripts/` - Helper scripts like the bash-direnv-wrapper

## Scripts

### claude-code-bash-direnv-wrapper.bash
A PreToolUse hook for the Bash tool that automatically allows direnv for directories with `.envrc` files before Claude Code runs commands. 

How it works:
1. Claude Code passes JSON with the working directory to the hook via stdin
2. The hook checks if the working directory (or a parent) has an `.envrc` file
3. If found, it runs `direnv allow` for that directory
4. Claude Code then executes the bash command with direnv automatically loading the environment

This ensures that:
- Projects with `.envrc` files have their environments properly loaded
- Nix flakes work via direnv's `use flake` directive  
- Environment variables and shell functions are available as expected
- No manual `direnv allow` is needed when Claude Code enters a new project

To debug the wrapper, set `export CLAUDE_CODE_DIRENV_DEBUG=1` in your shell before starting Claude Code.

## Wrappers

### git
A wrapper for the git command that ensures direnv environments are loaded for git operations. This is particularly important for git commits with pre-commit hooks that need tools from the nix environment (like terraform, tflint, etc.).

How it works:
1. Intercepts git commands via PATH override in Claude settings
2. Checks if current directory has an `.envrc` file
3. If found, runs: `direnv exec <dir> /usr/bin/git <args>`
4. If not found, passes through to regular git

This solves the problem where git pre-commit hooks fail because they can't find tools installed via nix/direnv.

## Notes

The `feedbackSurveyState` field that appears in ~/.claude/settings.json is internal Claude Code state that gets auto-generated. We don't include it in version control as it's not part of the official schema and will be recreated automatically.

## Current Configuration

- **Model**: sonnet[1m]
- **PATH Override**: Prepends `~/.claude/wrappers` to PATH for custom command wrappers
- **PreToolUse Hook**: Bash commands run through direnv-wrapper to auto-allow direnv environments
- **Symlink Locations**:
  - `settings.json` → `~/.claude/settings.json`
  - `commands/` → `~/.claude/commands`
  - `wrappers/` → `~/.claude/wrappers`
  - `scripts/claude-code-bash-direnv-wrapper.bash` → `~/.local/bin/claude-code-bash-direnv-wrapper`