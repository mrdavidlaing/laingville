#!/bin/bash

# Git Learning Assistant for Tmux Popups
# Provides contextual Git alias hints based on current repository status

show_contextual_hints() {
  clear

  # Beautiful header using your ==> style
  echo -e "\033[1;36m==> Git Learning Assistant\033[0m"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo

  # Analyze current Git context
  if git rev-parse --git-dir > /dev/null 2>&1; then
    analyze_git_context
    echo
    show_essential_aliases
  else
    echo -e "\033[0;33m📁 Not in a Git repository\033[0m"
    echo
    show_basic_git_setup
    echo
    show_essential_aliases
  fi

  echo
  echo -e "\033[2;37m💡 Press 'q' to quit, 'p' for practice mode, or Enter to continue...\033[0m"

  read -n 1 response
  case $response in
    p | P) start_practice_mode ;;
    q | Q) exit 0 ;;
    *) ;;
  esac
}

analyze_git_context() {
  local status_output=$(git status --porcelain 2> /dev/null)
  local branch=$(git branch --show-current 2> /dev/null)
  local ahead_behind=$(git status -b --porcelain 2> /dev/null | head -1)

  echo -e "\033[1;32m📍 Current: \033[0;32m$branch\033[0m"

  # Check for ahead/behind status
  if echo "$ahead_behind" | grep -q "ahead"; then
    echo -e "\033[0;33m   ↑ Branch is ahead - ready to push\033[0m"
    echo -e "     \033[1;35mp\033[0m   → git push                        \033[2;37m(share your changes)\033[0m"
  elif echo "$ahead_behind" | grep -q "behind"; then
    echo -e "\033[0;31m   ↓ Branch is behind - should pull\033[0m"
    echo -e "     \033[1;35mpl\033[0m  → git pull                        \033[2;37m(get latest changes)\033[0m"
  fi

  echo

  if [[ -z "$status_output" ]]; then
    echo -e "\033[0;36m✨ Clean working directory\033[0m"
    echo
    echo -e "\033[1;33m🎯 Suggested next actions:\033[0m"
    echo -e "  \033[1;35ml\033[0m   → git log --oneline --graph -10    \033[2;37m(recent history)\033[0m"
    echo -e "  \033[1;35mb\033[0m   → git branch -v                     \033[2;37m(list branches)\033[0m"
    echo -e "  \033[1;35mco\033[0m  → git checkout <branch>             \033[2;37m(switch branch)\033[0m"
    echo -e "  \033[1;35msw\033[0m  → git switch <branch>               \033[2;37m(modern branch switch)\033[0m"
  else
    echo -e "\033[1;33m⚡ Changes detected:\033[0m"

    if echo "$status_output" | grep -q "^??"; then
      echo -e "  \033[0;31m?? Untracked files present\033[0m"
      echo -e "     \033[1;35ma\033[0m   → git add <file>               \033[2;37m(stage specific file)\033[0m"
      echo -e "     \033[1;35maa\033[0m  → git add --all                \033[2;37m(stage everything)\033[0m"
    fi

    if echo "$status_output" | grep -q "^[AM]"; then
      echo -e "  \033[0;32mStaged changes ready\033[0m"
      echo -e "     \033[1;35mc\033[0m   → git commit                   \033[2;37m(commit with editor)\033[0m"
      echo -e "     \033[1;35mcm\033[0m  → git commit -m \"message\"      \033[2;37m(quick commit)\033[0m"
    fi

    if echo "$status_output" | grep -q "^ M"; then
      echo -e "  \033[0;33mModified files (unstaged)\033[0m"
      echo -e "     \033[1;35ms\033[0m   → git status --short --branch   \033[2;37m(detailed view)\033[0m"
      echo -e "     \033[1;35md\033[0m   → git diff                      \033[2;37m(see changes)\033[0m"
    fi

    if git log --oneline -1 HEAD > /dev/null 2>&1; then
      echo -e "  \033[0;36mLast commit available\033[0m"
      echo -e "     \033[1;35mamend\033[0m → git commit --amend --no-edit \033[2;37m(fix last commit)\033[0m"
      echo -e "     \033[1;35mlast\033[0m → git log -1 HEAD --stat       \033[2;37m(show last commit)\033[0m"
    fi
  fi
}

show_basic_git_setup() {
  echo -e "\033[1;33m🚀 Git Repository Setup:\033[0m"
  echo -e "  \033[1;35mgit init\033[0m                           \033[2;37m(initialize repository)\033[0m"
  echo -e "  \033[1;35mgit clone <url>\033[0m                    \033[2;37m(clone existing repo)\033[0m"
}

show_essential_aliases() {
  echo -e "\033[1;34m📚 Essential Git Aliases:\033[0m"
  echo
  echo -e "\033[1;37m  Status & Info:\033[0m"
  echo -e "  \033[1;35ms\033[0m    → git status --short --branch     \033[2;37m(compact status)\033[0m"
  echo -e "  \033[1;35ml\033[0m    → git log --oneline --graph -10   \033[2;37m(recent history)\033[0m"
  echo -e "  \033[1;35mb\033[0m    → git branch -v                   \033[2;37m(list branches)\033[0m"
  echo
  echo -e "\033[1;37m  Making Changes:\033[0m"
  echo -e "  \033[1;35ma\033[0m    → git add                         \033[2;37m(stage files)\033[0m"
  echo -e "  \033[1;35maa\033[0m   → git add --all                   \033[2;37m(stage everything)\033[0m"
  echo -e "  \033[1;35mc\033[0m    → git commit                      \033[2;37m(commit)\033[0m"
  echo -e "  \033[1;35mcm\033[0m   → git commit -m                   \033[2;37m(quick commit)\033[0m"
  echo
  echo -e "\033[1;37m  Navigation:\033[0m"
  echo -e "  \033[1;35mco\033[0m   → git checkout                    \033[2;37m(switch branch/restore)\033[0m"
  echo -e "  \033[1;35msw\033[0m   → git switch                      \033[2;37m(modern branch switch)\033[0m"
}

start_practice_mode() {
  clear
  echo -e "\033[1;35m🎮 Git Practice Mode\033[0m"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo
  echo "Try typing these commands in your terminal:"
  echo
  echo -e "\033[1;33m1.\033[0m \033[1;36mgit s\033[0m     \033[2;37m# Check repository status\033[0m"
  echo -e "\033[1;33m2.\033[0m \033[1;36mgit l\033[0m     \033[2;37m# View recent commits\033[0m"
  echo -e "\033[1;33m3.\033[0m \033[1;36mgit b\033[0m     \033[2;37m# List branches\033[0m"
  echo
  echo -e "\033[2;37mTip: Start with these three and practice them daily!\033[0m"
  echo
  echo -e "\033[0;33mPress any key to return to hints...\033[0m"
  read -n 1
  show_contextual_hints
}

# Export the main function for tmux popup usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  show_contextual_hints "$@"
fi
