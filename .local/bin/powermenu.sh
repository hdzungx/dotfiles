#!/usr/bin/env bash

declare -A DESC=(
    [lock]="Lockscreen"
    [suspend]="Suspend"
    [logout]="Logout"
    [reboot]="Reboot"
    [shutdown]="Shutdown"
)

declare -A ICONS=(
    [lock]="󰌾"
    [suspend]="󰒲"
    [logout]="󰍃"
    [reboot]="󰜉"
    [shutdown]="󰐥"
)

KEYS=("lock" "suspend" "logout" "reboot" "shutdown")
OPTIONS=()

for name in "${KEYS[@]}"; do
    OPTIONS+=("${ICONS[$name]}   ${DESC[$name]}")
done

CHOSEN=$(
    printf '%s\n' "${OPTIONS[@]}" | rofi \
        -dmenu \
        -i \
        -p "Power Menu" \
        -theme-str "
            window {
                width: 260px;
                location: center;
                anchor: center;
                border-radius: 12px;
            }
            mainbox {
                enabled: true;
                children: [ inputbar, listview ];
                padding: 12px;
            }
            inputbar {
                enabled: false;
            }
            listview {
                enabled: true;
                columns: 1;
                lines: ${#KEYS[@]};
                cycle: true;
                dynamic: true;
                scrollbar: false;
                layout: vertical;
                spacing: 6px;
            }
            element {
                enabled: true;
                padding: 10px 12px;
                border-radius: 8px;
            }
            element-text {
                vertical-align: 0.5;
                horizontal-align: 0.0;
                font: \"Sans 11\";
            }
        "
)

[[ -z "$CHOSEN" ]] && exit 0

case "$CHOSEN" in
    *"Lockscreen"*)
        swaylock
        ;;
    *"Suspend"*)
        systemctl suspend
        ;;
    *"Logout"*)
        niri msg action quit --skip-confirmation
        ;;
    *"Reboot"*)
        systemctl reboot
        ;;
    *"Shutdown"*)
        systemctl poweroff
        ;;
    *)
        exit 1
        ;;
esac