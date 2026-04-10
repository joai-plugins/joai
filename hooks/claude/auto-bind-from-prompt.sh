#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // .user_prompt // .message // ""' 2>/dev/null || echo "")

if [[ -z "$PROMPT" ]]; then
  echo '{}'
  exit 0
fi

URL=$(echo "$PROMPT" | grep -Eo 'https://[^[:space:]]+/webhooks/items/[^[:space:]]+/agents/[[:alnum:]_-]+' | head -n 1 || true)
SECRET=$(echo "$PROMPT" | grep -Eio 'Authorization:[[:space:]]*Bearer[[:space:]]+[^[:space:]]+' | head -n 1 | awk '{print $NF}' || true)

URL="${URL%%[\`\)\]\}\,\.;:]}"
SECRET="${SECRET%%[\`\)\]\}\,\.;:]}"

if [[ -z "$URL" || -z "$SECRET" ]]; then
  echo '{}'
  exit 0
fi

if [[ ! "$URL" =~ ^https://[^[:space:]]+/webhooks/items/[^[:space:]]+/agents/[[:alnum:]_-]+$ ]]; then
  echo '{}'
  exit 0
fi

STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude"
STATE_FILE="$STATE_DIR/.joai-board.json"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

jq -n \
  --arg url "$URL" \
  --arg secret "$SECRET" \
  --arg provider "anthropic" \
  --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{url:$url, secret:$secret, provider:$provider, updatedAt:$updatedAt}' > "$STATE_FILE"
chmod 600 "$STATE_FILE"

echo '{}'
