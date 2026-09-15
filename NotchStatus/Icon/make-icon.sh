#!/bin/bash
# 重新產生 Icon/AppIcon.icns：draw-icon.swift 畫 1024 PNG → sips 縮成各尺寸 → iconutil 打包
# 只有改圖示設計時才需要執行；產生的 AppIcon.icns 有進版控，build.sh 直接使用
set -euo pipefail
cd "$(dirname "$0")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

swift draw-icon.swift "$WORK/icon-1024.png"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done

iconutil -c icns "$ICONSET" -o AppIcon.icns
echo "Generated $PWD/AppIcon.icns"
