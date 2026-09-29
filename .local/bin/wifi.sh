#!/bin/bash

SESSION_TYPE="$XDG_SESSION_TYPE"
ENABLED_COLOR=""
DISABLED_COLOR=""
SIGNAL_ICONS=("󰤟" "󰤢" "󰤥" "󰤨")
SECURED_SIGNAL_ICONS=("󰤡" "󰤤" "󰤧" "󰤪")
WIFI_CONNECTED_ICON="󰄬"

get_wifi_interface() {
    local interface=$(nmcli -t -f DEVICE,TYPE device status | grep ':wifi$' | cut -d: -f1 | head -n 1)
    if [ -z "$interface" ]; then
        interface=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -n 1)
    fi
    echo "${interface:-wlo1}"
}

WIFI_IFACE=$(get_wifi_interface)

get_status() {
    if nmcli -t -f TYPE,STATE device status | grep 'ethernet:connected' > /dev/null; then
        local status_icon="󰈀"
        local status_color=$ENABLED_COLOR
    elif nmcli -t -f TYPE,STATE device status | grep 'wifi:connected' > /dev/null; then
        local wifi_info=$(nmcli --terse --fields "IN-USE,SIGNAL,SECURITY,SSID" device wifi list --rescan no | grep '\*')
        if [ -n "$wifi_info" ]; then
            IFS=: read -r in_use signal security ssid <<< "$wifi_info"
            local signal_icon="${SIGNAL_ICONS[3]}"
            local signal_level=$((signal / 25))
            
            if [[ "$signal_level" -lt "${#SIGNAL_ICONS[@]}" ]]; then
                signal_icon="${SIGNAL_ICONS[$signal_level]}"
            fi
            if [[ "$security" =~ WPA || "$security" =~ WEP ]]; then
                signal_icon="${SECURED_SIGNAL_ICONS[$signal_level]}"
            fi
            status_icon="$signal_icon"
            local status_color=$ENABLED_COLOR
        else
            status_icon=""
            local status_color=$DISABLED_COLOR
        fi
    else
        status_icon=""
        local status_color=$DISABLED_COLOR
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

manage_wifi() {
    nmcli device wifi rescan >/dev/null 2>&1 &
    sleep 2

    # Sử dụng delimiter chuẩn cho nmcli terse output
    nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no > /tmp/wifi_list.txt

    local ssids=()
    local formatted_ssids=()
    local active_ssid=""

    if [ -f /tmp/wifi_list.txt ]; then
        while IFS=: read -r in_use signal security ssid; do
            [ -z "$ssid" ] && continue
            # Làm sạch dữ liệu nếu có ký tự đặc biệt do định dạng terse
            ssid=$(echo "$ssid" | xargs)
            signal=$(echo "$signal" | xargs)
            [[ -z "$signal" ]] && signal=50

            local signal_icon="${SIGNAL_ICONS[3]}"
            local signal_level=$((signal / 25))
            if [[ "$signal_level" -ge "${#SIGNAL_ICONS[@]}" ]]; then
                signal_level=$((${#SIGNAL_ICONS[@]} - 1))
            fi

            if [[ "$security" =~ WPA || "$security" =~ WEP ]]; then
                signal_icon="${SECURED_SIGNAL_ICONS[$signal_level]}"
            else
                signal_icon="${SIGNAL_ICONS[$signal_level]}"
            fi

            local formatted="$signal_icon   $ssid"
            if [[ "$in_use" =~ [*] ]]; then
                active_ssid="$ssid"
                formatted="$WIFI_CONNECTED_ICON   $ssid  (Connected)"
            fi
            
            if [[ ! " ${ssids[@]} " =~ " ${ssid} " ]]; then
                ssids+=("$ssid")
                formatted_ssids+=("$formatted")
            fi
        done < /tmp/wifi_list.txt
    fi

    if [ ${#formatted_ssids[@]} -eq 0 ]; then
        formatted_ssids+=("󱧘   No networks found")
    fi

    local formatted_list=""
    for formatted_ssid in "${formatted_ssids[@]}"; do
        formatted_list+="$formatted_ssid\n"
    done

    local chosen_network=$(echo -e "$formatted_list" | rofi -dmenu -p "󰖩  Wi-Fi")
    
    if [ -z "$chosen_network" ] || [[ "$chosen_network" == *"No networks found"* ]]; then
        rm -f /tmp/wifi_list.txt
        return
    fi

    local chosen_id=""
    for ssid in "${ssids[@]}"; do
        if [[ "$chosen_network" == *"$ssid"* ]]; then
            chosen_id="$ssid"
            break
        fi
    done

    if [ -z "$chosen_id" ]; then
        rm -f /tmp/wifi_list.txt
        return
    else
        local action
        if [[ "$chosen_id" == "$active_ssid" ]]; then
            action="   Disconnect"
        else
            action="󰸋   Connect"
        fi

        action=$(echo -e "$action\n   Forget Network" | rofi -dmenu -p "   [$chosen_id]")
        case $action in
            *"Connect"*)
                local success_message="Connected to \"$chosen_id\"."
                local saved_connections=$(nmcli -g NAME connection show)
                if [[ $(echo "$saved_connections" | grep -Fx "$chosen_id") ]]; then
                    nmcli connection up id "$chosen_id" | grep "successfully" && notify-send "Wi-Fi" "$success_message"
                else
                    local wifi_password=$(rofi -dmenu -password -p "󰌾  Password")
                    if [ -n "$wifi_password" ]; then
                        nmcli device wifi connect "$chosen_id" password "$wifi_password" | grep "successfully" && notify-send "Wi-Fi" "$success_message"
                    fi
                fi
                ;;
            *"Disconnect"*)
                nmcli device disconnect "$WIFI_IFACE" && notify-send "Wi-Fi" "Disconnected from $chosen_id."
                ;;
            *"Forget"*)
                nmcli connection delete id "$chosen_id" && notify-send "Wi-Fi" "Forgot network $chosen_id."
                ;;
        esac
    fi

    rm -f /tmp/wifi_list.txt
}

manage_ethernet() {
    local eth_devices=$(nmcli device status | grep ethernet | awk '{print $1}')
    if [ -z "$eth_devices" ]; then
        notify-send "Ethernet" "No interface found."
        return
    fi

    local eth_list=""
    for dev in $eth_devices; do
        local dev_status=$(nmcli device status | grep "$dev" | awk '{print $3}')
        if [ "$dev_status" = "connected" ]; then
            eth_list+="󰄬   $dev  (Connected)\n"
        else
            eth_list+="󰌙   $dev  (Disconnected)\n"
        fi
    done

    local chosen_device=$(echo -e "$eth_list" | rofi -dmenu -p "󰈀  Ethernet")

    if [ -z "$chosen_device" ]; then
        return
    fi

    chosen_device=$(echo "$chosen_device" | awk '{print $2}')
    local device_status=$(nmcli device status | grep "$chosen_device" | awk '{print $3}')

    if [ "$device_status" = "connected" ]; then
        nmcli device disconnect "$chosen_device" && notify-send "Ethernet" "Disconnected from $chosen_device."
    elif [ "$device_status" = "disconnected" ]; then
        nmcli device connect "$chosen_device" && notify-send "Ethernet" "Connected to $chosen_device."
    fi
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

    if ! pgrep -x "NetworkManager" > /dev/null; then
        local password=$(rofi -dmenu -password -p "Root Password")
        echo "$password" | sudo -S systemctl start NetworkManager
    fi

    local wifi_status=$(nmcli -fields WIFI g)
    local wifi_toggle
    if [[ "$wifi_status" =~ "enabled" ]]; then
        wifi_toggle="󱛅   Disable Wi-Fi"
        wifi_toggle_command="off"
        manage_wifi_btn="\n󱓥   Manage Wi-Fi Networks"
    else
        wifi_toggle="󱚽   Enable Wi-Fi"
        wifi_toggle_command="on"
        manage_wifi_btn=""
    fi

    local chosen_option=$(echo -e "$wifi_toggle$manage_wifi_btn\n󰈀   Manage Ethernet" | rofi -dmenu -p "󰤨   Network")
    case $chosen_option in
        *"Disable Wi-Fi"*|*"Enable Wi-Fi"*)
            nmcli radio wifi $wifi_toggle_command
            notify-send "Wi-Fi" "Radio turned $wifi_toggle_command."
            ;;
        *"Manage Wi-Fi Networks"*)
            manage_wifi
            ;;
        *"Manage Ethernet"*)
            manage_ethernet
            ;;
    esac
}

main_menu "$@"