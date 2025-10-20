fastfetch --config ~/.config/fastfetch/MetoCat.jsonc

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
  z
)

source $ZSH/oh-my-zsh.sh

export PATH="$PATH:/Users/fabio/.local/bin"

if [ -f '/Users/fabio/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/fabio/Downloads/google-cloud-sdk/path.zsh.inc'; fi

if [ -f '/Users/fabio/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/fabio/Downloads/google-cloud-sdk/completion.zsh.inc'; fi
alias pygo='source ~/.global-py/bin/activate'

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

