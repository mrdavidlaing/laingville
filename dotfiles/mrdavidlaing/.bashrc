# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Add ~/.local/bin to PATH
export PATH="$HOME/.local/bin:$PATH"

eval "$(zoxide init bash)"
eval "$(starship init bash)"
