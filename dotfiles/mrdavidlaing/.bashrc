# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Source universal shell environment (PATH, EDITOR, etc.)
# This ensures VS Code terminals (non-login interactive shells) get all environment variables
if [[ -f ~/.profile ]]; then
    source ~/.profile
fi

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

# Personal eza aliases (extending Omarchy defaults)
if command -v eza &>/dev/null; then
  alias ll='ls'  # Muscle memory - same as Omarchy's ls
  alias lt3='eza --tree --level=3 --long --icons --git'  # Like Omarchy's lt but level 3
  alias lta3='lt3 -a'  # Like Omarchy's lta but level 3
fi

# Direnv (critical for devcontainer workflow)
command -v direnv &>/dev/null && eval "$(direnv hook bash)"

# Lazygit with 1Password SSH agent
lg() {
  local op_sock=$(ssh -G github.com | awk '/^identityagent / { print $2 }')
  SSH_AUTH_SOCK="${op_sock:-$SSH_AUTH_SOCK}" command lazygit "$@"
}

# oh-my-opencode profile shortcuts
alias omo-free='omo-profile free'
alias omo-value='omo-profile value'
alias omo-perf='omo-profile performance'
