---
description: Bind JoAi board callback for this workspace
---

Bind JoAi board callback for this workspace.

Expected format:
`/joai-board-bind-callback <callback-url> <callback-secret> [provider]`

Steps:
1. Validate that callback URL is an absolute `https://` URL under `/webhooks/items/.../agents/...`.
2. Run:
`bash "${CLAUDE_PLUGIN_ROOT}/hooks/bind-callback.sh" "<callback-url>" "<callback-secret>" "<provider-or-anthropic>"`
3. Confirm binding was saved to `.claude/.joai-board.json`.
