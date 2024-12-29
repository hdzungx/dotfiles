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