#!/bin/bash
# swift build 後手動組 .app bundle（沒有 Xcode，只用 CLT + SPM）
# 用法：./build.sh            只建置到 ./NotchStatus.app
#       ./build.sh --install  建置後安裝到 ~/Applications 並啟動（會自動註冊開機啟動）
set -euo pipefail
cd "$(dirname "$0")"

APP="NotchStatus.app"
INSTALL_DIR="$HOME/Applications"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/NotchStatus" "$APP/Contents/MacOS/NotchStatus"
cp Info.plist "$APP/Contents/Info.plist"
# 圖示；要改設計請改 Icon/draw-icon.swift 後執行 ./Icon/make-icon.sh
cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# ad-hoc 簽章，讓 bundle 的簽章包含 Info.plist
codesign --force --sign - "$APP"

echo "Built $PWD/$APP"

if [ "${1:-}" = "--install" ]; then
  pkill -x NotchStatus || true
  mkdir -p "$INSTALL_DIR"
  rm -rf "${INSTALL_DIR:?}/$APP"
  ditto "$APP" "$INSTALL_DIR/$APP"
  # 更新修改時間，讓 Finder 重新讀取圖示
  touch "$INSTALL_DIR/$APP"
  open "$INSTALL_DIR/$APP"
  echo "Installed and launched $INSTALL_DIR/$APP"
fi
