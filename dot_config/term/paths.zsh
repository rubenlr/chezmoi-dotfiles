##
## PATH and env hooks (all zsh invocations)
################################################################################
[[ -d $HOME/.bin ]] && \
    export PATH="${HOME}/.bin:${PATH}"

[[ -d $HOME/.local/bin ]] && \
    export PATH="$HOME/.local/bin:$PATH"

[[ -d $HOME/.cargo/bin ]] && \
    export PATH="$HOME/.cargo/bin:$PATH"

[[ -d $HOME/.lmstudio/bin ]] && \
    export PATH="$PATH:$HOME/.lmstudio/bin"

[[ -d /opt/homebrew/bin ]] && export PATH="/opt/homebrew/bin:$PATH"

[[ -d $HOME/.local/share/fnm ]] && export PATH="$HOME/.local/share/fnm:$PATH"

command -v brew >/dev/null 2>&1 && export PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:$PATH"

## Env files

[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
[ -f "${HOME}/.local/bin/env" ] && . "${HOME}/.local/bin/env"
[ -f "$HOME/.env" ] && source "$HOME/.env"
