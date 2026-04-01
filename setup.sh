#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Dotfiles Setup ==="
echo "Source: $DOTFILES_DIR"
echo ""

# --- Install packages ---
echo ">>> Installing packages..."
sudo apt update && sudo apt install -y zsh tmux alacritty curl git unzip fontconfig

# --- Install Neovim (latest stable from GitHub) ---
echo ">>> Installing latest Neovim..."
NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
TMP_DIR="$(mktemp -d)"
curl -Lo "$TMP_DIR/nvim.tar.gz" "$NVIM_URL"
sudo rm -rf /opt/nvim
sudo tar -xzf "$TMP_DIR/nvim.tar.gz" -C /opt/
sudo mv /opt/nvim-linux-x86_64 /opt/nvim
rm -rf "$TMP_DIR"
if ! grep -q '/opt/nvim/bin' <<< "$PATH"; then
  export PATH="/opt/nvim/bin:$PATH"
fi

# --- Install JetBrainsMono Nerd Font ---
echo ">>> Installing JetBrainsMono Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts"
if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
  NERD_FONT_VERSION="3.3.0"
  FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONT_VERSION}/JetBrainsMono.zip"
  TMP_DIR="$(mktemp -d)"
  curl -Lo "$TMP_DIR/JetBrainsMono.zip" "$FONT_URL"
  mkdir -p "$FONT_DIR"
  unzip -o "$TMP_DIR/JetBrainsMono.zip" -d "$FONT_DIR"
  rm -rf "$TMP_DIR"
  fc-cache -fv
else
  echo "JetBrainsMono Nerd Font already installed, skipping."
fi

# --- Install kanata ---
echo ">>> Installing kanata..."
KANATA_VERSION="1.8.0"
KANATA_URL="https://github.com/jtroo/kanata/releases/download/v${KANATA_VERSION}/kanata_v${KANATA_VERSION}"
sudo curl -Lo /usr/local/bin/kanata "$KANATA_URL"
sudo chmod +x /usr/local/bin/kanata

# --- Install oh-my-zsh ---
echo ">>> Installing oh-my-zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "oh-my-zsh already installed, skipping."
fi

# --- Install zsh plugins ---
echo ">>> Installing zsh plugins..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# --- Copy config files ---
echo ">>> Copying config files..."

cp "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
cp "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"

mkdir -p "$HOME/.config/alacritty"
cp "$DOTFILES_DIR/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"

mkdir -p "$HOME/.config/nvim"
cp -r "$DOTFILES_DIR/nvim/." "$HOME/.config/nvim/"

# --- Bootstrap LazyVim ---
echo ">>> Installing lazy.nvim and LazyVim plugins..."
LAZY_DIR="$HOME/.local/share/nvim/lazy/lazy.nvim"
if [ ! -d "$LAZY_DIR" ]; then
  git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "$LAZY_DIR"
fi
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

mkdir -p "$HOME/.config/kanata"
cp "$DOTFILES_DIR/config.kbd" "$HOME/.config/kanata/config.kbd"

# --- Kanata systemd user service ---
echo ">>> Setting up kanata systemd service..."
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/kanata.service" << 'EOF'
[Unit]
Description=Kanata keyboard remapper
Documentation=https://github.com/jtroo/kanata

[Service]
Type=simple
ExecStart=/usr/local/bin/kanata -c %h/.config/kanata/config.kbd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now kanata

# --- Install Claude Code ---
echo ">>> Installing Claude Code..."
if ! command -v claude &>/dev/null; then
  curl -fsSL https://claude.ai/install.sh | sh
else
  echo "Claude Code already installed, skipping."
fi

# --- Set default shell to zsh ---
echo ">>> Setting default shell to zsh..."
chsh -s "$(which zsh)"

# --- Done ---
echo ""
echo "=== Setup Complete ==="
echo "  - zsh, tmux, neovim, alacritty installed"
echo "  - JetBrainsMono Nerd Font installed"
echo "  - oh-my-zsh + plugins installed"
echo "  - LazyVim plugins synced"
echo "  - Claude Code installed"
echo "  - kanata installed and running as user service"
echo "  - Config files copied to ~/.config/"
echo "  - Default shell set to zsh"
echo ""
echo "Log out and back in for shell change to take effect."
