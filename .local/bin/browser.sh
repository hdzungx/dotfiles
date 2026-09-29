#!/usr/bin/env bash

PREDEFINED=(
    "Youtube"
    "YMusic"
    "Facebook"
    "Github"
    "Arch Wiki"
    "Deepseek"
    "GPT"
    "Claude"
    "Gemini"
    "Wikipedia"
    "Dodgers"
)

CHOICE=$(printf '%s\n' "${PREDEFINED[@]}" | rofi \
    -dmenu \
    -p "Search" \
    -i \
    -theme-str '
    window {width: 350px;}
    listview {
        columns: 2;
        lines: 6;
    }
    ' \
    -kb-accept-entry "Return")

[ -z "$CHOICE" ] && exit 0

urlencode() {
    python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

case "$CHOICE" in
"Youtube") firefox "https://www.youtube.com/" ;;
"YMusic") firefox "https://music.youtube.com/" ;;
"Facebook") firefox "https://www.facebook.com/" ;;
"Github") firefox "https://github.com" ;;
"Arch Wiki") firefox "https://wiki.archlinux.org/title/Main_page" ;;
"Deepseek") firefox "https://chat.deepseek.com/" ;;
"GPT") firefox "https://chatgpt.com/" ;;
"Claude") firefox "https://claude.ai/new" ;;
"Gemini") firefox "https://gemini.google.com/app" ;;
"Wikipedia") firefox "https://en.wikipedia.org/wiki/Main_Page" ;;
"Dodgers") firefox "https://www.google.com/search?q=dodgers" ;;
*) firefox "https://www.google.com/search?q=$(urlencode "$CHOICE")" ;;
esac