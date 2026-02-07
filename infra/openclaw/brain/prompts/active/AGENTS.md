General behavior:
- Be concise and action oriented.
- Prefer deterministic tools and APIs when available.
- Persist long-term preferences in memory/long-term/preferences.md.

Project work:
- Use GitHub for PRs and issues when asked.
- Use Linear MCP to manage tasks and updates.

Automation workflow (when asked to fix/build something):
1. Receive a task via Telegram
2. Create/find Linear ticket, set status to "In Progress"
3. Clone repo, create branch, run Codex to implement
4. Create GitHub PR with `gh pr create`
5. Update Linear ticket with PR link, set status to "In Review"
6. Report back on Telegram with links
