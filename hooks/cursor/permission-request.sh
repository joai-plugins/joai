#!/usr/bin/env bash
# Cursor pre-execution hook — handles beforeShellExecution and beforeMCPExecution.
# Forwards permission requests to JoAi for human approval, polls until resolved.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./hook-config.sh
source "$SCRIPT_DIR/hook-config.sh"

INPUT="$(cat)"
URL="$(resolve_agent_hook_url)"
AUTH_KEY="$(resolve_agent_auth_key)"

if [[ -z "$URL" || -z "$AUTH_KEY" ]]; then
  echo '{}'
  exit 0
fi

EVENT_NAME="$(echo "$INPUT" | jq -r '.hook_event_name // ""' 2>/dev/null || echo "")"
SESSION_ID="$(echo "$INPUT" | jq -r '.conversation_id // .session_id // "unknown"' 2>/dev/null || echo "unknown")"

# Tool name and input vary by event type:
# - beforeShellExecution: { command, cwd, sandbox }
# - beforeMCPExecution:   { tool_name, tool_input, url|command }
case "$EVENT_NAME" in
  beforeShellExecution)
    TOOL_NAME="Shell"
    TOOL_INPUT="$(echo "$INPUT" | jq -c '{command: .command, cwd: .cwd, sandbox: .sandbox}' 2>/dev/null || echo 'null')"
    ;;
  beforeMCPExecution)
    TOOL_NAME="MCP:$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")"
    TOOL_INPUT="$(echo "$INPUT" | jq -c '.tool_input // null' 2>/dev/null || echo 'null')"
    ;;
  *)
    TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")"
    TOOL_INPUT="$(echo "$INPUT" | jq -c '.tool_input // null' 2>/dev/null || echo 'null')"
    ;;
esac

REQ_ID="hook-${EVENT_NAME}-${SESSION_ID}-$(date +%s%N)"

PAYLOAD="$(jq -n \
  --arg type "permission.request" \
  --arg provider "cursor" \
  --arg requestId "$REQ_ID" \
  --arg sessionId "$SESSION_ID" \
  --argjson meta "$(jq -n --arg toolName "$TOOL_NAME" --argjson toolInput "$TOOL_INPUT" '{toolName: $toolName, toolInput: $toolInput}')" \
  '{
    type: $type,
    provider: $provider,
    requestId: $requestId,
    sessionId: $sessionId,
    meta: $meta
  }')"

TMP_BODY="$(mktemp)"
cleanup() { rm -f "$TMP_BODY"; }
trap cleanup EXIT

# Translate generic decision to Cursor permission response shape.
# Uses canonical camelCase fields per https://cursor.com/docs/hooks
emit_cursor_decision() {
  local decision="$1"
  local reason="$2"

  if [[ "$decision" == "allow" ]]; then
    jq -n '{permission: "allow"}'
  else
    jq -n --arg reason "${reason:-Denied in JoAi.}" '{
      permission: "deny",
      userMessage: $reason,
      agentMessage: $reason
    }'
  fi
}

# 1. POST the permission request
HTTP_CODE="$(curl -sS -o "$TMP_BODY" -w "%{http_code}" \
  -X POST "$URL" \
  -H "Authorization: Bearer $AUTH_KEY" \
  -H "Content-Type: application/json" \
  -H "X-JoAi-Request-Id: $REQ_ID" \
  --connect-timeout 5 \
  --max-time 10 \
  --data "$PAYLOAD" || true)"

if [[ ! "$HTTP_CODE" =~ ^2 ]]; then
  emit_cursor_decision "deny" "JoAi hook routing failed."
  exit 0
fi

STATUS="$(jq -r '.status // "pending"' "$TMP_BODY" 2>/dev/null || echo "pending")"
if [[ "$STATUS" != "pending" ]]; then
  DECISION="$(jq -r '.decision // "deny"' "$TMP_BODY" 2>/dev/null || echo "deny")"
  REASON="$(jq -r '.reason // ""' "$TMP_BODY" 2>/dev/null || echo "")"
  emit_cursor_decision "$DECISION" "$REASON"
  exit 0
fi

# 2. Poll the public API status endpoint with smooth backoff
API_BASE="$(resolve_api_base)"
POLL_URL="${API_BASE}/v1/hooks/requests/${REQ_ID}/status"
MAX_WAIT=3600
ELAPSED=0
INTERVAL=0

while [[ "$ELAPSED" -lt "$MAX_WAIT" ]]; do
  INTERVAL=$(( INTERVAL + 2 ))
  if [[ "$INTERVAL" -gt 30 ]]; then INTERVAL=30; fi
  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))

  POLL_CODE="$(curl -sS -o "$TMP_BODY" -w "%{http_code}" \
    -X GET "$POLL_URL" \
    -H "X-Agent-Auth-Key: $AUTH_KEY" \
    --connect-timeout 3 \
    --max-time 5 || true)"

  if [[ ! "$POLL_CODE" =~ ^2 ]]; then
    continue
  fi

  POLL_STATUS="$(jq -r '.data.status // "pending"' "$TMP_BODY" 2>/dev/null || echo "pending")"
  if [[ "$POLL_STATUS" == "pending" ]]; then
    continue
  fi

  DECISION="$(jq -r '.data.decision // "deny"' "$TMP_BODY" 2>/dev/null || echo "deny")"
  REASON="$(jq -r '.data.reason // ""' "$TMP_BODY" 2>/dev/null || echo "")"
  emit_cursor_decision "$DECISION" "$REASON"
  exit 0
done

emit_cursor_decision "deny" "Permission request timed out in JoAi."
