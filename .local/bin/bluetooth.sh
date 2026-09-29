#!/bin/bash

SESSION_TYPE="$XDG_SESSION_TYPE"
ENABLED_COLOR=""
DISABLED_COLOR=""

get_status() {
    local power_state=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')
    local status_icon=""
    local status_color=$DISABLED_COLOR

    if [ "$power_state" = "yes" ]; then
        if bluetoothctl info | grep -q "Connected: yes"; then
            status_icon="󰂱"
        else
            status_icon="󰂯"
        fi
        status_color=$ENABLED_COLOR
    fi

    if [[ -n "$status_color" ]]; then
        if [[ "$SESSION_TYPE" == "wayland" ]]; then
            echo "<span color=\"$status_color\">$status_icon</span>"
        elif [[ "$SESSION_TYPE" == "x11" ]]; then
            echo "%{F$status_color}$status_icon%{F-}"
        fi
    else
        echo "$status_icon"
    fi
}

manage_bluetooth() {
    local power_state=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')
    if [ "$power_state" != "yes" ]; then
        notify-send "Bluetooth" "Bluetooth is powered off."
        return
    fi

    # Bật quét ngầm để tìm thiết bị mới xung quanh
    bluetoothctl scan on >/dev/null 2>&1 &
    local scan_pid=$!

    # Đợi 2 giây để thu thập thiết bị đang phát sóng mà không cần bấm enter
    sleep 2

    # Lấy danh sách thiết bị đã kết nối, đã ghép nối và các thiết bị đang quét được
    local devices_output=$(bluetoothctl devices Connected; bluetoothctl devices Paired; bluetoothctl devices)
    
    # Dừng tiến trình quét sau khi đã lấy đủ dữ liệu
    kill $scan_pid 2>/dev/null
    killall bluetoothctl 2>/dev/null

    local bt_list=""
    local seen_macs=""

    while read -r type mac name; do
        [ -z "$mac" ] && continue
        if [[ "$seen_macs" == *"$mac"* ]]; then
            continue
        fi
        seen_macs+="$mac "

        local info=$(bluetoothctl info "$mac")
        local icon="󰂯"
        local status_str=""

        if echo "$info" | grep -q "Connected: yes"; then
            icon="󰂱"
            status_str=" (Connected)"
        elif echo "$info" | grep -q "Paired: yes"; then
            icon="󰂰"
            status_str=" (Paired)"
        else
            status_str=" (Available)"
        fi

        bt_list+="$icon   $name$status_str [$mac]\n"
    done <<< "$devices_output"

    if [ -z "$bt_list" ]; then
        bt_list="󱧘   No devices found\n"
    fi

    local chosen=$(echo -e "$bt_list" | rofi -dmenu -p "󰂯  Bluetooth")
    
    if [ -z "$chosen" ] || [[ "$chosen" == *"No devices found"* ]]; then
        return
    fi

    local mac=$(echo "$chosen" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
    if [ -z "$mac" ]; then
        return
    fi

    local info=$(bluetoothctl info "$mac")
    local is_connected=false
    local is_paired=false

    echo "$info" | grep -q "Connected: yes" && is_connected=true
    echo "$info" | grep -q "Paired: yes" && is_paired=true

    local action_list=""
    if [ "$is_connected" = true ]; then
        action_list="   Disconnect\n"
    else
        action_list="󰂱   Connect\n"
    fi

    if [ "$is_paired" = true ]; then
        action_list+="   Unpair Device"
    else
        action_list+="󰓜   Pair & Connect"
    fi

    local action=$(echo -e "$action_list" | rofi -dmenu -p "   Device")
    case $action in
        *"Connect"*)
            bluetoothctl connect "$mac" && notify-send "Bluetooth" "Connected to device."
            ;;
        *"Disconnect"*)
            bluetoothctl disconnect "$mac" && notify-send "Bluetooth" "Disconnected from device."
            ;;
        *"Pair & Connect"*)
            bluetoothctl pair "$mac" && bluetoothctl trust "$mac" && bluetoothctl connect "$mac" && notify-send "Bluetooth" "Paired and connected."
            ;;
        *"Unpair"*)
            bluetoothctl remove "$mac" && notify-send "Bluetooth" "Unpaired device."
            ;;
    esac
}

main_menu() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --status)
                status_mode=true
                shift
                ;;
            --enabled-color)
                ENABLED_COLOR="$2"
                shift 2
                ;;
            --disabled-color)
                DISABLED_COLOR="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ $status_mode == true ]]; then
        get_status
        exit 1
    fi

    local power_state=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')
    local bt_toggle
    local bt_toggle_cmd
    local manage_bt_btn=""

    if [ "$power_state" = "yes" ]; then
        bt_toggle="󰂲   Disable Bluetooth"
        bt_toggle_cmd="off"
        manage_bt_btn="\n󰂱   Manage Bluetooth Devices"
    else
        bt_toggle="󰂯   Enable Bluetooth"
        bt_toggle_cmd="on"
        manage_bt_btn=""
    fi

    local chosen_option=$(echo -e "$bt_toggle$manage_bt_btn" | rofi -dmenu -p "󰂯   Bluetooth")
    case $chosen_option in
        *"Disable Bluetooth"*|*"Enable Bluetooth"*)
            bluetoothctl power "$bt_toggle_cmd"
            notify-send "Bluetooth" "Bluetooth turned $bt_toggle_cmd."
            ;;
        *"Manage Bluetooth Devices"*)
            manage_bluetooth
            ;;
    esac
}

main_menu "$@"