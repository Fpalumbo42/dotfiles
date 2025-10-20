#!/bin/bash

echo "Installing dotfiles..."
echo "WARNING: Existing configurations will be overwritten!"

# Remove old configurations
echo "Removing old configurations..."
rm -f ~/.zshrc
rm -f ~/.p10k.zsh
rm -rf ~/.config/fastfetch

# Create symlinks
echo "Creating symlinks..."
ln -sf ~/dotfiles/.zshrc ~/.zshrc
ln -sf ~/dotfiles/.p10k.zsh ~/.p10k.zsh
ln -sf ~/dotfiles/fastfetch ~/.config/fastfetch

# iTerm2 configuration
if [ -f ~/dotfiles/com.googlecode.iterm2.plist ]; then
    echo "Installing iTerm2 configuration..."
    cp -f ~/dotfiles/com.googlecode.iterm2.plist ~/Library/Preferences/
fi

# Install oh-my-zsh if not already installed
if [ ! -d ~/.oh-my-zsh ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Powerlevel10k
if [ ! -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
    echo "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
fi

# Install zsh plugins
if [ ! -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    echo "Installing zsh-autosuggestions..."
    brew install zsh-autosuggestions
fi

if [ ! -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    echo "Installing zsh-syntax-highlighting..."
    brew install zsh-syntax-highlighting
fi

# Install fastfetch if not already installed
if ! command -v fastfetch &> /dev/null; then
    echo "Installing fastfetch..."
    brew install fastfetch
fi

echo "Installation complete!"
echo "Restart your terminal or run: source ~/.zshrc"