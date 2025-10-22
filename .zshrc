# fastfetch --config ~/.config/fastfetch/MetoCat.jsonc

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

# Bat configuration (VS Code theme)
export BAT_THEME="Visual Studio Dark+"

# Python
alias pygo='source ~/.global-py/bin/activate'  # Activate global Python
alias venv='function _venv(){ [ ! -d .venv ] && python3 -m venv .venv; source .venv/bin/activate; }; _venv'  # Create/activate venv
alias cat='bat'  # Better cat
# System
alias clean='~/dotfiles/scripts/clean.sh'  # Clean system
alias reload='source ~/.zshrc'  # Reload zsh
alias ports='lsof -i -P | grep LISTEN'  # Show open ports
alias diskspace='df -h | grep -v tmpfs'  # Disk usage
alias lock='osascript -e "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"'  # Lock screen
alias finder='open -a Finder .'  # Open in Finder
alias speedtest='networkQuality'  # Test internet speed

# Terminal
alias split='~/dotfiles/.venv/bin/python3 ~/dotfiles/scripts/split_terminal.py'  # Split terminal
alias aqua='asciiquarium'  # Aquarium animation
alias fire='cacafire'  # Fire animation
alias 2048='npx 2048-cli'  # 2048 game
alias type='typespeed'  # Typing practice game
alias tldr='function _tldr(){ curl -s cheat.sh/$1; }; _tldr'  # Quick command help
alias insult='curl -s "https://evilinsult.com/generate_insult.php?lang=fr&type=text"'  # Random French insult

# Network
alias ip='curl ipinfo.io'  # Show IP info

# Dotfiles
alias dotfiles-install='cd ~/dotfiles && ./install.sh'  # Install/update dotfiles
alias aliases='~/dotfiles/scripts/show_aliases.sh'  # List aliases

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh          