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
