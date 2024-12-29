#!/bin/bash

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

# Update system
sudo pacman -Syu --noconfirm

# Essential packages
pacman_packages=(
    # Package Management
    pacman-contrib reflector

    # System Monitoring & Utilities
    btop fastfetch lsd bat

    # Notification & Clipboard
    libnotify clipnotify cliphist

    # Window Manager & Display System
    hyprland waybar swaybg sddm
    polkit-gnome xdg-desktop-portal xdg-desktop-portal-hyprland 
    xdg-desktop-portal-wlr xdg-desktop-portal-gtk

    # Networking & VPN
    networkmanager openvpn networkmanager-openvpn sshfs

    # Bluetooth
    bluez bluez-utils blueman

    # Audio
    pipewire pipewire-pulse wireplumber pavucontrol pamixer

    # System Tools
    parallel pyenv brightnessctl wl-clipboard

    # Development Tools
    base-devel gcc clang make cmake automake fakeroot

    # Shell & Terminal Utilities
    kitty zsh ranger tmux

    # File Management
    nemo gvfs ark

    # Appearance & Themes
    qt5ct qt6ct qt5-graphicaleffects qt5-svg qt5-quickcontrols2 
    qt5-wayland qt6-wayland

    # Applications
    firefox neovim dunst hypridle vlc redshift

    # Media & Documents
    loupe zathura-pdf-poppler imagemagick

    # Input Method (fcitx5)
    fcitx5 fcitx5-qt fcitx5-gtk fcitx5-unikey

    # Fonts
    ttf-hack-nerd ttf-jetbrains-mono ttf-jetbrains-mono-nerd
)

# AUR Packages
aur_packages=(
    # Wayland utilities
    rofi-lbonn-wayland-git swaylock-effects-git grimblast-git flameshot-git hyprpicker wlr-randr-git hyprprop wlogout

    # Appearance & Themes
    bibata-cursor-theme-bin tela-circle-icon-theme-dracula

    # Applications
    telegram-desktop-bin visual-studio-code-bin obsidian

    # Misc tools
    cava cmatrix-git peaclock
)

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

. rog.sh
. nvidia.sh

# Final message
echo "All packages installed successfully."

# start services
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth.service
sudo systemctl start NetworkManager
sudo systemctl start bluetooth.service
sudo systemctl enable sddm.service

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Set open in terminal in nemo
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty

# Setup configs
code --install-extension apps/vscode/catppuccin-vsc-3.16.1.vsix
cp -r .config "$HOME"
cp -r bin "$HOME"
cp -r .icons "$HOME"
cp -r .themes "$HOME"
cp -r wallpaper "$HOME"
chsh -s $(which zsh)
cp .zshrc $HOME
sudo cp -r sddm_theme/catppuccin-mocha /usr/share/sddm/themes/
sudo cp sddm_theme/sddm.conf /etc/
sudo cp -r .local/share/nemo/actions/* /usr/share/nemo/actions/

echo 'Installation complete!'
