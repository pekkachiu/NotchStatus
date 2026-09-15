#!/bin/bash
# 錄 README demo 用：用假的專案名稱，依序播放 NotchStatus 的各種狀態。
#
# 用法（在 repo 根目錄）：
#   ./scripts/demo.sh             有瀏海的樣子
#   ./scripts/demo.sh --no-notch  沒有瀏海時的浮動膠囊
#   加上 --yes 可跳過「按 Enter 開始」
#
# 執行期間會暫停正在跑的正式版（避免真實 session 入鏡），結束或按 Ctrl+C 後自動重開同一個 App。
set -euo pipefail
cd "$(dirname "$0")/.."

APP="$PWD/NotchStatus/NotchStatus.app/Contents/MacOS/NotchStatus"
FORCE_NO_NOTCH=""
ASK=true
for arg in "$@"; do
  case "$arg" in
    --no-notch) FORCE_NO_NOTCH=1 ;;
    --yes) ASK=false ;;
    *) echo "未知參數：$arg" >&2; exit 1 ;;
  esac
done

if [ ! -x "$APP" ]; then
  echo "找不到 $APP，請先執行 NotchStatus/build.sh" >&2
  exit 1
fi

DIR="$(mktemp -d)"

# 暫停正在跑的正式版（不管裝在 /Applications 或 ~/Applications），記下它的位置，結束後重開同一個
running_bundles=()
for pid in $(pgrep -x NotchStatus || true); do
  exe="$(ps -o command= -p "$pid")"
  [ "$exe" = "$APP" ] && continue
  running_bundles+=("${exe%/Contents/MacOS/NotchStatus}")
  kill "$pid"
done

cleanup() {
  pkill -f "$APP" 2> /dev/null || true
  rm -rf "$DIR"
  for bundle in ${running_bundles[@]+"${running_bundles[@]}"}; do
    open "$bundle" || echo "⚠ 無法重新開啟 $bundle，請手動開啟" >&2
  done
}
trap cleanup EXIT

NOTCH_STATE_DIR="$DIR" NOTCH_FORCE_NO_NOTCH="$FORCE_NO_NOTCH" "$APP" > /dev/null 2>&1 &
disown # 結束時由 cleanup 關掉，不要讓 shell 印出 "Terminated"
sleep 1.5

# ts 用遞增計數而不是時間，同一秒內寫入也能保證順序
seq=0
put() { # put <session> <state> <project>
  seq=$((seq + 1))
  printf '{"state":"%s","project":"%s","ts":%d}\n' "$2" "$3" "$seq" > "$DIR/.$1.tmp"
  mv "$DIR/.$1.tmp" "$DIR/$1.json"
}
step() { # step <說明> <秒數>
  printf '▶ %s\n' "$1"
  sleep "$2"
}

if $ASK; then
  read -r -p "開始錄影後按 Enter…"
fi
sleep 1

put a working my-app;       step "處理中（my-app）" 3
put a waiting my-app;       step "等你確認" 3.5
put a working my-app;       step "授權後回到處理中" 2.5
put a done my-app;          step "完成，3 秒後收成灰點" 5
put b working api-server;   step "另一個 session 開始處理（api-server）" 3
printf '▶ 現在把滑鼠移到%s上，展示所有 session 的清單\n' "$([ -n "$FORCE_NO_NOTCH" ] && echo 膠囊 || echo 瀏海)"
sleep 6
put b done api-server;      step "api-server 完成" 5
rm -f "$DIR"/*.json;        step "全部結束，隱藏" 2

echo "✓ demo 結束"
