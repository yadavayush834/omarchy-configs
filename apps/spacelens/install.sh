#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$DATA_HOME/spacelens"
DESKTOP_DIR="$DATA_HOME/applications"
ICON_DIR="$DATA_HOME/icons/hicolor/scalable/apps"

install -d "$APP_DIR" "$DESKTOP_DIR" "$ICON_DIR"
install -m 755 "$SOURCE_DIR/app.py" "$APP_DIR/app.py"
install -m 644 "$SOURCE_DIR/index.html" "$SOURCE_DIR/style.css" "$SOURCE_DIR/app.js" "$APP_DIR/"
install -m 644 "$SOURCE_DIR/spacelens.svg" "$ICON_DIR/spacelens.svg"

sed "s|@APP_DIR@|$APP_DIR|g" "$SOURCE_DIR/spacelens.desktop.in" > "$DESKTOP_DIR/com.ayush.SpaceLens.desktop"
chmod 755 "$DESKTOP_DIR/com.ayush.SpaceLens.desktop"

command -v update-desktop-database >/dev/null && update-desktop-database "$DESKTOP_DIR" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$DATA_HOME/icons/hicolor" || true

printf 'SpaceLens installed. Open the application launcher and search for SpaceLens Disk Usage.\n'
