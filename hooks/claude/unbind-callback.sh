#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/.joai-board.json"
rm -f "$STATE_FILE"
echo "Unbound JoAi board callback"
