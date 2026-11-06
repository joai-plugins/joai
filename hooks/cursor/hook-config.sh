#!/usr/bin/env bash
# Cursor hook config — resolves JoAi hook URL and agent auth key.
set -euo pipefail

# Cursor sets CURSOR_PROJECT_DIR (and CLAUDE_PROJECT_DIR as compatibility alias).
export CLAUDE_PROJECT_DIR="${CURSOR_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-.}}"

# Resolution order:
# 1. Explicit env vars (highest priority)
# 2. Per-project state file (.cursor/.joai-hooks.json or .claude/.joai-hooks.json)
# 3. Global state file (~/.joai/hooks.json) — written by connect.sh
# 4. Per-project board state — legacy fallback
# 5. JOAI_AGENT_UUID env var

resolve_agent_hook_url() {
  local explicit_url="${JOAI_AGENT_HOOK_URL:-}"
  if [[ -n "$explicit_url" ]]; then
    echo "$explicit_url"
    return 0
  fi

  local state_file
  for state_file in \
    "${CLAUDE_PROJECT_DIR}/.cursor/.joai-hooks.json" \
    "${CLAUDE_PROJECT_DIR}/.claude/.joai-hooks.json"; do
    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
      local stored_url
      stored_url="$(jq -r '.url // ""' "$state_file" 2>/dev/null || echo "")"
      if [[ -n "$stored_url" ]]; then
        echo "$stored_url"
        return 0
      fi
    fi
  done

  local global_state="${HOME}/.joai/hooks.json"
  if [[ -f "$global_state" ]] && command -v jq >/dev/null 2>&1; then
    local stored_url
    stored_url="$(jq -r '.url // ""' "$global_state" 2>/dev/null || echo "")"
    if [[ -n "$stored_url" ]]; then
      echo "$stored_url"
      return 0
    fi
  fi

  local board_state
  for board_state in \
    "${CLAUDE_PROJECT_DIR}/.cursor/.joai-board.json" \
    "${CLAUDE_PROJECT_DIR}/.claude/.joai-board.json"; do
    if [[ -f "$board_state" ]] && command -v jq >/dev/null 2>&1; then
      local board_url
      board_url="$(jq -r '.url // ""' "$board_state" 2>/dev/null || echo "")"
      if [[ "$board_url" =~ ^https?://[^[:space:]]+/webhooks/items/[^/]+/agents/([[:alnum:]_-]+)$ ]]; then
        local agent_id="${BASH_REMATCH[1]}"
        local origin="${board_url%%/webhooks/items/*}"
        echo "${origin}/agents/${agent_id}/hooks"
        return 0
      fi
    fi
  done

  local api_base="${JOAI_API_BASE:-https://api.joai.ai}"
  local agent_uuid="${JOAI_AGENT_UUID:-}"
  if [[ -n "$agent_uuid" ]]; then
    echo "${api_base%/}/agents/${agent_uuid}/hooks"
    return 0
  fi

  echo ""
}

resolve_api_base() {
  local url
  url="$(resolve_agent_hook_url)"
  if [[ "$url" =~ ^(https?://[^/]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "${JOAI_API_BASE:-https://api.joai.ai}"
  fi
}

resolve_agent_auth_key() {
  local explicit="${JOAI_AGENT_AUTH_KEY:-}"
  if [[ -n "$explicit" ]]; then
    echo "$explicit"
    return 0
  fi

  local state_file
  for state_file in \
    "${CLAUDE_PROJECT_DIR}/.cursor/.joai-hooks.json" \
    "${CLAUDE_PROJECT_DIR}/.claude/.joai-hooks.json"; do
    if [[ -f "$state_file" ]] && command -v jq >/dev/null 2>&1; then
      local stored
      stored="$(jq -r '.authKey // .secret // ""' "$state_file" 2>/dev/null || echo "")"
      if [[ -n "$stored" ]]; then
        echo "$stored"
        return 0
      fi
    fi
  done

  local global_state="${HOME}/.joai/hooks.json"
  if [[ -f "$global_state" ]] && command -v jq >/dev/null 2>&1; then
    local stored
    stored="$(jq -r '.authKey // ""' "$global_state" 2>/dev/null || echo "")"
    if [[ -n "$stored" ]]; then
      echo "$stored"
      return 0
    fi
  fi

  local board_state
  for board_state in \
    "${CLAUDE_PROJECT_DIR}/.cursor/.joai-board.json" \
    "${CLAUDE_PROJECT_DIR}/.claude/.joai-board.json"; do
    if [[ -f "$board_state" ]] && command -v jq >/dev/null 2>&1; then
      jq -r '.secret // ""' "$board_state" 2>/dev/null || echo ""
      return 0
    fi
  done

  echo ""
}
