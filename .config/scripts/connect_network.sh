#!/usr/bin/env bash

# Notify starting
notify-send "Scanning available network connections..."

# Detect connection types
wifi_state=$(nmcli -t -f WIFI g)
eth_state=$(nmcli device status | grep ethernet | awk '{print $3}')
vpn_list=$(nmcli -t -f NAME,TYPE connection show | grep vpn | cut -d: -f1)

# Toggle labels
if [[ "$wifi_state" == "enabled" ]]; then
    wifi_toggle="󰖪  Disable Wi-Fi"
else
    wifi_toggle="󰖩  Enable Wi-Fi"
fi

if [[ "$eth_state" == "connected" ]]; then
    eth_status="  Disconnect Ethernet"
else
    eth_status="  Connect Ethernet"
fi

# Wi-Fi list
wifi_list=$(nmcli --fields "SECURITY,SSID" device wifi list \
    | sed 1d \
    | sed 's/  */ /g' \
    | sed -E "s/WPA*.?\S/ /g" \
    | sed "s/^--/ /g" \
    | sed "s/  //g" \
    | sed "/--/d")

# VPN menu entries
vpn_menu=""
if [[ -n "$vpn_list" ]]; then
    while IFS= read -r vpn; do
        vpn_menu+="󰖂  Connect VPN: $vpn\n"
    done <<< "$vpn_list"
fi

# Airplane mode toggle
if [[ "$wifi_state" == "disabled" && "$eth_state" != "connected" ]]; then
    airplane_toggle="󰁇  Disable Airplane Mode"
else
    airplane_toggle="󰁆  Enable Airplane Mode"
fi

# Rofi menu
chosen=$(echo -e "$wifi_toggle\n$eth_status\n$vpn_menu$airplane_toggle\n$wifi_list" \
    | rofi -dmenu -i -selected-row 1 -p "Network Menu: ")

# Action handler
case "$chosen" in
    "󰖩  Enable Wi-Fi") nmcli radio wifi on ;;
    "󰖪  Disable Wi-Fi") nmcli radio wifi off ;;
    "  Connect Ethernet") nmcli device connect $(nmcli device status | grep ethernet | awk '{print $1}') ;;
    "  Disconnect Ethernet") nmcli device disconnect $(nmcli device status | grep ethernet | awk '{print $1}') ;;
    "󰁆  Enable Airplane Mode") nmcli radio all off ;;
    "󰁇  Disable Airplane Mode") nmcli radio all on ;;
    󰖂*) 
        vpn_name=$(echo "$chosen" | sed 's/󰖂  Connect VPN: //')
        nmcli connection up id "$vpn_name"
    ;;
    *)
        # Wi-Fi connection
        read -r ssid <<< "${chosen:3}"
        if [ -z "$ssid" ]; then exit; fi
        saved=$(nmcli -g NAME connection)
        success_msg="Connected to \"$ssid\"."
        if echo "$saved" | grep -wq "$ssid"; then
            nmcli connection up id "$ssid" && notify-send "Connection Established" "$success_msg"
        else
            if [[ "$chosen" =~ "" ]]; then
                password=$(rofi -dmenu -p "Password: ")
            fi
            nmcli device wifi connect "$ssid" password "$password" \
                && notify-send "Connection Established" "$success_msg"
        fi
    ;;
esac
