#!/bin/bash
# NotchStatus 狀態寫入：$1 = working | waiting | idle | done | end
input=$(cat)
sid=$(jq -r '.session_id' <<<"$input")
dir=$(basename "$(jq -r '.cwd' <<<"$input")")
state_dir=~/.claude/notch/state
mkdir -p "$state_dir"

# 往上找 Claude Code 的行程。直接關掉終端機時不會觸發 SessionEnd，
# App 用這個 pid 判斷 session 是否還活著、清掉殘留的狀態檔。找不到就留空。
claude_pid() {
  local p=$PPID comm
  while [ "${p:-0}" -gt 1 ]; do
    comm=$(ps -o comm= -p "$p") || return
    if [ "$(basename "$comm")" = "claude" ]; then
      echo "$p"
      return
    fi
    p=$(ps -o ppid= -p "$p" | tr -d ' ')
  done
}

if [ "$1" = "end" ]; then
  rm -f "$state_dir/$sid.json"
else
  # 先寫暫存檔再 mv（同一檔案系統上是原子操作），避免 App 讀到寫一半的 JSON
  tmp="$state_dir/.$sid.json.tmp"
  jq -nc --arg s "$1" --arg d "$dir" --arg t "$(date +%s)" --arg p "$(claude_pid)" \
    '{state:$s, project:$d, ts:($t|tonumber), pid:(if $p == "" then null else ($p|tonumber) end)}' > "$tmp" \
    && mv -f "$tmp" "$state_dir/$sid.json"
fi
# 必須 exit 0：Stop hook 回傳 2 會讓 Claude 無法停下
exit 0
