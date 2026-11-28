#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

INPUT=$(cat)
STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.joai-board.json"
LOG_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/logs"
LOG_FILE="$LOG_DIR/joai-board-hooks.log"
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

TMP_BODY=""
cleanup() {
  if [[ -n "$TMP_BODY" ]]; then
    rm -f "$TMP_BODY"
  fi
}
trap cleanup EXIT

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG_FILE"
}

if [[ ! -f "$STATE_FILE" ]]; then
  echo '{}'
  exit 0
fi

URL=$(jq -r '.url // ""' "$STATE_FILE" 2>/dev/null || echo "")
SECRET=$(jq -r '.secret // ""' "$STATE_FILE" 2>/dev/null || echo "")
PROVIDER=$(jq -r '.provider // "anthropic"' "$STATE_FILE" 2>/dev/null || echo "anthropic")

if [[ -z "$URL" || -z "$SECRET" ]]; then
  log "State file exists but url/secret missing"
  echo '{}'
  exit 0
fi

if [[ ! "$URL" =~ ^https://[^[:space:]]+/webhooks/items/[^[:space:]]+/agents/[[:alnum:]_-]+$ ]]; then
  log "Invalid callback URL format in state file"
  echo '{}'
  exit 0
fi

HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo "Stop")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
LAST_MESSAGE=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' 2>/dev/null || echo "")
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
REQ_ID="claude-${SESSION_ID}-$(date +%s%N)"

PAYLOAD=$(jq -n \
  --arg hook_event_name "$HOOK_EVENT" \
  --arg last_assistant_message "$LAST_MESSAGE" \
  --arg runId "$SESSION_ID" \
  --arg provider "$PROVIDER" \
  --argjson stop_hook_active "$STOP_ACTIVE" \
  '{
    hook_event_name:$hook_event_name,
    last_assistant_message:$last_assistant_message,
    stop_hook_active:$stop_hook_active,
    runId:$runId,
    provider:$provider
  }')

TMP_BODY=$(mktemp)
HTTP_CODE=$(curl -sS -o "$TMP_BODY" -w "%{http_code}" \
  -X POST "$URL" \
  -H "Authorization: Bearer $SECRET" \
  -H "Content-Type: application/json" \
  -H "X-JoAi-Request-Id: $REQ_ID" \
  --connect-timeout 5 \
  --max-time 12 \
  --data "$PAYLOAD" || true)

if [[ ! "$HTTP_CODE" =~ ^2 ]]; then
  log "Callback failed http=$HTTP_CODE url=$URL"
  echo '{}'
  exit 0
fi

if ! jq -e . "$TMP_BODY" >/dev/null 2>&1; then
  log "Callback returned non-json"
  echo '{}'
  exit 0
fi

if jq -e '.decision == "block"' "$TMP_BODY" >/dev/null 2>&1; then
  jq '{decision, reason, systemMessage, additionalContext}' "$TMP_BODY"
  exit 0
fi

if jq -e '.data.nextAction == "iterate"' "$TMP_BODY" >/dev/null 2>&1; then
  jq -n '{decision:"block", reason:"Continue working on the board and report status again when you stop."}'
  exit 0
fi

echo '{}'
