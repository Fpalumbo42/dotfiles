#!/bin/bash

set -e  # Exit on error

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Installing dotfiles..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  WARNING: Existing configurations will be overwritten!"
echo ""

# Remove old configurations
echo "🗑️  Removing old configurations..."
rm -f ~/.zshrc
rm -f ~/.p10k.zsh
rm -rf ~/.config/fastfetch
rm -rf ~/.config/btop

# Create symlinks
echo "🔗 Creating symlinks..."
ln -sf ~/dotfiles/.zshrc ~/.zshrc
ln -sf ~/dotfiles/.p10k.zsh ~/.p10k.zsh
ln -sf ~/dotfiles/fastfetch ~/.config/fastfetch

# Symlink btop config if it exists
if [ -d ~/dotfiles/btop ]; then
    echo "  → Symlinking btop configuration..."
    ln -sf ~/dotfiles/btop ~/.config/btop
fi

# iTerm2 configuration
if [ -f ~/dotfiles/com.googlecode.iterm2.plist ]; then
    echo "⚙️  Installing iTerm2 configuration..."
    defaults read com.googlecode.iterm2 > /dev/null 2>&1
    cp -f ~/dotfiles/com.googlecode.iterm2.plist ~/Library/Preferences/
    killall cfprefsd 2>/dev/null || true
fi

# Install oh-my-zsh if not already installed
if [ ! -d ~/.oh-my-zsh ]; then
    echo "📦 Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Powerlevel10k
if [ ! -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
    echo "🎨 Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k
fi

# Install zsh plugins
echo "🔌 Installing zsh plugins..."
if ! brew list zsh-autosuggestions &> /dev/null; then
    echo "  → Installing zsh-autosuggestions..."
    brew install zsh-autosuggestions
fi

if ! brew list zsh-syntax-highlighting &> /dev/null; then
    echo "  → Installing zsh-syntax-highlighting..."
    brew install zsh-syntax-highlighting
fi

# Install fastfetch if not already installed
if ! command -v fastfetch &> /dev/null; then
    echo "🚀 Installing fastfetch..."
    brew install fastfetch
fi

# Install btop if not already installed
if ! command -v btop &> /dev/null; then
    echo "📊 Installing btop (system monitor)..."
    brew install btop
fi

# Install fun terminal tools
echo "🎨 Installing fun terminal tools..."
if ! command -v asciiquarium &> /dev/null; then
    echo "  → Installing asciiquarium..."
    brew install asciiquarium
fi

if ! command -v cacafire &> /dev/null; then
    echo "  → Installing libcaca (cacafire)..."
    brew install libcaca
fi

# Install Node.js if not already installed (needed for 2048)
if ! command -v node &> /dev/null; then
    echo "  → Installing Node.js..."
    brew install node
fi

# Install 2048 game via npm
echo "  → Installing 2048 game..."
npm install -g 2048-cli

# Setup Python virtual environment for iTerm2 scripts
echo "🐍 Setting up Python virtual environment..."
cd ~/dotfiles

# Remove old venv if exists
if [ -d .venv ]; then
    echo "  → Removing old virtual environment..."
    rm -rf .venv
fi

# Create new venv
echo "  → Creating virtual environment..."
python3 -m venv .venv

# Activate venv and install iterm2
echo "  → Installing iterm2 package..."
.venv/bin/pip install --quiet --upgrade pip
.venv/bin/pip install --quiet iterm2

# Create scripts directory
mkdir -p ~/dotfiles/scripts

# Make scripts executable
if [ -f ~/dotfiles/scripts/split_terminal.py ]; then
    chmod +x ~/dotfiles/scripts/split_terminal.py
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 IMPORTANT: To enable iTerm2 Python API:"
echo "   1. Open iTerm2 > Preferences (Cmd+,)"
echo "   2. Go to 'General' > 'Magic'"
echo "   3. Check '✓ Enable Python API'"
echo ""
echo "🎯 Available commands:"
echo "   • split             → Create 3-pane layout with btop monitor"
echo "   • reload            → Reload shell configuration"
echo "   • dotfiles-install  → Reinstall dotfiles"
echo "   • btop              → Launch btop system monitor"
echo "   • ip                → Show your IP info"
echo "   • aqua              → ASCII aquarium animation"
echo "   • fire              → Fire animation"
echo "   • 2048              → Play 2048 game"
echo ""
echo "💡 Tip: Press 'Esc' or 'M' in btop to customize colors and layout!"
echo ""
echo "🔄 Restart your terminal or run: source ~/.zshrc"
echo ""