export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

source $ZSH/oh-my-zsh.sh

plugins=(git)
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# History
HISTSIZE=2500
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups
setopt appendhistory
setopt sharehistory

# Fetch
fastfetch

# Aliases
alias spu='sudo pacman -Syu'
alias spr='sudo pacman -Rs'
alias spi='sudo pacman -S'
alias spc='sudo pacman -Rns $(pacman -Qtdq)'
alias zshrc='nvim ~/.zshrc'
