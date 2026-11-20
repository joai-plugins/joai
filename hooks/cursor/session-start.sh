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
  API_BASE="${JOAI_API_BASE:-https://api.joai.ai}"
  echo "{\"additional_context\":\"JoAi is installed but hooks are not configured yet. Before doing anything else: (1) call the joai_agent_info MCP tool (no arguments) — it returns {uuid, name, authKey}, (2) write ~/.joai/hooks.json as {\\\"url\\\": \\\"${API_BASE}/agents/<uuid>/hooks\\\", \\\"authKey\\\": \\\"<authKey>\\\", \\\"agentName\\\": \\\"<name>\\\"}, (3) confirm 'Connected to JoAi agent: <name>. Hooks are now active.'\"}"
  exit 0
fi

SESSION_ID="$(echo "$INPUT" | jq -r '.conversation_id // .session_id // null' 2>/dev/null || echo "null")"
REQ_ID="hook-session-start-$(date +%s%N)"

# Build provider-agnostic payload
PAYLOAD="$(jq -n \
  --arg type "session.start" \
  --arg provider "cursor" \
  --arg requestId "$REQ_ID" \
  --arg sessionId "$SESSION_ID" \
  '{
    type: $type,
    provider: $provider,
    requestId: $requestId,
    sessionId: $sessionId
  }')"

TMP_BODY="$(mktemp)"
cleanup() { rm -f "$TMP_BODY"; }
trap cleanup EXIT

HTTP_CODE="$(curl -sS -o "$TMP_BODY" -w "%{http_code}" \
  -X POST "$URL" \
  -H "Authorization: Bearer $AUTH_KEY" \
  -H "Content-Type: application/json" \
  -H "X-JoAi-Request-Id: $REQ_ID" \
  --connect-timeout 5 \
  --max-time 12 \
  --data "$PAYLOAD" || true)"

if [[ ! "$HTTP_CODE" =~ ^2 ]]; then
  echo '{}'
  exit 0
fi

CONTEXT="$(jq -r '.context // ""' "$TMP_BODY" 2>/dev/null || echo "")"
if [[ -z "$CONTEXT" ]]; then
  echo '{}'
  exit 0
fi

# Translate to Cursor session start format
jq -n --arg context "$CONTEXT" '{
  additional_context: $context
}'
