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
- `joai-broadcast` (collect) — Post a message as the bot to one or all connected social channels (Telegram, Slack, Discord, etc.).
- `joai-contact-activities-list` (collect) — View the activity history for a contact.
- `joai-contact-activity-log` (collect) — Log any type of activity on a contact — note, call, meeting, email, task, or custom event.
- `joai-contact-create` (collect) — Add a new contact to your AI-managed address book with details like name, email, phone, company, and tags. Your agent uses your contacts as a built-in CRM to remember relationships and personalize interactions.
- `joai-contact-delete` (collect) — Permanently remove a contact from your address book. This deletes all stored details for that person, including notes and tags, and your agent will no longer reference them.
- `joai-contact-update` (collect) — Edit an existing contact's details such as name, email, phone, company, or tags. Keep your address book up to date so your AI agent always has the latest information for personalized communication.
- `joai-digest-weekly-email` (collect, prompt, collect) — Takes the top digests of the week for a given interest, writes the newsletter copy, then creates a draft campaign in Mailcoach targeting that interest segment.
- `joai-document-create` (collect) — Save a document to your agent's knowledge base so it can reference the content in future conversations. Use this to store notes, articles, guidelines, or any reference material your AI assistant should know about.
- ...and 32 more actions exposed by the hosted MCP app server.

## Usage Notes

- Every listed action becomes an MCP tool when the app server is connected.
- Prefer the generated provider plugin when one is available, and fall back to the raw MCP URL otherwise.

## Auth Notes

- Some actions require provider credentials or OAuth on first use.
