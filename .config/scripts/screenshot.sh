#!/usr/bin/env bash
OUTDIR="$HOME/Pictures/Screenshots"
mkdir -p "$OUTDIR"

FILE="$OUTDIR/$(date +'%Y%m%d_%H%M%S').png"

case "$1" in
  region) grim -g "$(slurp)" "$FILE" ;;
  fullscreen) grim "$FILE" ;;
  *) echo "Usage: $0 {region|fullscreen}" ; exit 1 ;;
esac

wl-copy < "$FILE"
notify-send "Screenshot saved" "$FILE"
