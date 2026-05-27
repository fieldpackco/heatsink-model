# reviews/

Cross-agent code review artifacts.

## Filename convention

`<topic>-<author>-<role>.md`

- **author** ∈ `claude` | `codex` | `human`
- **role** ∈ `request` | `response` | `resolution`

Example flow on a single review:

```
signed-urls-claude-request.md     # Claude asks for review
signed-urls-codex-response.md     # Codex responds
signed-urls-claude-resolution.md  # Claude addresses findings
```

The author tag in the filename is what the local fswatch notifier and the GitHub-side automations key off of. Don't skip it.

Templates and full workflow live in [`../multi-agent-workflow.md`](../multi-agent-workflow.md).
