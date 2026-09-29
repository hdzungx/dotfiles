#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Wallpapers"
THUMB_SIZE=175
GAMBLING_ICON="applications-games"

if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Error" "Directory $WALLPAPER_DIR does not exist!"
    exit 1
fi

TMPFILE=$(mktemp)

{
    echo "__GAMBLING__"
    find "$WALLPAPER_DIR" -maxdepth 1 \
        \( -type f -o -type l \) \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
        -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" \) |
        sort
} >"$TMPFILE"

COUNT=$(wc -l <"$TMPFILE")

if (( COUNT <= 4 )); then
    COLUMNS=2
elif (( COUNT <= 8 )); then
    COLUMNS=4
elif (( COUNT <= 15 )); then
    COLUMNS=5
else
    COLUMNS=6
fi

LINES=$(( (COUNT + COLUMNS - 1) / COLUMNS ))

INDEX=$(
while read -r filepath; do
    if [[ "$filepath" == "__GAMBLING__" ]]; then
        RANDOM_IMG=$(find "$WALLPAPER_DIR" -maxdepth 1 \( -type f -o -type l \) \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" \) | shuf -n1)
        [[ -L "$RANDOM_IMG" ]] && RANDOM_IMG=$(readlink -f "$RANDOM_IMG")
        printf '🎲 Random\x00icon\x1f%s\n' "${RANDOM_IMG:-$GAMBLING_ICON}"
    else
        real_path="$filepath"
        [[ -L "$real_path" ]] && real_path=$(readlink -f "$real_path")
        printf '%s\x00icon\x1f%s\n' "$(basename "$filepath")" "$real_path"
    fi
done <"$TMPFILE" |
rofi \
    -dmenu \
    -i \
    -show-icons \
    -format i \
    -theme-str "
        window {
            width: 70%;
            location: center;
            anchor: center;
            x-offset: 0;
            y-offset: 0;
        }

        inputbar {
            enabled: false;
        }

        listview {
            columns: $COLUMNS;
            lines: $LINES;
            flow: horizontal;
            layout: vertical;
            spacing: 12px;
            dynamic: true;
            fixed-height: false;
            scrollbar: false;
        }

        element {
            orientation: vertical;
            padding: 8px;
            spacing: 4px;
            border-radius: 8px;
        }

        element-icon {
            size: ${THUMB_SIZE}px;
            border-radius: 8px;
            horizontal-align: 0.5;
        }

        element-text {
            font: \"Sans 10\";
            margin: 4px 0 0 0;
            padding: 0;
            horizontal-align: 0.5;
        }

        element selected {
            border-radius: 10px;
        }
    "
)

[[ -z "$INDEX" ]] && {
    rm -f "$TMPFILE"
    exit 0
}

SELECTED=$(sed -n "$((INDEX + 1))p" "$TMPFILE")
rm -f "$TMPFILE"

[[ -L "$SELECTED" ]] && SELECTED=$(readlink -f "$SELECTED")

if [[ "$SELECTED" == "__GAMBLING__" ]]; then
    SELECTED=$(
        find "$WALLPAPER_DIR" -maxdepth 1 \
            \( -type f -o -type l \) \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
            -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4" \) |
            shuf -n1
    )
    [[ -L "$SELECTED" ]] && SELECTED=$(readlink -f "$SELECTED")
fi

if [[ -f "$SELECTED" ]]; then
    sleep 0.8

    echo "$SELECTED" >"$HOME/.config/wallpaper"
    ln -sf "$SELECTED" "$HOME/.config/wallpaper.lock"

    awww img "$SELECTED" --transition-type center &

    if command -v matugen >/dev/null 2>&1; then
        matugen image "$SELECTED" \
            --source-color-index 0 \
            -t scheme-tonal-spot

        sleep 0.5

        pkill -SIGUSR1 kitty 2>/dev/null || true
        pkill -SIGUSR1 nvim 2>/dev/null || true
        pkill -USR1 btop 2>/dev/null || true
        pkill -SIGUSR1 cava 2>/dev/null || true

        systemctl --user restart xdg-desktop-portal-gtk

        pkill waybar 2>/dev/null || true

        while pgrep -x waybar >/dev/null; do
            sleep 0.1
        done

        nohup waybar >/dev/null 2>&1 &
    fi

    notify-send -a walls "Wallpaper changed" "Applied: $(basename "$SELECTED")"
fi