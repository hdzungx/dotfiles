#!/usr/bin/env bash

if pidof rofi > /dev/null; then
    pkill rofi
fi

wallpapers_dir="$HOME/wallpaper"

if [ ! -d "$wallpapers_dir" ]; then
    notify-send "Error" "Wallpaper directory not found"
    exit 1
fi

selected_wallpaper=$(find -L "$wallpapers_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) | while read -r file; do
    echo -en "$(basename "${file%.*}")\0icon\x1f$file\n"
done | rofi -dmenu -p " ")

if [ -z "$selected_wallpaper" ]; then
    exit 0
fi

image_fullname_path=$(find -L "$wallpapers_dir" -maxdepth 1 -type f -name "$selected_wallpaper.*" | head -n 1)

if [ -z "$image_fullname_path" ] || [ ! -f "$image_fullname_path" ]; then
    notify-send "Error" "Wallpaper file not found: $selected_wallpaper"
    exit 1
fi

if ! pgrep -x swww-daemon > /dev/null; then
    swww-daemon &
    sleep 2
fi

if swww img "$image_fullname_path" --transition-type any --transition-duration 2; then
    notify-send "Wallpaper Changed" "$selected_wallpaper" -i "$image_fullname_path"
else
    notify-send "Error" "Failed to change wallpaper"
    exit 1
fi

if [ -f ~/.config/scripts/wallpaper_effects.sh ]; then
    ~/.config/scripts/wallpaper_effects.sh
fi