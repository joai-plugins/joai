#!/usr/bin/env bash
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

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
REQ_ID="$(echo "$INPUT" | jq -r '.request_id // .requestId // empty' 2>/dev/null || echo "")"
if [[ -z "$REQ_ID" ]]; then
  REQ_ID="hook-permission-${SESSION_ID}-$(date +%s%N)"
fi

# Build provider-agnostic payload
PAYLOAD="$(jq -n \
  --arg type "permission.request" \
  --arg provider "anthropic" \
  --arg requestId "$REQ_ID" \
  --arg sessionId "$SESSION_ID" \
  --argjson meta "$(echo "$INPUT" | jq -c '{
    toolName: (.tool_name // null),
    toolInput: (.tool_input // null)
  }' 2>/dev/null || echo '{}')" \
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

# Helper: translate generic decision to Claude hookSpecificOutput format
emit_claude_decision() {
  local decision="$1"
  local reason="$2"

  if [[ "$decision" == "allow" ]]; then
    local updated
    updated="$(echo "$INPUT" | jq -c '[.permission_suggestions[0] // empty] | if length == 0 then null else . end' 2>/dev/null || echo "null")"
    jq -n --argjson updated "$updated" '{
      hookSpecificOutput: {
        hookEventName: "PermissionRequest",
        decision: ({ behavior: "allow" } + (if $updated then { updatedPermissions: $updated } else {} end))
      }
    }'
  else
    jq -n --arg reason "${reason:-Denied in JoAi.}" '{
      hookSpecificOutput: {
        hookEventName: "PermissionRequest",
        decision: { behavior: "deny", message: $reason }
      }
    }'
  fi
}

# 1. POST the permission request (returns immediately)
HTTP_CODE="$(curl -sS -o "$TMP_BODY" -w "%{http_code}" \
  -X POST "$URL" \
  -H "Authorization: Bearer $AUTH_KEY" \
  -H "Content-Type: application/json" \
  -H "X-JoAi-Request-Id: $REQ_ID" \
  --connect-timeout 5 \
  --max-time 10 \
  --data "$PAYLOAD" || true)"

if [[ ! "$HTTP_CODE" =~ ^2 ]]; then
  emit_claude_decision "deny" "JoAi hook routing failed."
  exit 0
fi

# Already resolved (e.g. auto-approved tool or duplicate request)
STATUS="$(jq -r '.status // "pending"' "$TMP_BODY" 2>/dev/null || echo "pending")"
if [[ "$STATUS" != "pending" ]]; then
  DECISION="$(jq -r '.decision // "deny"' "$TMP_BODY" 2>/dev/null || echo "deny")"
  REASON="$(jq -r '.reason // ""' "$TMP_BODY" 2>/dev/null || echo "")"
  emit_claude_decision "$DECISION" "$REASON"
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
  emit_claude_decision "$DECISION" "$REASON"
  exit 0
done

# Timed out
emit_claude_decision "deny" "Permission request timed out in JoAi."
