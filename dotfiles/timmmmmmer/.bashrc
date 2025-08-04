# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Add ~/.local/bin to PATH (if not already in PATH)
export PATH="$HOME/.local/bin:$PATH"

# Load 1Password environment secrets if available
[ -f "$HOME/.config/env.secrets.local" ] && source "$HOME/.config/env.secrets.local"

eval "$(zoxide init bash)"
#eval "$(starship init bash)"
