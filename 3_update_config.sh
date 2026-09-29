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