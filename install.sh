#!/bin/bash

# ==== Check if running Arch ==== #
. /etc/os-release

if [[ $ID != 'arch' ]]; then
  echo 'Arch Linux not detected.'
  echo 'This script only works on Arch or Arch based distros.'
  read -p 'Continue anyways? (y/N) ' confirmation
  confirmation=$(echo "$confirmation" | tr '[:lower:]' '[:upper:]')
  if [[ "$confirmation" == 'N' ]] || [[ "$confirmation" == '' ]]; then
    exit 1
  fi
fi

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
    # Development tools
    base-devel gcc clang make cmake automake fakeroot dpkg
    
    # Window Manager & Display System
    hyprland waybar polkit-gnome xdg-desktop-portal-hyprland
    
    # System utilities
    brightnessctl wl-clipboard cliphist fastfetch btop lsd bat
    
    # Audio
    pipewire pipewire-pulse wireplumber pavucontrol pamixer
    
    # Networking
    networkmanager network-manager-applet
    
    # Bluetooth
    bluez bluez-utils blueman
    
    # Shell & Terminal
    kitty zsh ranger
    
    # File management
    nemo gvfs ark
    
    # Appearance & Themes
    qt5ct qt6ct kvantum kvantum-qt5 lxappearance
    qt5-graphicaleffects qt5-svg qt5-quickcontrols2
    qt5-wayland qt6-wayland
    nwg-look
    starship

    # Applications
    neovim rofi-wayland nano dunst hypridle swaybg
    
    # Media & Documents
    loupe zathura-pdf-poppler imagemagick ueberzugpp

    # fcitx5
    fcitx5 fcitx5-qt fcitx5-gtk fcitx5-unikey kcm-fcitx5

    # Font
    ttf-hack-nerd ttf-jetbrains-mono-nerd
)

# AUR Packages
aur_packages=(
    # Wayland utilities
    swaylock-effects-git grimblast-git hyprpicker wlr-randr-git hyprprop wlogout

    # Appearance & Themes
    bibata-cursor-theme-bin tela-circle-icon-theme-dracula

    # Applications
    google-chrome telegram-desktop-bin visual-studio-code-bin
    
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

# NVIDIA driver installation prompt
read -p 'Do you want to install NVIDIA drivers? (y/N) ' confirmation
confirmation=$(echo "$confirmation" | tr '[:lower:]' '[:upper:]')
if [[ "$confirmation" == 'Y' ]] || [[ "$confirmation" == '' ]]; then
  nvidia_pkg=(
    nvidia-dkms
    nvidia-settings
    nvidia-utils
    libva
    libva-nvidia-driver-git
  )

  # Install additional Nvidia packages
  echo "Installing additional Nvidia packages..."
  for krnl in $(cat /usr/lib/modules/*/pkgbase); do
    for NVIDIA in "${krnl}-headers" "${nvidia_pkg[@]}"; do
      install_aur_package "$NVIDIA"
    done
  done

  # Check if the Nvidia modules are already added in mkinitcpio.conf and add if not
  if grep -qE '^MODULES=.*nvidia. *nvidia_modeset.*nvidia_uvm.*nvidia_drm' /etc/mkinitcpio.conf; then
    echo "Nvidia modules already included in /etc/mkinitcpio.conf"
  else
    sudo sed -Ei 's/^(MODULES=\([^\)]*)\)/\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    echo "Nvidia modules added in /etc/mkinitcpio.conf"
  fi

  sudo mkinitcpio -P

  # Additional Nvidia steps
  NVEA="/etc/modprobe.d/nvidia.conf"
  if [ -f "$NVEA" ]; then
    echo "Seems like nvidia-drm modeset=1 is already added in your system..moving on."
  else
    echo "Adding options to $NVEA..."
    sudo echo -e "options nvidia_drm modeset=1 fbdev=1" | sudo tee -a /etc/modprobe.d/nvidia.conf
  fi

  # Additional for GRUB users
  if [ -f /etc/default/grub ]; then
      if ! sudo grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
          sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia-drm.modeset=1"/' /etc/default/grub
          echo "nvidia-drm.modeset=1 added to /etc/default/grub"
      fi
      if ! sudo grep -q "nvidia_drm.fbdev=1" /etc/default/grub; then
          sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia_drm.fbdev=1"/' /etc/default/grub
          echo "nvidia_drm.fbdev=1 added to /etc/default/grub"
      fi
      sudo grub-mkconfig -o /boot/grub/grub.cfg
  else
      echo "/etc/default/grub does not exist"
  fi

  # Blacklist nouveau
  if [[ -z $blacklist_nouveau ]]; then
    read -n1 -rep "Would you like to blacklist nouveau? (y/n)" blacklist_nouveau
  fi
  echo
  if [[ $blacklist_nouveau =~ ^[Yy]$ ]]; then
    NOUVEAU="/etc/modprobe.d/nouveau.conf"
    if [ -f "$NOUVEAU" ]; then
      echo "Seems like nouveau is already blacklisted..moving on."
    else
      echo "blacklist nouveau" | sudo tee -a "$NOUVEAU"
      if [ -f "/etc/modprobe.d/blacklist.conf" ]; then
        echo "install nouveau /bin/true" | sudo tee -a "/etc/modprobe.d/blacklist.conf"
      else
        echo "install nouveau /bin/true" | sudo tee "/etc/modprobe.d/blacklist.conf"
      fi
    fi
  else
    echo "Skipping nouveau blacklisting."
  fi
fi

read -p 'Do you want to install ASUS ROG packages? (y/N) ' confirmation
confirmation=$(echo "$confirmation" | tr '[:lower:]' '[:upper:]')
if [[ "$confirmation" == 'Y' ]] || [[ "$confirmation" == '' ]]; then
  echo "Installing ASUS ROG packages..."
  for ASUS in power-profiles-daemon asusctl supergfxctl rog-control-center; do
    install_aur_package "$ASUS"
    if [ $? -ne 0 ]; then
      echo "$ASUS package installation failed. Please check manually."
      exit 1
    fi
  done

  echo "Activating ROG services..."
  sudo systemctl enable supergfxd

  echo "Enabling power-profiles-daemon..."
  sudo systemctl enable power-profiles-daemon

  echo "Installation and activation ROG Package & Servicecompleted."
fi

# Final message
echo "All packages installed successfully."

# Install zsh plugin
if [[ ! -d $HOME/.oh-my-zsh ]]; then
  export CHSH='yes'
  export RUNZSH='no'
  export KEEP_ZSHRC='yes'
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  # Install zsh-autosuggestions and zsh-syntax-highlighting
  echo -e "\n\nClone zsh-autosuggestion and zsh-syntax-highlighting\n\n"
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# Install sddm
if ! pacman -Q sddm &>/dev/null; then
  read -p 'Install sddm? (Y/n) ' instSDDM
  instSDDM=$(echo "$instSDDM" | tr '[:lower:]' '[:upper:]')
  if [[ "$instSDDM" == 'Y' ]] || [[ "$instSDDM" == '' ]]; then
    echo 'Installing sddm...'
    sudo pacman "${pacArgs[@]}" -S sddm
    sudo systemctl enable sddm.service
  fi
else
  echo "sddm is already installed."
fi


# start services
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth.service
sudo systemctl start NetworkManager
sudo systemctl start bluetooth.service

# Set open in terminal in nemo
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty

# Copy config
copy_config() {
    echo "→ Copying subdirectories from $1 to $2..."
    for dir in "$1"/*/; do
        if [ -d "$dir" ]; then
            dest_dir="$2/$(basename "$dir")"
            if [ -d "$dest_dir" ]; then
                echo "! Destination directory $dest_dir exists. Removing it..."
                rm -rf "$dest_dir"
                echo "✓ Old directory removed."
            fi
            cp -r "$dir" "$2"
            echo "✓ Copied directory: $dest_dir"
        fi
    done

    if [ $? -eq 0 ]; then
        echo "✓ Directories copied successfully."
    else
        echo "✗ ERROR: Failed to copy directories!"
        return 1
    fi
}

copy_config ".config" "$HOME/.config"
cp -r bin "$HOME"
cp -r .icons "$HOME"
cp -r .themes "$HOME"
cp .gtkrc-2.0 "$HOME"
cp -r wallpaper "$HOME"
sudo cp -r sddm_theme/catppuccin-mocha /usr/share/sddm/themes/
sudo cp sddm_theme/sddm.conf /etc/
chsh -s $(which zsh)
cp .zshrc-default $HOME/.zshrc

echo 'Installation complete!'