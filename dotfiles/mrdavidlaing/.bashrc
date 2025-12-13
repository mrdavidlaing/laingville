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

# Direnv (critical for devcontainer workflow)
command -v direnv &>/dev/null && eval "$(direnv hook bash)"

# Lazygit with 1Password SSH agent
lg() {
  local op_sock=$(ssh -G github.com | awk '/^identityagent / { print $2 }')
  SSH_AUTH_SOCK="${op_sock:-$SSH_AUTH_SOCK}" command lazygit "$@"
}
