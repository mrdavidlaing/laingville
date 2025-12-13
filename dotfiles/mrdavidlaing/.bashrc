# ~/.bashrc

# If not running interactively, don't do anything
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

# Additional eza aliases (extending Omarchy defaults)
if command -v eza &>/dev/null; then
  alias ll='eza -la --icons --group-directories-first'
  alias la='eza -a --icons'
  alias lt3='eza --tree --icons --level=3'
  alias lm='eza -la --icons --sort=modified'
  alias lsize='eza -la --icons --sort=size'
fi

# Direnv (critical for devcontainer workflow)
command -v direnv &>/dev/null && eval "$(direnv hook bash)"

# Lazygit with 1Password SSH agent
lg() {
  local op_sock=$(ssh -G github.com | awk '/^identityagent / { print $2 }')
  SSH_AUTH_SOCK="${op_sock:-$SSH_AUTH_SOCK}" command lazygit "$@"
}
