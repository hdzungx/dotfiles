#!/bin/bash
set -euo pipefail
trap 'echo "Error on line $LINENO. See ~/post-install.log" >&2' ERR

[[ $EUID -ne 0 ]] || { echo "Run this as a normal user, not root." >&2; exit 1; }
getent hosts aur.archlinux.org >/dev/null || { echo "No network. Connect first (e.g. nmtui)." >&2; exit 1; }

exec > >(tee -a "$HOME/post-install.log") 2>&1

PARU_OPTS=(--needed --noconfirm --skipreview)
FAILED=()

sudo -v
( while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done ) &
KEEPALIVE=$!
trap 'kill "$KEEPALIVE" 2>/dev/null || true' EXIT

install_pkgs() {
    paru -S "${PARU_OPTS[@]}" "$@" && return 0
    echo "Batch failed, retrying one by one..." >&2
    local pkg
    for pkg in "$@"; do
        paru -S "${PARU_OPTS[@]}" "$pkg" || FAILED+=("$pkg")
    done
}

sudo sed -i 's/^#Color/Color/; s/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
export MAKEFLAGS="-j$(nproc)"
sudo pacman -Syu --noconfirm

paru_ok() { command -v paru >/dev/null && paru --version >/dev/null 2>&1; }

if ! paru_ok; then
    { pacman -Qq paru-bin paru-bin-debug 2>/dev/null || true; } | xargs -r sudo pacman -Rns --noconfirm
    sudo pacman -S --needed --noconfirm base-devel git pciutils
    tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi
paru_ok || { echo "paru is not working after install; aborting." >&2; exit 1; }

GPU_PKGS=(linux-headers mesa)
HAS_NVIDIA=0

if ! command -v lspci >/dev/null; then
    sudo pacman -S --needed --noconfirm pciutils
fi

if lspci | grep -iE 'vga|3d|display' | grep -iq 'intel'; then
    GPU_PKGS+=(vulkan-intel intel-media-driver)
fi

if lspci | grep -iE 'vga|3d|display' | grep -iq 'amd'; then
    GPU_PKGS+=(vulkan-radeon libva-mesa-driver)
fi

if lspci | grep -iE 'vga|3d|display' | grep -iq 'nvidia'; then
    GPU_PKGS+=(nvidia-dkms nvidia-utils)
    HAS_NVIDIA=1
fi

PKGS=(
    "${GPU_PKGS[@]}"

    bluez bluez-utils pipewire pipewire-pulse pipewire-alsa wireplumber
    pamixer pavucontrol brightnessctl

    ly niri xwayland-satellite rofi waybar mako polkit-gnome awww
    swaylock swayidle wl-clipboard
    xdg-desktop-portal-gtk

    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji
    fcitx5-im fcitx5-chinese-addons fcitx5-lotus

    kitty zsh-autosuggestions zsh-syntax-highlighting starship fastfetch btop
    yazi lazygit ripgrep fd fzf stow

    matugen-bin adw-gtk-theme qt5ct qt6ct kvantum kvantum-qt5 dconf

    thunar gvfs gvfs-mtp thunar-volman tumbler firefox telegram-desktop visual-studio-code-bin

    android-tools android-udev
)
install_pkgs "${PKGS[@]}"

sudo usermod -aG uucp,lock "$USER"
getent group adbusers >/dev/null && sudo usermod -aG adbusers "$USER"
sudo systemctl enable --now bluetooth
sudo systemctl enable ly@tty1.service

if [[ $HAS_NVIDIA -eq 1 ]]; then
    echo -e "\n--- CONFIGURING NVIDIA KMS & WAYLAND ---"
    sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
    sudo mkinitcpio -P

    if ! grep -q "GBM_BACKEND=nvidia-drm" /etc/environment; then
        sudo tee -a /etc/environment > /dev/null << 'EOF'

XDG_SESSION_TYPE=wayland
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
WLR_NO_HARDWARE_CURSORS=1
EOF
    fi

    if [[ -d /boot/loader/entries ]]; then
        for conf in /boot/loader/entries/*.conf; do
            if grep -q "^options" "$conf" && ! grep -q "nvidia-drm.modeset=1" "$conf"; then
                sudo sed -i 's/^options.*/& nvidia-drm.modeset=1 nvidia-drm.fbdev=1/' "$conf"
            fi
        done
    fi

    if [[ -f /etc/default/grub ]]; then
        if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 nvidia-drm.fbdev=1 /' /etc/default/grub
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
    fi
fi

echo -e "\n--- LINKING DOTFILES ---"

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p ~/.config/{rofi,yazi,nvim/lua,btop/themes,mako,niri,kitty,gtk-3.0,gtk-4.0,matugen/templates,waybar}
mkdir -p ~/.local/bin

stamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$HOME/dotfiles_backup/$stamp"

while IFS= read -r -d '' f; do
    rel_path="${f#"$DOT"/}"
    target="$HOME/$rel_path"
    
    if [[ -e $target || -L $target ]] && [[ $(readlink -f "$target") != "$(readlink -f "$f")" ]]; then
        mkdir -p "$(dirname "$backup_dir/$rel_path")"
        mv "$target" "$backup_dir/$rel_path"
        echo "Backed up conflict: $target -> $backup_dir/$rel_path"
    fi
done < <(find "$DOT" -type f -not -path "*/\.git/*" -print0)

cd "$DOT"

chmod +x .local/bin/*.sh 2>/dev/null || true

stow --no-folding -t ~ .

if [[ -f ~/.config/niri/config.kdl ]]; then
    niri validate -c ~/.config/niri/config.kdl || echo "WARNING: niri config has errors."
else
    echo "WARNING: niri config not found or linking failed."
fi

echo -e "\n--- APPLYING SYSTEM SETTINGS ---"

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true

WALLPAPER_FILE="$HOME/Wallpapers/default.jpg"

if [[ -f "$WALLPAPER_FILE" ]]; then
    echo "Found wallpaper at $WALLPAPER_FILE. Generating Matugen theme..."
    matugen image "$WALLPAPER_FILE" -m dark --source-color-index 0 > /dev/null 2>&1
else
    echo "WARNING: $WALLPAPER_FILE not found. Please check your stow structure."
fi

pkill -SIGUSR2 waybar || true
pkill -SIGUSR1 kitty || true
pkill -SIGUSR2 mako || true

echo
if ((${#FAILED[@]})); then
    echo "These packages failed to install: ${FAILED[*]}"
    echo "Retry later with: paru -S ${FAILED[*]}"
fi
echo "Done."
