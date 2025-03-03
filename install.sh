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
    btop fastfetch lsd bat tree parallel brightnessctl usbutils 

    # Notification & Clipboard
    libnotify clipnotify cliphist dunst 

    # Shell & Terminal
    zsh starship kitty tmux cowsay ranger micro neovim 

    # Audio & Bluetooth
    pipewire pipewire-pulse pipewire-audio pipewire-jack pipewire-alsa wireplumber 
    pavucontrol pamixer python-pyalsa 
    blueman bluez bluez-utils 

    # Fonts
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd ttf-fira-code ttf-iosevka-nerd 
    ttf-hack-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra 

    # Input Method (fcitx5)
    fcitx5 fcitx5-qt fcitx5-gtk fcitx5-unikey 

    # Development Tools
    automake fakeroot gcc git cmake clang make shellcheck uthash gzip dpkg 

    # Media & Graphics
    ffmpeg ffmpegthumbnailer imagemagick vlc loupe 

    # Network & SSH
    openssh sshfs wget netctl openvpn networkmanager networkmanager-openvpn gnome-disk-utility 

    # Arch Linux & AUR Support
    sudo fakeroot 

    # Compression & File Management
    zip unzip p7zip unrar ark gparted nemo gvfs 

    # XDG & Desktop Portal
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr xdg-desktop-portal-hyprland 

    # Wayland & Hyprland
    hyprland waybar swaybg wl-clipboard hypridle wmname qt5-wayland qt6-wayland 

    # Display Manager
    sddm 

    # NVIDIA Drivers & Vulkan
    nvidia-dkms nvidia-utils nvidia-settings vulkan-icd-loader 
    opencl-nvidia libxnvctrl 

    # Theming & UI
    papirus-icon-theme zenity qt5ct qt6ct qt5-graphicaleffects qt5-svg qt5-quickcontrols2 

    # Power Management
    upower udiskie 

    # Backup & Restore
    timeshift 

    # PDF & Document Viewers
    evince zathura-pdf-poppler 

    # Miscellaneous
    mat2 playerctl redshift rofimoji wmname polkit-gnome pyenv
)

# AUR Packages
aur_packages=(
    # Package Management
    update-grub  

    # Shell & Launcher  
    rofi-lbonn-wayland-git  

    # Fonts  
    ttf-meslo-nerd-font-powerlevel10k  

    # Development Tools  
    visual-studio-code-bin  

    # Media & Graphics  
    flameshot-git yt-dlp  

    # Theming & UI  
    bibata-cursor-theme-bin tela-circle-icon-theme-dracula  

    # Wayland & Hyprland  
    hyprpicker swaylock-effects-git wlr-randr-git hyprprop grimblast-git wlogout

    # Misc tools
    cava cmatrix-git peaclock pipes.sh obsidian
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

# Final message
echo "All packages installed successfully."

# start services
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth.service
sudo systemctl start NetworkManager
sudo systemctl start bluetooth.service
sudo systemctl enable sddm.service

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

# Set open in terminal in nemo
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty

# Grub theme
sudo cp -r grub/* /usr/share/grub/themes/
sudo sed -i 's|^[#]*GRUB_THEME=.*|GRUB_THEME="/usr/share/grub/themes/catppuccin-mocha-grub-theme/theme.txt"|' /etc/default/grub
sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

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
