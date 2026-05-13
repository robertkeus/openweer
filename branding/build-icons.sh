#!/usr/bin/env bash
# Rasterize OpenWeer icons from branding/icon.svg + favicon.svg.
# Requires: rsvg-convert, sips (macOS), npx.
set -euo pipefail

cd "$(dirname "$0")"
REPO_ROOT="$(cd .. && pwd)"

SRC_ICON="icon.svg"
SRC_FAV="favicon.svg"

IOS_ICON="$REPO_ROOT/ios/OpenWeer/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
WEB_PUB="$REPO_ROOT/web/public"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ iOS icon 1024 (opaque)"
rsvg-convert -w 1024 -h 1024 -b "#1f56cc" "$SRC_ICON" -o "$TMP/icon-1024-rgba.png"
# Strip alpha channel: PNG → JPEG → PNG round-trip via sips. iOS rejects icons that have an alpha channel.
sips -s format jpeg "$TMP/icon-1024-rgba.png" --out "$TMP/icon-1024.jpg" >/dev/null
sips -s format png  "$TMP/icon-1024.jpg"      --out "$IOS_ICON"        >/dev/null

echo "→ Web PWA icons 192/512"
rsvg-convert -w 192 -h 192 "$SRC_ICON" -o "$WEB_PUB/icon-192.png"
rsvg-convert -w 512 -h 512 "$SRC_ICON" -o "$WEB_PUB/icon-512.png"

echo "→ Web favicon.svg"
cp "$SRC_FAV" "$WEB_PUB/favicon.svg"

echo "→ favicon.ico (16/32/48)"
rsvg-convert -w 16  -h 16  "$SRC_FAV" -o "$TMP/fav-16.png"
rsvg-convert -w 32  -h 32  "$SRC_FAV" -o "$TMP/fav-32.png"
rsvg-convert -w 48  -h 48  "$SRC_FAV" -o "$TMP/fav-48.png"
npx --yes png-to-ico "$TMP/fav-16.png" "$TMP/fav-32.png" "$TMP/fav-48.png" > "$WEB_PUB/favicon.ico"

echo "✓ Done"
