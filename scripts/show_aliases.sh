#!/bin/bash

echo -e "\033[1mAliases:\033[0m\n"

# Python
echo -e "\033[33mPython:\033[0m"
awk '/# Python/,/^$/ {if (/^alias/ && !/alias aliases/) print}' ~/.zshrc | sed 's/alias //' | awk -F"[='#]" '{printf "  \033[36m%-20s\033[0m %s\n", $1, $NF}'

# System
echo -e "\n\033[33mSystem:\033[0m"
awk '/# System/,/^$/ {if (/^alias/) print}' ~/.zshrc | sed 's/alias //' | awk -F"[='#]" '{printf "  \033[36m%-20s\033[0m %s\n", $1, $NF}'

# Terminal
echo -e "\n\033[33mTerminal:\033[0m"
awk '/# Terminal/,/^$/ {if (/^alias/) print}' ~/.zshrc | sed 's/alias //' | awk -F"[='#]" '{printf "  \033[36m%-20s\033[0m %s\n", $1, $NF}'

# Network
echo -e "\n\033[33mNetwork:\033[0m"
awk '/# Network/,/^$/ {if (/^alias/) print}' ~/.zshrc | sed 's/alias //' | awk -F"[='#]" '{printf "  \033[36m%-20s\033[0m %s\n", $1, $NF}'

# Dotfiles
echo -e "\n\033[33mDotfiles:\033[0m"
awk '/# Dotfiles/,/^$/ {if (/^alias/ && !/alias aliases/) print}' ~/.zshrc | sed 's/alias //' | awk -F"[='#]" '{printf "  \033[36m%-20s\033[0m %s\n", $1, $NF}'
