#!/bin/bash
set -e

echo "================================"
echo "Installing Dotfiles"
echo "================================"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() { echo -e "${RED}✗ $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Distro check
if ! command -v pacman &>/dev/null; then
    error "pacman not found. This script is for Arch-based distros only."
    exit 1
fi

DISTRO=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')
if [[ "$DISTRO" == "cachyos" || "$DISTRO" == "endeavouros" || "$DISTRO" == "manjaro" ]]; then
    warning "Distro '$DISTRO' detected. Some packages may conflict with distro defaults."
    read -rp "Continue installation? (y/N): " confirm
    [[ "$confirm" != "y" ]] && exit 1
fi

# Install base packages
echo "Installing base-devel..."
sudo pacman -S --needed --noconfirm base-devel git

# Check for AUR helper
if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
    echo "Installing yay (AUR helper)..."
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd -
fi
AUR_HELPER=$(command -v yay || command -v paru)

# Backup existing configs
BACKUP_DIR=~/dotfiles_backup_$(date +%Y%m%d_%H%M%S)
echo "Backing up existing configs to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
[ -d ~/.config ] && cp -r ~/.config "$BACKUP_DIR/"
[ -f ~/.Xresources ] && cp ~/.Xresources "$BACKUP_DIR/"

if [ -d "$BACKUP_DIR" ]; then
    success "Backup saved at $BACKUP_DIR"
else
    error "Backup failed! Aborting."
    exit 1
fi

# Install system packages
echo "Installing system packages..."
sudo pacman -S --needed --noconfirm \
    i3-wm i3status alacritty pcmanfm rofi picom feh scrot xclip xdotool dex \
    brightnessctl firefox dolphin xorg-xdpyinfo playerctl lm_sensors imagemagick xsettingsd \
    python python-pip python-pipx lxsession fish redshift inotify-tools \
    jq bc dunst rsync fastfetch pamixer python-i3ipc cava tex-gyre-fonts kde-cli-tools konsole archlinux-xdg-menu python-dbus xdg-desktop-portal-gtk

# Install fonts
echo "Installing fonts..."
sudo pacman -S --needed --noconfirm \
    noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
    ttf-jetbrains-mono ttf-fira-code ttf-dejavu \
    ttf-liberation ttf-font-awesome

# Handle i3lock -> i3lock-color
if pacman -Qi i3lock &>/dev/null; then
    echo "Removing i3lock (will be replaced by i3lock-color)..."
    sudo pacman -Rdd --noconfirm i3lock 2>/dev/null \
        && success "i3lock removed" \
        || warning "Failed to remove i3lock. Remove manually: sudo pacman -Rdd i3lock"
fi

# Install AUR packages
echo "Installing AUR packages..."
$AUR_HELPER -S --needed --noconfirm \
    eww-git \
    ttf-jetbrains-mono-nerd \
    ttf-iosevka-nerd \
    ttf-twemoji \
    ueberzugpp \
    qt5ct-kde \
    qt6ct-kde \
    mpd-mpris \
    i3lock-color \
    m3wal

# Install custom fonts
if [ -d "fonts" ]; then
    echo "Installing custom fonts..."
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    cp -rf fonts/* "$FONT_DIR"
    fc-cache -fv
    success "Custom fonts installed"
fi

# Install Tela icon theme
echo "Installing Tela icon theme..."
git clone https://github.com/vinceliuice/Tela-icon-theme.git /tmp/Tela-icon-theme
cd /tmp/Tela-icon-theme && ./install.sh
cd -
success "Tela icon theme installed"

# Set fish as default shell (safely)
echo "Setting fish as default shell..."
FISH_PATH=$(which fish)
if ! grep -qxF "$FISH_PATH" /etc/shells; then
    echo "Registering fish to /etc/shells..."
    echo "$FISH_PATH" | sudo tee -a /etc/shells
    success "fish registered to /etc/shells"
fi
sudo chsh -s "$FISH_PATH" "$USER"
success "Default shell changed to fish"

# Persist PATH in fish config
mkdir -p ~/.config/fish
if ! grep -q "fish_add_path.*\.local/bin" ~/.config/fish/config.fish 2>/dev/null; then
    echo 'fish_add_path ~/.local/bin' >> ~/.config/fish/config.fish
    success "PATH persisted to fish config"
fi

# Create necessary directories
echo "Creating directories..."
mkdir -p ~/.config/{i3,rofi,dunst,alacritty,picom,eww,m3-colors}
mkdir -p ~/.local/{share,bin}
mkdir -p ~/.cache

# Copy dotfiles
echo "Copying dotfiles..."
if [ -d ".config" ]; then
    rsync -av --backup --backup-dir="$BACKUP_DIR/rsync-overwritten" \
        --exclude='*.tmp' .config/ ~/.config/
    success ".config copied"
fi

if [ -d ".local/share" ]; then
    echo "Copying .local/share files..."
    mkdir -p ~/.local/share
    rsync -av --exclude='pipx' .local/share/ ~/.local/share/
    success ".local/share copied"
fi

if [ -d ".local/bin" ]; then
    echo "Copying scripts from .local/bin..."
    mkdir -p ~/.local/bin
    find .local/bin -maxdepth 1 -type f -exec cp {} ~/.local/bin/ \;
    success "Scripts copied"
fi

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

# m3-colors
echo "Setting up m3-colors..."
if [ -d "m3-colors" ]; then
    cp -r m3-colors/* ~/.config/m3-colors/
    success "m3-colors config copied"
else
    warning "m3-colors directory not found, using defaults"
fi

# Permissions
echo "Setting permissions..."
find ~/.config -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null
find ~/.config/Scripts -type f -name "*.py" -exec chmod +x {} \; 2>/dev/null
chmod +x ~/.local/bin/* 2>/dev/null || true

# Initialize m3wal
echo ""
echo "================================"
echo "Initializing m3wal..."
echo "================================"

WALLPAPER=$(find ~/Pictures/Wallpapers ~/Pictures/wallpapers -type f \
    \( -iname "*.jpg" -o -iname "*.png" \) 2>/dev/null | head -n 1)

if command -v m3wal &>/dev/null; then
    if [ -n "$WALLPAPER" ]; then
        echo "Applying wallpaper: $WALLPAPER"
        m3wal "$WALLPAPER" --full
        success "Wallpaper and theme applied"
    else
        warning "No wallpaper found, skipping m3wal initialization"
        echo "Run 'm3wal /path/to/wallpaper.jpg --full' manually later"
    fi
else
    warning "m3wal not found. Install manually: yay -S m3wal"
fi

# Reload i3
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

echo ""
echo "================================"
echo "Installation Complete!"
echo "================================"
echo "Backup saved at: $BACKUP_DIR"
echo ""
echo "Installed components:"
echo "  • i3-wm, rofi, dunst, picom"
echo "  • alacritty, dolphin, feh"
echo "  • firefox, eww, m3wal"
echo "  • Nerd Fonts & icon fonts"
echo ""
echo "Next steps:"
echo "  1. Logout and log back in (or restart)"
echo "  2. Select i3 as your window manager"
echo "  3. Change wallpaper: m3wal /path/to/wallpaper.jpg --full"
echo "  4. Configure m3-colors: ~/.config/m3-colors/m3-colors.conf"
echo ""
echo "================================"
