#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

INPUT=$(cat)
PROJECT_DIR="${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-.}}"
STATE_FILE="${PROJECT_DIR}/.cursor/.joai-board.json"

# Fall back to Claude state file if Cursor one doesn't exist
if [[ ! -f "$STATE_FILE" ]]; then
  STATE_FILE="${PROJECT_DIR}/.claude/.joai-board.json"
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo '{}'
  exit 0
fi

URL=$(jq -r '.url // ""' "$STATE_FILE" 2>/dev/null || echo "")
SECRET=$(jq -r '.secret // ""' "$STATE_FILE" 2>/dev/null || echo "")

if [[ -z "$URL" || -z "$SECRET" ]]; then
  echo '{}'
  exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.conversation_id // .session_id // "unknown"' 2>/dev/null || echo "unknown")
STATUS=$(echo "$INPUT" | jq -r '.status // "completed"' 2>/dev/null || echo "completed")
LOOP_COUNT=$(echo "$INPUT" | jq -r '.loop_count // 0' 2>/dev/null || echo "0")
REQ_ID="cursor-stop-${SESSION_ID}-$(date +%s%N)"

PAYLOAD=$(jq -n \
  --arg hook_event_name "Stop" \
  --arg runId "$SESSION_ID" \
  --arg provider "cursor" \
  --arg status "$STATUS" \
  --argjson loop_count "$LOOP_COUNT" \
  '{
    hook_event_name: $hook_event_name,
    runId: $runId,
    provider: $provider,
    status: $status,
    loop_count: $loop_count
  }')

TMP_BODY=$(mktemp)
cleanup() { rm -f "$TMP_BODY"; }
trap cleanup EXIT

HTTP_CODE=$(curl -sS -o "$TMP_BODY" -w "%{http_code}" \
  -X POST "$URL" \
  -H "Authorization: Bearer $SECRET" \
  -H "Content-Type: application/json" \
  -H "X-JoAi-Request-Id: $REQ_ID" \
  --connect-timeout 5 \
  --max-time 12 \
  --data "$PAYLOAD" || true)

if [[ ! "$HTTP_CODE" =~ ^2 ]]; then
  echo '{}'
  exit 0
fi

# Cursor stop hooks can return a followup_message to continue the agent
if jq -e '.data.nextAction == "iterate"' "$TMP_BODY" >/dev/null 2>&1; then
  jq -n '{ followup_message: "Continue working on the board and report status again when you stop." }'
  exit 0
fi

echo '{}'
