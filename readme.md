# Simple Auto-Ricing i3wm Dotfiles

This is my personal collection of dotfiles for **i3wm** on Arch Linux. The primary goal is to create a minimal, functional, and aesthetically pleasing environment with an automated color-theming (ricing) setup based on the current wallpaper.

This setup is built on the foundation of `pywal` and `wpgtk` to generate and apply color schemes on the fly.

**(It is highly recommended to add a screenshot of your desktop here!)**
![Desktop Preview](https://github.com/MDiaznf23/simple-autoricing-i3wm-dotfiles/blob/main/path/to/your/screenshot.png)

---

## About This Configuration

These dotfiles represent a **simplified and modernized** take on more complex auto-ricing scripts. This configuration is heavily inspired by the [chameleon-lizard/autorice](https://github.com/chameleon-lizard/autorice) repository but makes several key changes:

* **Shell:** Uses **Fish** as the default shell instead of Zsh.
* **Python:** Uses `pipx` to install Python utilities (`pywal`, `wpgtk`) in isolated environments, which is safer and cleaner than `pip --user`.
* **Minimalism:** The package list is curated to be more lightweight.
* **Widgets:** Includes **Eww** (Elkowar's Wacky Widgets) for modern, modular widgets.

## Key Components

This setup is built from the following main components:

| Component | Application |
| :--- | :--- |
| **Window Manager** | `i3-wm` |
| **Status Bar** | `Polybar` |
| **Terminal Emulator** | `Alacritty` |
| **Default Shell** | `Fish` |
| **Theming Engine** | `pywal` & `wpgtk` |
| **Application Launcher**| `Rofi` |
| **Compositor** | `Picom` |
| **Widgets** | `Eww` (Elkowar's Wacky Widgets) |
| **File Manager** | `PCManFM` |
| **Wallpaper Manager** | `feh` |
| **Utilities** | `scrot`, `brightnessctl`, `xclip` |

---

## ⚡ Installation

**Warning:** This script is designed exclusively for **Arch Linux** and its derivatives (e.g., EndeavourOS, CachyOS). It will install packages, change your default shell, and overwrite existing configuration files. Please review the script and proceed at your own risk.

### 1. Clone the Repository

```bash
git clone [https://github.com/MDiaznf23/simple-autoricing-i3wm-dotfiles.git](https://github.com/MDiaznf23/simple-autoricing-i3wm-dotfiles.git)
cd simple-autoricing-i3wm-dotfiles

# Make the script executable
chmod +x install.sh

# Run the installer
./install.sh

🔬 What the Installation Script Does

The install.sh script automates the entire setup process:

    AUR Helper Check: Checks if yay or paru is installed. If not, it will clone and install yay.

    Backup: Creates a time-stamped backup of your existing ~/.config, ~/.cache, ~/.local, and ~/.Xresources directories/files into ~/dotfiles_backup_....

    Install Pacman Packages: Installs all necessary system packages from the official repositories (e.g., i3-wm, polybar, alacritty, rofi, fish, python-pipx).

    Install AUR Packages: Uses the yay or paru helper to install eww from the AUR.

    Set Default Shell: Changes the user's default shell to fish using chsh.

    Install Python Packages: Uses pipx to safely install pywal and wpgtk.

    Setup wpgtk: Runs the wpg-install.sh setup scripts.

    Copy Dotfiles: Copies the .config, .cache, .local, and .Xresources files from this repository to your home directory.

    Set Permissions: Makes all necessary scripts (like autostart, polybar launcher, and rofi scripts) executable.

    Load Xresources: Merges the new .Xresources file into the X server's database.

🚀 Post-Installation

After the script finishes, you must log out of your current session and log back in. Select i3 from your display manager's session menu.

Your new terminal will automatically use the fish shell.

Credits & Inspiration

This setup would not be possible without the work of others. It is heavily inspired by and is a simplification of the dotfiles found in the chameleon-lizard/autorice repository.

License

This project is licensed under the MIT License.
