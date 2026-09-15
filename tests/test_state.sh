#!/bin/bash
# hooks/state.sh 的測試。用暫存 HOME 隔離，不會動到真正的 ~/.claude/notch/state
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/hooks/state.sh"
export HOME="$(mktemp -d)"
trap 'rm -rf "$HOME"' EXIT
STATE_DIR="$HOME/.claude/notch/state"
pass=0; fail=0

check() { # check <描述> <實際> <預期>
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 — got '$2', want '$3'"; fi
}

run() { # run <session_id> <cwd> <state>；回傳 exit code
  jq -nc --arg s "$1" --arg c "$2" '{session_id:$s, cwd:$c}' | "$SCRIPT" "$3"
}

for s in working waiting idle done; do
  run s1 "/Users/x/proj" "$s"
  check "$s: exit 0" "$?" "0"
  check "$s: state 欄位" "$(jq -r .state "$STATE_DIR/s1.json")" "$s"
done

check "project 取 cwd 的 basename" "$(jq -r .project "$STATE_DIR/s1.json")" "proj"
check "ts 是數字" "$(jq -r '.ts | type' "$STATE_DIR/s1.json")" "number"

run s2 "/Users/x/my project" working
check "cwd 含空白" "$(jq -r .project "$STATE_DIR/s2.json")" "my project"
check "多 session 各自一個檔案" "$(ls "$STATE_DIR" | wc -l | tr -d ' ')" "2"

run s1 "/Users/x/proj" end
check "end: exit 0" "$?" "0"
check "end: 刪除該 session 檔案" "$([ -e "$STATE_DIR/s1.json" ] && echo yes || echo no)" "no"
check "end: 不影響其他 session" "$([ -e "$STATE_DIR/s2.json" ] && echo yes || echo no)" "yes"

run ghost "/tmp" end
check "end: 檔案不存在也 exit 0" "$?" "0"

check "不留下暫存檔" "$(ls -A "$STATE_DIR" | grep -c '\.tmp$')" "0"

# pid：往上找名為 claude 的祖先行程。用一個叫 claude 的 bash 當假的 Claude Code 來執行 state.sh
FAKE_CLAUDE="$HOME/bin/claude"
mkdir -p "$HOME/bin" && ln -s /bin/bash "$FAKE_CLAUDE"
fake_pid=$("$FAKE_CLAUDE" -c 'jq -nc "{session_id:\"p1\", cwd:\"/tmp\"}" | "$1" working; echo $$' _ "$SCRIPT")
check "pid 是祖先 claude 行程" "$(jq -r .pid "$STATE_DIR/p1.json")" "$fake_pid"
check "pid 是數字" "$(jq -r '.pid | type' "$STATE_DIR/p1.json")" "number"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
