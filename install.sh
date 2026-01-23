#!/bin/bash
set -e  # Exit on error

echo "================================"
echo "Installing Dotfiles"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
error() { echo -e "${RED}✗ $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Install base packages
echo "Installing base-devel..."
sudo pacman -S --needed --noconfirm base-devel git

# Check for AUR helper
if ! command -v yay &> /dev/null && ! command -v paru &> /dev/null; then
    echo "Installing yay (AUR helper)..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd -
fi
AUR_HELPER=$(command -v yay || command -v paru)

# Backup existing configs
BACKUP_DIR=~/dotfiles_backup_$(date +%Y%m%d_%H%M%S)
echo "Backing up existing configs to $BACKUP_DIR"
mkdir -p $BACKUP_DIR
[ -d ~/.config ] && cp -r ~/.config $BACKUP_DIR/
[ -f ~/.Xresources ] && cp ~/.Xresources $BACKUP_DIR/

# Install system packages
echo "Installing system packages..."
sudo pacman -S --needed --noconfirm \
    i3-wm i3status i3lock alacritty pcmanfm rofi picom feh scrot xclip xdotool \
    brightnessctl firefox playerctl lm_sensors imagemagick xsettingsd \
    python python-pip python-pipx fish redshift \
    jq bc dunst rsync fastfetch pamixer python-i3ipc qt5ct

# Install fonts
echo "Installing fonts..."
sudo pacman -S --needed --noconfirm \
    noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
    ttf-jetbrains-mono ttf-fira-code ttf-dejavu \
    ttf-liberation ttf-font-awesome

# Install AUR packages
echo "Installing AUR packages..."
$AUR_HELPER -S --needed --noconfirm \
    eww-git \
    mpdris2 \
    ttf-jetbrains-mono-nerd \
    ttf-iosevka-nerd \
    ttf-twemoji \
    ueberzugpp \
    qt6ct-kde

# Install custom fonts if available
if [ -d "fonts" ]; then
    echo "Installing custom fonts..."
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    cp -rf fonts/* "$FONT_DIR"
    fc-cache -fv
    success "Custom fonts installed"
fi

# Set fish as default shell
echo "Setting fish as default shell..."
sudo chsh -s $(which fish) $USER

# Install m3wal via pipx
echo "Installing m3wal..."
pipx ensurepath
pipx install m3wal
export PATH="$HOME/.local/bin:$PATH"
success "m3wal installed"

# Create necessary directories
echo "Creating directories..."
mkdir -p ~/.config/{i3,rofi,dunst,alacritty,picom,eww,m3-colors}
mkdir -p ~/.local/{share,bin}
mkdir -p ~/.cache

# Copy dotfiles
echo "Copying dotfiles..."
if [ -d ".config" ]; then
    rsync -av --exclude='*.tmp' .config/ ~/.config/
    success ".config copied"
fi

# Copy .local/share (excluding pipx venvs)
if [ -d ".local/share" ]; then
    echo "Copying .local/share files..."
    mkdir -p ~/.local/share
    rsync -av --exclude='pipx' .local/share/ ~/.local/share/
    success ".local/share copied"
fi

# Copy scripts from .local/bin 
if [ -d ".local/bin" ]; then
    echo "Copying scripts from .local/bin..."
    mkdir -p ~/.local/bin
    # Copy only regular files (not symlinks)
    find .local/bin -maxdepth 1 -type f -exec cp {} ~/.local/bin/ \;
    success "Scripts copied"
fi

# Copy resource files
[ -f ".Xresources" ] && cp .Xresources ~/
[ -f ".xprofile" ] && cp .xprofile ~/

# Copy wallpapers
if [ -d "Wallpapers" ] || [ -d "wallpapers" ]; then
    echo "Copying wallpapers..."
    mkdir -p ~/Pictures
    [ -d "Wallpapers" ] && cp -r Wallpapers ~/Pictures/
    [ -d "wallpapers" ] && cp -r wallpapers ~/Pictures/
    success "Wallpapers copied"
fi

# Copy m3-colors configuration
echo "Setting up m3-colors..."
if [ -d "m3-colors" ]; then
    cp -r m3-colors/* ~/.config/m3-colors/
    success "m3-colors config copied"
else
    warning "m3-colors directory not found, using defaults"
fi

# Make scripts executable
echo "Setting permissions..."
find ~/.config -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null
find ~/.config/Scripts -type f -name "*.py" -exec chmod +x {} \; 2>/dev/null
chmod +x ~/.local/bin/* 2>/dev/null || true

# Initialize m3wal with default wallpaper (if available)
echo ""
echo "================================"
echo "Initializing m3wal..."
echo "================================"

# Find first wallpaper
WALLPAPER=$(find ~/Pictures/Wallpapers ~/Pictures/wallpapers -type f \( -iname "*.jpg" -o -iname "*.png" \) 2>/dev/null | head -n 1)

if [ -n "$WALLPAPER" ]; then
    echo "Applying wallpaper: $WALLPAPER"
    m3wal "$WALLPAPER" --full
    success "Wallpaper and theme applied"
else
    warning "No wallpaper found, skipping m3wal initialization"
    echo "Run 'm3wal /path/to/wallpaper.jpg --full' manually later"
fi

# Reload i3 if currently running
echo ""
echo "================================"
echo "Reloading i3..."
echo "================================"

if pgrep -x "i3" > /dev/null; then
    i3-msg restart
    success "i3 reloaded successfully"
else
    warning "i3 is not currently running"
    echo "Please logout and select i3 as your window manager"
fi

# Final message
echo ""
echo "================================"
echo "Installation Complete!"
echo "================================"
echo "Backup saved at: $BACKUP_DIR"
echo ""
echo "Installed components:"
echo "  • i3-wm, rofi, dunst, picom"
echo "  • alacritty, pcmanfm, feh"
echo "  • firefox, eww, m3wal"
echo "  • Nerd Fonts & icon fonts"
echo ""
echo "Next steps:"
echo "  1. Logout and login again (or restart)"
echo "  2. Select i3 as your window manager"
echo "  3. Change wallpaper: m3wal /path/to/wallpaper.jpg --full"
echo "  4. Configure m3-colors: ~/.config/m3-colors/m3-colors.conf"
echo ""
echo "================================"
