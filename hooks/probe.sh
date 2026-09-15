#!/bin/bash
# Phase 0 probe：記錄 hook 事件，驗證觸發時機與 payload 格式
input=$(cat)
echo "$(date +%T) $(jq -r '.hook_event_name' <<<"$input") [$(jq -r '.notification_type // .reason // ""' <<<"$input")] $(jq -r '.message // ""' <<<"$input")" \
  >> ~/.claude/notch/probe.log
# 原始 payload，用來確認實際欄位（文件未完整記載 Notification 的 schema）
jq -c --arg t "$(date +%T)" '{t:$t} + .' <<<"$input" >> ~/.claude/notch/probe.jsonl
exit 0
