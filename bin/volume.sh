#!/usr/bin/env bash

print_error() {
    echo "Usage: $0 --device <input|output> --action <increase|decrease|toggle> [--status]"
    exit 1
}

notify_vol() {
    vol=$(get_volume)
    notify-send -u low "Volume" "${vol}%"
}

get_volume() {
    if [[ "${srce}" == "--default-source" ]]; then
        pamixer "${srce}" --get-volume
    else
        pamixer --get-volume
    fi
}

print_status() {
    local vol=$(get_volume)
    
    if [[ "${device}" == "output" ]]; then
        if [[ $(pamixer --get-mute) == "true" ]]; then
            local icon="  $vol%"
        elif [[ "$vol" -le 30 ]]; then
            local icon=" $vol%"
        elif [[ "$vol" -le 60 ]]; then
            local icon=" $vol%"
        elif [[ "$vol" -le 80 ]]; then
            local icon="  $vol%"
        else
            local icon="  $vol%" 
        fi
    elif [[ "${device}" == "input" ]]; then
        if [[ $(pamixer "${srce}" --get-mute) == "true" ]]; then
            local icon="  $vol%"
        else
            local icon=" $vol%"
        fi
    fi

    if [[ ("$(pamixer --get-mute)" == "true" && "${device}" == "output") || ("$(pamixer "${srce}" --get-mute)" == "true" && "${device}" == "input") ]]; then
        echo "<span color='#f38ba8'>$icon</span>"
    else
        echo "<span>$icon</span>"
    fi
}

action_volume() {
    case "${action}" in
        increase) 
            pamixer "${srce}" -i 2 
            ;;
        decrease) 
            pamixer "${srce}" -d 2 
            ;;
        toggle) 
            pamixer "${srce}" -t 
            notify_mute 
            exit 0 
            ;;
        *) 
            print_error 
            ;;
    esac
}

notify_mute() {
    if [[ $(pamixer "${srce}" --get-mute) == "true" ]]; then
        notify-send -u low "Muted"
    else
        notify-send -u low "Unmuted"
    fi
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --device) device="$2"; shift ;;
        --action) action="$2"; shift ;;
        --status) status=true ;;
        *) print_error ;;
    esac
    shift
done

case "${device}" in
    input) srce="--default-source" ;;
    output) srce="" ;;
    *) print_error ;;
esac

if [[ -z "${device}" ]]; then
    print_error
fi

if [[ "$status" == true ]]; then
    print_status
    exit 0
fi

if [[ -z "${action}" ]]; then
    print_error
fi

# Execute action
action_volume