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
    i3-wm i3status i3lock polybar alacritty pcmanfm rofi picom feh scrot xclip conky\
    brightnessctl firefox playerctl lm_sensors imagemagick xsettingsd base-devel git \
    python python-pip python-pipx fish redshift \
    jq bc dunst

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
    mpdris2 \
    ttf-jetbrains-mono-nerd \
    ttf-iosevka-nerd \
    ttf-twemoji \
    fonts-kalam 

# Install custom fonts
echo "Installing custom fonts..."
FONT_DIR="$HOME/.local/share/fonts"
if [ -d "fonts" ]; then
    mkdir -p "$FONT_DIR"
    cp -rf fonts/* "$FONT_DIR"
    echo "Updating font cache..."
    fc-cache -fv
    success "Custom fonts installed to $FONT_DIR"
else
    warning "fonts directory not found"
fi

# Set fish as default shell
echo "Setting fish as default shell..."
sudo chsh -s $(which fish) $USER

# Install Python packages via pipx
echo "Installing Python packages..."
pipx ensurepath
pipx install pywal
pipx install wpgtk

# Inject dependencies ke wpgtk venv
echo "Installing wpgtk dependencies..."
pipx inject wpgtk colorz
pipx inject wpgtk haishoku
pipx inject wpgtk colorthief

# Add pipx bin to PATH for current session
export PATH="$HOME/.local/bin:$PATH"

# Create necessary directories
mkdir -p ~/.config/{i3,polybar,rofi,dunst,alacritty,picom,eww,wpg/templates}
mkdir -p ~/.local/{share,bin}
mkdir -p ~/.cache

# Copy dotfiles - EXCLUDE symlinks and binaries from .local/bin
echo "Copying dotfiles..."

# Copy .config (excluding symlinks)
if [ -d ".config" ]; then
    echo "Copying .config files..."
    rsync -av --exclude='*.tmp' .config/ ~/.config/
    success ".config copied"
fi

# Copy .cache (excluding wal cache)
if [ -d ".cache" ]; then
    echo "Copying .cache files..."
    mkdir -p ~/.cache
    rsync -av --exclude='wal' .cache/ ~/.cache/
    success ".cache copied"
fi

# Copy .local/share (excluding pipx venvs)
if [ -d ".local/share" ]; then
    echo "Copying .local/share files..."
    mkdir -p ~/.local/share
    rsync -av --exclude='pipx' .local/share/ ~/.local/share/
    success ".local/share copied"
fi

# Copy scripts from .local/bin (only actual files, not symlinks)
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

# Copy picom config if exists
echo "Copying picom configuration..."
if [ -d "picom" ]; then
    cp -r picom ~/.config/
    success "Picom config copied to ~/.config/picom"
elif [ -d ".config/picom" ]; then
    # Already copied by rsync above
    success "Picom config already in place"
else
    warning "Picom directory not found"
fi

# Move wallpapers to Pictures
echo "Moving wallpapers..."
if [ -d "Wallpapers" ]; then
    mkdir -p ~/Pictures
    cp -r Wallpapers ~/Pictures/
    success "Wallpapers copied to ~/Pictures/Wallpapers"
elif [ -d "wallpapers" ]; then
    mkdir -p ~/Pictures
    cp -r wallpapers ~/Pictures/
    success "Wallpapers copied to ~/Pictures/wallpapers"
else
    warning "Wallpapers directory not found"
fi

# Create dynamic symlinks for binaries
echo "Creating dynamic symlinks..."

# Wait for pipx to be available
sleep 2

# Symlink pywal binary
if [ -f "$HOME/.local/share/pipx/venvs/pywal/bin/wal" ]; then
    ln -sf "$HOME/.local/share/pipx/venvs/pywal/bin/wal" "$HOME/.local/bin/wal"
    success "wal symlink created"
else
    warning "pywal binary not found yet (will be available after relogin)"
fi

# Symlink wpgtk binary
if [ -f "$HOME/.local/share/pipx/venvs/wpgtk/bin/wpg" ]; then
    ln -sf "$HOME/.local/share/pipx/venvs/wpgtk/bin/wpg" "$HOME/.local/bin/wpg"
    success "wpg symlink created"
else
    warning "wpgtk binary not found yet (will be available after relogin)"
fi

# Create wpg colors.scss symlink for eww
echo "Creating colors.scss symlink for eww..."
if [ -d "$HOME/.config/eww" ]; then
    # Remove if it's a broken symlink
    [ -L "$HOME/.config/eww/colors.scss" ] && rm "$HOME/.config/eww/colors.scss"
    
    # Wait for wal cache to be created, or create placeholder
    if [ ! -f "$HOME/.cache/wal/colors.scss" ]; then
        mkdir -p "$HOME/.cache/wal"
        # Create a basic placeholder that will be replaced by wpg
        cat > "$HOME/.cache/wal/colors.scss" << 'SCSS'
// Placeholder - will be generated by wpg
$color0: #1a1a1a;
$color1: #cc6666;
$color2: #b5bd68;
$color3: #f0c674;
$color4: #81a2be;
$color5: #b294bb;
$color6: #8abeb7;
$color7: #c5c8c6;
$color8: #666666;
$color9: #d54e53;
$color10: #b9ca4a;
$color11: #e7c547;
$color12: #7aa6da;
$color13: #c397d8;
$color14: #70c0b1;
$color15: #eaeaea;
SCSS
        warning "Created placeholder colors.scss"
    fi
    
    ln -sf "$HOME/.cache/wal/colors.scss" "$HOME/.config/eww/colors.scss"
    success "eww colors.scss symlink created"
fi

# Create wpg template symlinks
echo "Creating wpg template symlinks..."
if [ -d "$HOME/.config/wpg/templates" ]; then
    cd "$HOME/.config/wpg/templates"
    
    # Remove old symlinks
    rm -f gtk2 gtk3.0 gtk3.20
    
    # Create new symlinks to FlatColor theme
    mkdir -p "$HOME/.local/share/themes/FlatColor/gtk-2.0"
    mkdir -p "$HOME/.local/share/themes/FlatColor/gtk-3.0"
    mkdir -p "$HOME/.local/share/themes/FlatColor/gtk-3.20"
    
    # Create symlinks if base files exist
    [ -f "gtk2.base" ] && ln -sf "$HOME/.local/share/themes/FlatColor/gtk-2.0/gtkrc" gtk2
    [ -f "gtk3.0.base" ] && ln -sf "$HOME/.local/share/themes/FlatColor/gtk-3.0/gtk.css" gtk3.0
    [ -f "gtk3.20.base" ] && ln -sf "$HOME/.local/share/themes/FlatColor/gtk-3.20/gtk.css" gtk3.20
    
    success "wpg template symlinks created"
    cd - > /dev/null
fi

# Initialize wpg with wallpapers
echo "Initializing wpg with your wallpapers..."

# Clean old schemes
rm -rf ~/.config/wpg/schemes/* 2>/dev/null
rm -rf ~/.cache/wal/* 2>/dev/null

# Make scripts executable
echo "Setting permissions..."
chmod +x ~/.config/i3/autostart.sh 2>/dev/null || warning "i3 autostart.sh not found"
chmod +x ~/.config/polybar/launch.sh 2>/dev/null || warning "polybar launch.sh not found"
chmod +x ~/.config/Scripts/* 2>/dev/null || warning "Scripts directory not found"
chmod +x ~/.local/bin/* 2>/dev/null
find ~/.config/rofi -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || warning "rofi scripts not found"
find ~/.config/eww/scripts -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || warning "eww scripts not found"

# Create wpg wrapper
echo "Creating wpg wrapper..."
sudo tee /usr/local/bin/wpg-post-wrapper > /dev/null << 'EOF'
#!/bin/bash
$HOME/.config/wpg/wpg-post.sh "$@"
EOF
sudo chmod +x /usr/local/bin/wpg-post-wrapper
success "wpg-post-wrapper created"

# Merge Xresources
if [ -f ~/.Xresources ]; then
    xrdb -merge ~/.Xresources
fi

# Post-install: Setup wallpapers (delayed to allow pipx PATH)
echo ""
echo "================================"
echo "Setting up wallpapers..."
echo "================================"

# Function to setup wpg after relogin
cat > ~/setup-wpg.sh << 'SETUP'
#!/bin/bash
echo "Adding wallpapers to wpg..."
if command -v wpg &> /dev/null; then
    for wallpaper in ~/Pictures/Wallpapers/* ~/Pictures/wallpapers/* 2>/dev/null; do
        [ -f "$wallpaper" ] && wpg -a "$wallpaper" 2>/dev/null && echo "Added: $(basename "$wallpaper")"
    done
    
    # Try to set default wallpaper
    if [ -f ~/Pictures/Wallpapers/dark_mountain.jpg ]; then
        wpg -s dark_mountain.jpg && echo "✅ Default theme applied!"
    elif [ -f ~/Pictures/wallpapers/dark_mountain.jpg ]; then
        wpg -s dark_mountain.jpg && echo "✅ Default theme applied!"
    else
        echo "Please run: wpg -s <wallpaper_name>"
    fi
    
    rm ~/setup-wpg.sh
else
    echo "wpg not found in PATH. Please logout and login first."
fi
SETUP

chmod +x ~/setup-wpg.sh

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
echo "  - firefox"
echo "  - pywal, wpgtk, eww"
echo "  - Nerd Fonts & icon fonts"
echo ""
echo "CRITICAL NEXT STEPS:"
echo "1. Logout and login to i3"
echo "2. Run: ~/setup-wpg.sh"
echo "   (This will add wallpapers and set default theme)"
echo "3. Fish shell will be active on next login"
echo "4. Check ~/.xsession-errors for any startup errors"
echo ""
echo "To change themes later: wpg -s <wallpaper_name>"
echo "================================"
