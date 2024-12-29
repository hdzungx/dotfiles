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
cp .zshrc-default $HOME/.zshrc
cp -r ./.local $HOME

echo 'Update complete!'
hyprctl reload
