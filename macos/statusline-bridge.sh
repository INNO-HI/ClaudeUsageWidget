#!/bin/bash
# Claude Code Status Line → Widget Bridge
# Claude Code가 stdin으로 보내주는 JSON을 받아서
# ~/.claude-status.json 에 저장하고, 동시에 status line도 표시
#
# 설치: ~/.claude/settings.json 에 아래 추가
# {
#   "statusLine": {
#     "type": "command",
#     "command": "~/.claude/statusline-bridge.sh"
#   }
# }

input=$(cat)

# 위젯용 JSON 파일로 저장 (권한 600)
OUTPUT_FILE="$HOME/.claude-status.json"
echo "$input" > "$OUTPUT_FILE"
chmod 600 "$OUTPUT_FILE" 2>/dev/null

# 원래 status line 출력 (간단하게 모델명 + 컨텍스트 %)
if command -v jq >/dev/null 2>&1; then
    MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
    PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
    FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
    WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)

    OUT="[$MODEL] ctx:${PCT}%"
    [ -n "$FIVE_H" ] && OUT="$OUT | 5h:${FIVE_H}%"
    [ -n "$WEEK" ] && OUT="$OUT | 7d:${WEEK}%"
    echo "$OUT"
else
    echo "[Claude] (jq not installed)"
fi
