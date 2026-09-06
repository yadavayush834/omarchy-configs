#!/usr/bin/env bash
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$DATA_HOME/spacelens"
DESKTOP_FILE="$DATA_HOME/applications/com.ayush.SpaceLens.desktop"
ICON_FILE="$DATA_HOME/icons/hicolor/scalable/apps/spacelens.svg"

rm -r -- "$APP_DIR"
rm -- "$DESKTOP_FILE" "$ICON_FILE"

command -v update-desktop-database >/dev/null && update-desktop-database "$DATA_HOME/applications" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" || true

printf 'SpaceLens uninstalled.\n'
