#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required." >&2
  exit 1
fi

URL="${1:-}"
SECRET="${2:-}"
PROVIDER="${3:-anthropic}"

if [[ -z "$URL" || -z "$SECRET" ]]; then
  echo "Usage: bind-callback.sh <callback-url> <callback-secret> [provider]" >&2
  exit 1
fi

if [[ ! "$URL" =~ ^https://[^[:space:]]+/webhooks/items/[^[:space:]]+/agents/[[:alnum:]_-]+$ ]]; then
  echo "Error: callback URL must be an https URL matching /webhooks/items/{itemHashid}/agents/{agentUuid}" >&2
  exit 1
fi

PROVIDER=$(echo "$PROVIDER" | tr '[:upper:]' '[:lower:]')
case "$PROVIDER" in
  openai|anthropic|gemini|opencode) ;;
  *)
    echo "Error: provider must be one of: openai, anthropic, gemini, opencode" >&2
    exit 1
    ;;
esac

STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude"
STATE_FILE="$STATE_DIR/.joai-board.json"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

jq -n \
  --arg url "$URL" \
  --arg secret "$SECRET" \
  --arg provider "$PROVIDER" \
  --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{url:$url, secret:$secret, provider:$provider, updatedAt:$updatedAt}' > "$STATE_FILE"
chmod 600 "$STATE_FILE"

echo "Bound JoAi board callback to: $URL"
