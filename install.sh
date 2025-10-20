#!/bin/bash

echo "🚀 Installation des dotfiles de Fabio..."

# Sauvegarde les configs existantes
echo "📦 Backup des configs existantes..."
mkdir -p ~/.dotfiles-backup
cp ~/.zshrc ~/.dotfiles-backup/.zshrc.backup 2>/dev/null
cp ~/.p10k.zsh ~/.dotfiles-backup/.p10k.zsh.backup 2>/dev/null

# Crée les symlinks
echo "🔗 Création des symlinks..."
ln -sf ~/dotfiles/.zshrc ~/.zshrc
ln -sf ~/dotfiles/.p10k.zsh ~/.p10k.zsh
rm -rf ~/.config/fastfetch
ln -sf ~/dotfiles/fastfetch ~/.config/fastfetch

# iTerm2 config
if [ -f ~/dotfiles/com.googlecode.iterm2.plist ]; then
    echo "🎨 Installation config iTerm2..."
    cp ~/dotfiles/com.googlecode.iterm2.plist ~/Library/Preferences/
fi

# Installation de oh-my-zsh si pas installé
if [ ! -d ~/.oh-my-zsh ]; then
    echo "📥 Installation de oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Installation de Powerlevel10k
if [ ! -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
    echo "🎨 Installation de Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
fi

# Installation des plugins zsh
if [ ! -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    echo "💡 Installation de zsh-autosuggestions..."
    brew install zsh-autosuggestions
fi

if [ ! -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    echo "🎨 Installation de zsh-syntax-highlighting..."
    brew install zsh-syntax-highlighting
fi

# Installation de fastfetch si pas installé
if ! command -v fastfetch &> /dev/null; then
    echo "⚡ Installation de fastfetch..."
    brew install fastfetch
fi

echo "✅ Installation terminée!"
echo "🔄 Relance ton terminal ou exécute: source ~/.zshrc"
