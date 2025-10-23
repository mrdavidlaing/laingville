# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Source profile for environment setup (PATH, etc.)
# This ensures non-login interactive shells get the same environment as login shells
if [[ -f ~/.profile ]]; then
    source ~/.profile
fi

# Enhanced directory listings (prefer eza when available)
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -la --icons --group-directories-first'
  alias la='eza -a --icons'
  alias lzg='eza -la --icons --git'
  alias lt='eza --tree --icons --level=2'
  alias lt3='eza --tree --icons --level=3'
  alias lm='eza -la --icons --sort=modified'
  alias lsize='eza -la --icons --sort=size'
else
  echo "Warning: eza not found; enhanced ls aliases disabled. Install it with 'scoop install eza'." >&2
fi

lg() {
  local op_sock=$(ssh -G github.com | awk '/^identityagent / { print $2 }')
  SSH_AUTH_SOCK="${op_sock:-$SSH_AUTH_SOCK}" command lazygit "$@"
}

# Ensure Windows tree.com is available in Git Bash
if ! command -v tree >/dev/null 2>&1 && [ -x /c/Windows/System32/tree.com ]; then
  alias tree='/c/Windows/System32/tree.com'
fi

# Sort variations for development workflows
alias grep='grep --color=auto'
alias vim='nvim'
alias vi='nvim'
alias cd='z'
PS1='[\u@\h \W]\$ '

# WSL-specific interactive configuration
if grep -qi microsoft /proc/version 2>/dev/null; then
    # 1Password SSH Agent integration for WSL (interactive aliases)
    # Note: GIT_SSH_COMMAND is set in ~/.profile for script compatibility
    if command -v ssh.exe &> /dev/null && command -v ssh-add.exe &> /dev/null; then
        alias ssh='ssh.exe'
        alias ssh-add='ssh-add.exe'
    else
        echo "Warning: ssh.exe not found. 1Password SSH agent forwarding unavailable." >&2
        echo "Ensure Windows OpenSSH is installed and in PATH." >&2
    fi
fi

# Git Learning Integration
if [[ -f ~/.config/tmux/git-learning/git-hints.sh ]]; then
    # Make git learning functions available
    source ~/.bashrc_git_learning 2>/dev/null
fi

# Interactive tool initialization (must be at the end)
# These tools provide enhanced interactive shell experience and need to be
# initialized after all other shell configuration is complete
eval "$(starship init bash)"
eval "$(zoxide init bash)"
eval "$(direnv hook bash)"
