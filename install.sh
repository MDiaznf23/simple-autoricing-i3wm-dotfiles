#!/bin/bash
echo "================================"
echo "Installing Dotfiles"
echo "================================"

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
[ -d ~/.cache ] && cp -r ~/.cache $BACKUP_DIR/
[ -d ~/.local ] && cp -r ~/.local $BACKUP_DIR/
[ -f ~/.Xresources ] && cp ~/.Xresources $BACKUP_DIR/

# Install system packages from official repos
echo "Installing system packages..."
sudo pacman -S --needed --noconfirm \
    i3-wm i3status i3lock polybar alacritty pcmanfm rofi picom feh scrot xclip \
    brightnessctl xsettingsd base-devel git \
    python python-pip python-pipx fish \
    jq bc dunst \

# Install fonts
echo "Installing fonts..."
sudo pacman -S --needed --noconfirm \
    noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra \
    ttf-jetbrains-mono ttf-fira-code ttf-dejavu \
    ttf-liberation \
    ttf-font-awesome

# Install AUR packages
echo "Installing AUR packages..."
$AUR_HELPER -S --needed --noconfirm \
    eww \
    firefox-esr-bin \
    ttf-jetbrains-mono-nerd \
    ttf-iosevka-nerd \
    ttf-twemoji

# Set fish as default shell
echo "Setting fish as default shell..."
sudo chsh -s $(which fish) $USER

# Install Python packages via pipx
echo "Installing Python packages..."
pipx ensurepath
pipx install pywal
pipx install wpgtk

# Add pipx bin to PATH for current session
export PATH="$HOME/.local/bin:$PATH"

# Run wpgtk setup
echo "Setting up wpgtk..."
wpg-install.sh 2>/dev/null || echo "Warning: wpg-install.sh failed or not found"
wpg-install.sh -i 2>/dev/null || echo "Warning: wpg-install.sh -i failed or not found"

# Copy dotfiles
echo "Copying dotfiles..."
cp -r .config ~/
cp -r .cache ~/
cp -r .local ~/
cp .Xresources ~/

# Move wallpapers to Pictures
echo "Moving wallpapers..."
if [ -d "wallpapers" ]; then
    mkdir -p ~/Pictures
    cp -r wallpapers ~/Pictures/
    echo "Wallpapers copied to ~/Pictures/wallpapers"
else
    echo "Warning: wallpapers directory not found"
fi

# Make scripts executable
echo "Setting permissions..."
chmod +x ~/.config/i3/autostart.sh 2>/dev/null || echo "Warning: i3 autostart.sh not found"
chmod +x ~/.config/polybar/launch.sh 2>/dev/null || echo "Warning: polybar launch.sh not found"
chmod +x ~/.config/Scripts/* 2>/dev/null || echo "Warning: Scripts directory not found"
find ~/.config/rofi -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || echo "Warning: rofi scripts not found"

# Merge Xresources
if [ -f ~/.Xresources ]; then
    xrdb -merge ~/.Xresources
fi

# Create necessary directories if they don't exist
mkdir -p ~/.config/{i3,polybar,rofi,dunst,alacritty}
mkdir -p ~/.local/share
mkdir -p ~/.cache

echo ""
echo "================================"
echo "Installation Complete!"
echo "================================"
echo "Backup saved at: $BACKUP_DIR"
echo ""
echo "Installed packages:"
echo "  - i3-wm, polybar, rofi, dunst"
echo "  - alacritty, pcmanfm, picom, feh"
echo "  - jq, bc, xclip, scrot"
echo "  - firefox, firefox-esr-bin"
echo "  - pywal, wpgtk, eww"
echo ""
echo "NEXT STEPS:"
echo "1. Logout and login to i3"
echo "2. Fish shell will be active on next login"
echo "3. Check ~/.xsession-errors for any startup errors"
echo "================================"
