#!/usr/bin/env bash
set -euo pipefail

clear

echo "WELCOME! Now we will install and setup Hyprland on an Arch-based system"

# Installation functions
install_pacman_package() {
  if pacman -Q "$1" &>/dev/null ; then
    echo "$1 is already installed. Skipping..."
  else
    echo "Installing $1 ..."
    sudo pacman -S --noconfirm "$1"
    if ! pacman -Q "$1" &>/dev/null ; then
      echo "$1 failed to install. Please check manually."
      exit 1
    fi
  fi
}

install_aur_package() {
  if paru -Q "$1" &>/dev/null ; then
    echo "$1 is already installed. Skipping..."
  else
    echo "Installing $1 ..."
    paru -S --noconfirm "$1"
    if ! paru -Q "$1" &>/dev/null ; then
      echo "$1 failed to install. Please check manually."
      exit 1
    fi
  fi
}

pacman_packages=(
    # Core Hyprland environment
    hyprland
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-wlr

    # Wallpaper
    swww

    # Screenshot tools
    grim
    slurp

    # Notifications
    swaync

    # Status bar
    waybar

    # Launcher
    rofi
    rofi-emoji

    # Terminal
    kitty

    # Clipboard
    wl-clipboard
    cliphist

    # File manager
    nemo
    gvfs

    # Audio - PipeWire and related tools
    pipewire
    pipewire-alsa
    pipewire-audio
    pipewire-pulse
    pipewire-jack          
    wireplumber    
    pavucontrol
    pamixer

    # Network
    networkmanager
    network-manager-applet

    # Bluetooth
    blueman
    bluez
    bluez-utils

    # Brightness control
    brightnessctl
    
    # Basic tools
    curl
    wget
    unzip
    fastfetch
    neovim
    eza
    fzf
    ripgrep

    # Shell and prompt
    zsh
    starship

    # Fonts
    noto-fonts
    noto-fonts-emoji
    ttf-jetbrains-mono-nerd

    # Input Method
    fcitx5
    fcitx5-gtk
    fcitx5-qt
    fcitx5-configtool
    fcitx5-bamboo
    
    # GTK 
    nwg-look
    
    # QT
    kvantum
    qt5-wayland
    qt6-wayland
    qt6-svg
    qt6-declarative
    qt5-quickcontrols2

    # Display Manager Support
    sddm

    # Policy kit agent
    polkit-kde-agent
)

aur_packages=(
    wlogout
    swaylock-effects-git
    maple-mono-nf-cn-unhinted 
)


# Update system
echo "Updating system..."
sudo pacman -Syu --noconfirm

# Install paru if not present
if ! command -v paru &>/dev/null; then
    echo "Installing paru..."
    git clone https://aur.archlinux.org/paru.git
    cd paru || exit
    makepkg -si --noconfirm
    cd ..
    rm -rf paru
fi

# Install official packages
for package in "${pacman_packages[@]}"; do
  install_pacman_package "$package"
done

# Install AUR packages
for package in "${aur_packages[@]}"; do
  install_aur_package "$package"
done

# Allow pip3 install by removing EXTERNALLY-MANAGED file
sudo rm -rf $(python3 -c "import sys; print(f'/usr/lib/python{sys.version_info.major}.{sys.version_info.minor}/EXTERNALLY-MANAGED')")

# --- Enable services ---
sudo systemctl enable --now sddm
sudo systemctl enable --now bluetooth
sudo systemctl enable --now NetworkManager
systemctl --user enable --now wireplumber pipewire pipewire-pulse

# Set Ghostty as the default terminal emulator for Nemo
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty

# Apply fonts
fc-cache -fv

# Extract themes and icons
sudo tar -xvf ./assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/
sudo tar -xvf ./assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/
sudo tar -xvf ./assets/icons/Bibata-cursor.tar.xz -C /usr/share/icons/

# Backup
MAIN_BACKUP_DIR="$HOME/dotfiles_backup"
mkdir -p "$MAIN_BACKUP_DIR"
echo "Main backup directory: $MAIN_BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DOTFILE_BACKUP="$MAIN_BACKUP_DIR/$TIMESTAMP"
mkdir -p "$DOTFILE_BACKUP"
echo "Current backup folder: $DOTFILE_BACKUP"

items_to_backup=(
  "$HOME/.zshrc"
  "$HOME/.config/colors"
  "$HOME/.config/fastfetch"
  "$HOME/.config/gtk-2.0"
  "$HOME/.config/gtk-3.0"
  "$HOME/.config/gtk-4.0"
  "$HOME/.config/hypr"
  "$HOME/.config/kitty"
  "$HOME/.config/Kvantum"
  "$HOME/.config/rofi"
  "$HOME/.config/scripts"
  "$HOME/.config/swaylock"
  "$HOME/.config/swaync"
  "$HOME/.config/waybar"
  "$HOME/.config/wlogout"
  "$HOME/.config/starship.toml"
)

for item in "${items_to_backup[@]}"; do
    if [ -e "$item" ]; then
        mv "$item" "$DOTFILE_BACKUP/"
        echo "Backed up $item"
    fi
done

echo "Backup completed successfully!"

# Script perm
chmod +x .config/scripts/*.sh  

# Stow dotfiles
stow -t ~ .

# Change shell
ZSH_PATH="$(which zsh)"
chsh -s "$ZSH_PATH"

# Create user dir
mkdir -p ~/Desktop ~/Downloads ~/Documents ~/Pictures ~/Music ~/Videos
