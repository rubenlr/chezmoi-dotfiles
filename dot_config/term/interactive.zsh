zstyle ':completion:*' rehash true
unsetopt CORRECT
unsetopt CORRECT_ALL

alias zshrc='${EDITOR:-nano} ~/.config/term/zshrc'
alias reload='source ~/.zshrc'

## Android SDK
################################################################################
if [[ -d "$HOME/Library/Android/sdk" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
fi

## Modern CLI Tools
################################################################################
if (( ${+commands[bat]} )); then
  alias cat='bat --paging=never'
  alias less='bat'
fi

if (( ${+commands[eza]} )); then
  alias ls='eza --icons'
  alias ll='eza -lh --icons --git'
  alias la='eza -lah --icons --git'
  alias lt='eza -T --icons --level=2'
fi

# Better grep
#alias grep='rg'

# Better find (used by fzf automatically if installed)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
