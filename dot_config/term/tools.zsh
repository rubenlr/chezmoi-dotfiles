##
## HomeBrew Configuration
################################################################################
export HOMEBREW_PREFIX=~/.homebrew                                              # HomeBrew prefix
export HOMEBREW_MAKE_JOBS=8                                                     # Use all cores for building when it's necessary
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_UPGRADE_GREEDY=1                                                # Upgrade all packages, include the ones that has auto update setup.
export HOMEBREW_FORBIDDEN_FORMULAE=colima                                       # aways use rootless directories
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"  # aways use rootless directories (mirrors .zshrc)
PATH="${HOMEBREW_PREFIX}/bin:${PATH}"                                           # Add HomeBrew bin to PATH

##
## SDKMAN Configuration
################################################################################
export SDKMAN_DIR="$HOME/.sdkman"                                               # SDKMAN directory
export SDKMAN_AUTO_SELFUPDATE=true                                              # SDKMAN auto self-update
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && \
    source "$HOME/.sdkman/bin/sdkman-init.sh"                                   # Source SDKMAN init script

##
## Enable fnm
################################################################################
export PATH="$HOME/.local/share/fnm:$PATH"
command -v fnm >/dev/null 2>&1 && eval "$(fnm env --shell zsh)"
