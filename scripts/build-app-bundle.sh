#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION" >&2

BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
APP_DIR="$BIN_DIR/sp-ice-db.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/sp-ice-db" "$MACOS_DIR/sp-ice-db"
cp "$ROOT_DIR/Resources/macOS/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/sp-ice-db"

printf '%s\n' "$APP_DIR"
