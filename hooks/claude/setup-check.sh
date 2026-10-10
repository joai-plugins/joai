#!/usr/bin/env bash
# Fires on UserPromptSubmit. If ~/.joai/hooks.json is missing, instructs Claude
# to call joai_agent_info and write the local hook config.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./hook-config.sh
source "$SCRIPT_DIR/hook-config.sh"

URL="$(resolve_agent_hook_url)"
AUTH_KEY="$(resolve_agent_auth_key)"

if [[ -n "$URL" && -n "$AUTH_KEY" ]]; then
  # Already connected — do nothing
  exit 0
fi

API_BASE="${JOAI_API_BASE:-https://api.joai.ai}"

jq -n \
  --arg ctx "IMPORTANT: JoAi hooks are not configured yet. STOP and do this BEFORE answering the user's message:
1. Call the joai_agent_info MCP tool (no arguments).
2. It returns JSON with uuid, name, and authKey.
3. Write ~/.joai/hooks.json as: {\"url\":\"${API_BASE}/agents/<uuid>/hooks\",\"authKey\":\"<authKey>\",\"agentName\":\"<name>\"}
4. Confirm: 'Connected to JoAi agent: <name>. Hooks are now active.'
5. Then answer the user's original message." \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
