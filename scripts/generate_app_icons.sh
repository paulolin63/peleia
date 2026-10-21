#!/bin/bash
# ============================================================
#  scripts/generate_app_icons.sh
#  Generates Android & Web launcher icons from a base PNG icon
# ============================================================
set -e

SRC_IMG="$1"
if [ -z "$SRC_IMG" ] || [ ! -f "$SRC_IMG" ]; then
  echo "Usage: ./scripts/generate_app_icons.sh <path-to-source-icon.png>"
  exit 1
fi

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RES_DIR="$BASE_DIR/android/app/src/main/res"
WEB_DIR="$BASE_DIR/web"
ASSETS_DIR="$BASE_DIR/assets/icons"

echo "🎨 Generating app icons from $SRC_IMG..."

mkdir -p "$ASSETS_DIR"
cp "$SRC_IMG" "$ASSETS_DIR/app_icon.png"

# Android mipmap icons
mkdir -p "$RES_DIR/mipmap-mdpi"
mkdir -p "$RES_DIR/mipmap-hdpi"
mkdir -p "$RES_DIR/mipmap-xhdpi"
mkdir -p "$RES_DIR/mipmap-xxhdpi"
mkdir -p "$RES_DIR/mipmap-xxxhdpi"

sips -s format png -z 48 48   "$SRC_IMG" --out "$RES_DIR/mipmap-mdpi/ic_launcher.png" > /dev/null
sips -s format png -z 72 72   "$SRC_IMG" --out "$RES_DIR/mipmap-hdpi/ic_launcher.png" > /dev/null
sips -s format png -z 96 96   "$SRC_IMG" --out "$RES_DIR/mipmap-xhdpi/ic_launcher.png" > /dev/null
sips -s format png -z 144 144 "$SRC_IMG" --out "$RES_DIR/mipmap-xxhdpi/ic_launcher.png" > /dev/null
sips -s format png -z 192 192 "$SRC_IMG" --out "$RES_DIR/mipmap-xxxhdpi/ic_launcher.png" > /dev/null

# Web icons
sips -s format png -z 32 32   "$SRC_IMG" --out "$WEB_DIR/favicon.png" > /dev/null
sips -s format png -z 192 192 "$SRC_IMG" --out "$WEB_DIR/icons/Icon-192.png" > /dev/null
sips -s format png -z 512 512 "$SRC_IMG" --out "$WEB_DIR/icons/Icon-512.png" > /dev/null
sips -s format png -z 192 192 "$SRC_IMG" --out "$WEB_DIR/icons/Icon-maskable-192.png" > /dev/null
sips -s format png -z 512 512 "$SRC_IMG" --out "$WEB_DIR/icons/Icon-maskable-512.png" > /dev/null

echo "✅ All Android and Web launcher icons successfully created!"
