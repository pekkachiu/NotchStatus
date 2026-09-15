#!/bin/bash
# swift build 後手動組 .app bundle（沒有 Xcode，只用 CLT + SPM）
# 用法：./build.sh            只建置到 ./NotchStatus.app
#       ./build.sh --install  建置後安裝並啟動（會自動註冊開機啟動）：
#                             已裝在 /Applications 就更新那份，否則裝到 ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="NotchStatus.app"
# 已經裝在哪裡就更新哪裡，避免兩個資料夾各有一份、開機啟動抓到舊的
if [ -d "/Applications/$APP" ]; then
  INSTALL_DIR="/Applications"
else
  INSTALL_DIR="$HOME/Applications"
fi

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
  if [ "$INSTALL_DIR" = "/Applications" ] && [ -d "$HOME/Applications/$APP" ]; then
    echo "⚠ ~/Applications 裡還有一份舊的 $APP，建議刪除：rm -rf ~/Applications/$APP" >&2
  fi
fi
