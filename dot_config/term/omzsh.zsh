##
## Oh My Zsh Configuration
################################################################################
export ZSH="$HOME/.oh-my-zsh"                                                   # Path to Oh My Zsh installation.

ZSH_THEME="avit"                                                                # Theme in use
CASE_SENSITIVE="false"                                                          # Case-insensitive completion
HYPHEN_INSENSITIVE="true"                                                       # treats _ and - as interchangeable
zstyle ':omz:update' mode auto                                                  # 'disabled' or 'auto' or 'reminder'
zstyle ':omz:update' frequency 3                                                # days between updates
DISABLE_MAGIC_FUNCTIONS="true"                                                  # Uncomment the following line if pasting URLs and other text is messed up.
DISABLE_LS_COLORS="true"                                                        # Uncomment the following line to disable colors in ls.
DISABLE_AUTO_TITLE="true"                                                       # Uncomment the following line to disable auto-setting terminal title.
ENABLE_CORRECTION="true"                                                        # Command auto-correction
COMPLETION_WAITING_DOTS="true"                                                  # Completion waiting dots
DISABLE_UNTRACKED_FILES_DIRTY="true"                                            # Uncomment to disable marking untracked files under VCS as dirty\ (faster for large repos)

HIST_STAMPS="yyyy-mm-dd"                                                        # timestamp format in history
HISTSIZE=10000                                                                  # History size
SAVEHIST=10000                                                                  # Save history size
plugins=(   git                                                                 # Git
            docker                                                              # Docker
            docker-compose                                                      # Docker Compose
            terraform                                                           # Terraform
            #mvn                                                                 # Maven
            ssh-agent                                                           # SSH Agent
            #node                                                                # Node
            zsh-autosuggestions                                                 # Zsh Autosuggestions
            zsh-syntax-highlighting                                             # Zsh Syntax Highlighting
            #brew                                                                # Homebrew
            #sdkman                                                              # SDKMAN
)
ZSH_DISABLE_COMPFIX="true"                                                      # Skip directory permission checks
source $ZSH/oh-my-zsh.sh                                                        # Load Oh My Zsh
