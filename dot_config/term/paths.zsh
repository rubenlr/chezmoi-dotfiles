##
## PATH and env hooks (all zsh invocations)
################################################################################
export PATH="${HOME}/.bin:${PATH}"

[ -f "${HOME}/.local/bin/env" ] && . "${HOME}/.local/bin/env"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"
# End of LM Studio CLI section

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="$HOME/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

command -v brew >/dev/null 2>&1 && export PATH="$(brew --prefix)/opt/coreutils/libexec/gnubin:$PATH"

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
