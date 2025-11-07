#!/usr/bin/env bash
set -euo pipefail

clear

echo "==> WELCOME! Now we will install and setup Hyprland on an Arch-based system"

cd ~

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
    # Hyprland & Wayland Environment
    hyprland swww grim slurp swaync waybar rofi rofi-emoji hyprshot xdg-desktop-portal-hyprland xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk

    # System
    brightnessctl network-manager-applet bluez bluez-utils blueman pipewire pipewire-pulse pipewire-audio pipewire-jack pipewire-alsa wireplumber pavucontrol pamixer
        
    # System Utilities and Media
    kitty nemo gvfs loupe gnome-text-editor ffmpeg cava

    # Qt & Display Manager Support
    sddm qt5ct qt6ct qt5-wayland qt6-wayland qt6-svg qt6-declarative qt5-quickcontrols2

    # System monitoring and fun terminal visuals
    btop fastfetch    

    # Essential utilities
    make curl wget unzip dpkg fzf eza bat zoxide neovim tmux ripgrep fd stow man openssh

    # Shell & customization
    zsh starship

    # CTF tools
    gdb ltrace strace patchelf 

    # Programming languages
    python3 python-pip

    # Input Method
    fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool fcitx5-bamboo
    
    # Communication
    discord
    
    # Misc
    adwaita-fonts noto-fonts noto-fonts-cjk ttf-jetbrains-mono-nerd adw-gtk-theme kvantum-qt5 libvips cliphist
)

aur_packages=(
    # Hyprland & Wayland Environment
    wlogout swaylock-effects-git

    # Communication
    firefox telegram-desktop-bin

    # Code Editors and IDEs
    visual-studio-code-bin

    # System monitoring and fun terminal visuals
    pipes.sh peaclock pokemon-colorscripts cmatrix-git

    # Misc
    bibata-cursor-theme-bin tela-circle-icon-theme-dracula
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

# Enable bluetooth
sudo systemctl enable --now bluetooth

# Enable networkmanager
sudo systemctl enable --now NetworkManager

# Set Ghostty as the default terminal emulator for Nemo
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty

# Apply fonts
fc-cache -fv

# Set cursor
mkdir -p ~/.icons/default/
touch ~/.icons/default/index.theme
echo "[icon theme]" >> ~/.icons/default/index.theme
echo "Inherits=Bibata-Modern-Classic" >> ~/.icons/default/index.theme
sudo rm -rf /usr/share/icons/default/index.theme
sudo cp ~/.icons/default/index.theme /usr/share/icons/default/

# Enable sddm
if [[ ! -e /etc/systemd/system/display-manager.service ]]; then
    wget -O catppuccin-mocha-lavender.zip \
        https://github.com/catppuccin/sddm/releases/latest/download/catppuccin-mocha-lavender-sddm.zip
    sudo rm -rf /usr/share/sddm/themes/catppuccin-mocha-lavender
    sudo mkdir -p /usr/share/sddm/themes/catppuccin-mocha-lavender
    sudo unzip -qo catppuccin-mocha-lavender.zip -d /usr/share/sddm/themes/catppuccin-mocha-lavender
    rm -f catppuccin-mocha-lavender.zip
    sudo systemctl enable sddm
    echo -e "[Theme]\nCurrent=catppuccin-mocha-lavender" | sudo tee -a /etc/sddm.conf
    echo "sddm has been enabled."
fi

chmod +x .config/scripts/*.sh  

# Stow dotfiles
stow -t ~ .

# Change shell
ZSH_PATH="$(which zsh)"
grep -qxF "$ZSH_PATH" /etc/shells || echo "$ZSH_PATH" | sudo tee -a /etc/shells
chsh -s "$ZSH_PATH"

# Create user dir
mkdir -p ~/Desktop ~/Downloads ~/Documents ~/Pictures ~/Music ~/Videos
