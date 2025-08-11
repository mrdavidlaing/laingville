# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias vim='nvim'
alias vi='nvim'
PS1='[\u@\h \W]\$ '

# Add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Set default editor
export EDITOR=nvim

# Load 1Password environment secrets if available
[ -f "$HOME/.config/env.secrets.local" ] && source "$HOME/.config/env.secrets.local"

eval "$(starship init bash)"
eval "$(zoxide init bash)"

# WSL-specific configuration
if grep -qi microsoft /proc/version 2>/dev/null; then
    # 1Password SSH Agent integration for WSL
    # Uses Windows ssh.exe to access 1Password agent
    if command -v ssh.exe &> /dev/null && command -v ssh-add.exe &> /dev/null; then
        alias ssh='ssh.exe'
        alias ssh-add='ssh-add.exe'
        # Configure Git to use Windows SSH for 1Password agent
        export GIT_SSH_COMMAND="ssh.exe"
    else
        echo "Warning: ssh.exe not found. 1Password SSH agent forwarding unavailable." >&2
        echo "Ensure Windows OpenSSH is installed and in PATH." >&2
    fi
fi
