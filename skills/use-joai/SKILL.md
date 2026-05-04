---
name: use-joai
description: Use the JoAi JoAi app plugin when the task needs JoAi tools or workflows.
---

# JoAi

Connect JoAi to Claude, Codex, and ChatGPT through JoAi's hosted MCP app server.

If a specific task was given, identify the relevant MCP tool and call it immediately — no preamble.

If invoked with no task, call the authenticate tool first (if present), then list the available actions concisely so the user can pick one.

Never ask "what would you like to do?" — either act on the task or show the menu.

## Example Prompts

- List the JoAi tools available in this app.
- Explain what setup or authentication JoAi needs before I run an action.
- Use JoAi to help me with the task I describe next.

## Action Inventory

- `joai-agent-create` (collect) — Create a new AI assistant agent in your team that can chat, manage tasks, and automate workflows on your behalf. Give it a name and start customizing its skills, knowledge, and personality to fit your needs.
- `joai-agent-name-update` (collect) — Rename your AI agent to better reflect its purpose or brand identity. The updated name will appear across all conversations and shared links.
- `joai-agent-publish` (collect) — Publish your AI agent so anyone can discover and chat with it via a shareable link. Once public, your agent becomes accessible to the world while you keep full control over its configuration and knowledge.
- `joai-billing-address-set` (collect) — Set the billing address for a user. Required before generating an upgrade link. Pass a VAT ID to mark the account as a business (routes to Stripe instead of LemonSqueezy).
- `joai-blueprint-create` (collect) — Create a reusable automation blueprint that your agent can execute to carry out complex multi-step tasks.
- `joai-blueprint-update` (collect) — Edit an existing blueprint's name, description, or configuration.
- `joai-broadcast` (collect) — Post a message as the bot to one or all connected social channels (Telegram, Slack, Discord, etc.).
- `joai-character-update` (collect) — Update your agent's name, system prompt, or bio to shape how it thinks, talks, and presents itself.
- `joai-contact-activities-list` (collect) — View the activity history for a contact.
- `joai-contact-activity-delete` (collect) — Remove a single activity (note, call, meeting, task, update, or custom event) from a contact's timeline — useful for cleaning up duplicates or obsolete entries.
- `joai-contact-activity-log` (collect) — Log any type of activity on a contact — note, call, meeting, task, update, or custom event. Emails are NOT logged here; they live in dedicated email-integrated rooms.
- `joai-contact-create` (collect) — Add a new contact to your AI-managed address book with details like name, email, phone, company, and tags. Your agent uses your contacts as a built-in CRM to remember relationships and personalize interactions.
- ...and 76 more actions exposed by the hosted MCP app server.

## Usage Notes

- Every listed action becomes an MCP tool when the app server is connected.
- Prefer the generated provider plugin when one is available, and fall back to the raw MCP URL otherwise.

## Auth Notes

- Some actions require provider credentials or OAuth on first use.
