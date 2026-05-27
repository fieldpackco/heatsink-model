# Multi-agent workflow

How Claude Code, Codex, and humans collaborate across devices on a multi-agent workspace. Process, not architecture. (Architecture lives in `docs/plans/`.)

## Roles

| Agent | Role |
|---|---|
| **Claude Code** | Driver. Reads design, writes code, runs CLIs, drives infra. |
| **Codex** | Reviewer + secondary driver. Independent code review; can also implement tasks labeled `needs:codex`. |
| **Human** | Decider. Final word on design, scope, and merges. Resolves agent disagreements. |

Other agents (Cursor, etc.) follow the same protocol — agent-agnostic by design.

## Source of truth

**The autopilot host runs `scripts/autopilot.sh`.** It watches `docs/reviews/` with fswatch and dispatches the other agent in `--full-auto` the moment an artifact lands. Local files drive routing. GitHub is a mirror used for history and cross-device sync — not the trigger.

| What | Where |
|---|---|
| Routing trigger | Files in `docs/reviews/` named `<topic>-<author>-<role>.md` |
| Dispatcher | `scripts/autopilot.sh` (fswatch + codex/claude CLIs) |
| Autopilot log | `.agent-state/autopilot.log` |
| Dashboard | `.agent-state/current.md` (committed file) |
| Status check | `scripts/status.sh` |
| Code reviews | `docs/reviews/<topic>-<author>-<role>.md` |
| Handoffs / decisions | `docs/notes/YYYY-MM-DD-<topic>.md` |
| GitHub mirror | issues with `needs:*` labels — kept in sync by agents at end of turn, but they don't drive the loop |

## Branches and worktrees

- **One branch per task.** Name: `<agent>/<short-name>` — `claude/feature-x`, `codex/review-y`, `human/scope-cut`.
- **Push every commit.** Default to small, frequent pushes.
- **Worktrees are local.** Each device creates and destroys worktrees as it needs them; they never coordinate across machines. The pushed branch is the unit.
- **Before starting:** `git fetch && git checkout <branch> && git pull`.
- **Before stopping:** push, update the issue, update `.agent-state/current.md`.

## The session lifecycle (every agent, every session)

```
START:
  1. cd to repo, git fetch + git status
  2. ./scripts/status.sh
  3. Read .agent-state/current.md
  4. Read open issues with label needs:<your-name>
  5. Pick the topmost unblocked one (or continue an in-flight branch)

WORK:
  6. Checkout / create the branch (claude/... or codex/...)
  7. Do the work in small commits, push each
  8. Add issue comments at significant decision points

STOP / HANDOFF:
  9. Push everything
  10. Update .agent-state/current.md
  11. Comment on the issue: what's done, what's next, what's blocked
  12. Set labels: remove needs:<you>, add needs:<next-actor>
  13. If session ends mid-work, write docs/notes/YYYY-MM-DD-<topic>-<author>-handoff.md
```

## When to request code review

**Always** at these checkpoints (open a `kind:review` issue, label `needs:codex` if Claude wrote the code, `needs:claude` if Codex did):

- End of each numbered v1 build step in the design doc.
- Before merging any change to:
  - security-sensitive middleware (auth, idempotency, error handling)
  - signed photo upload URL minting
  - QUO client or webhook signature verification
  - Postgres migrations
  - the OpenAPI spec generation pipeline
- After a refactor touching more than ~3 files.
- Before publishing any package to a public registry.
- **Before acting on any significant design or planning doc** — system design docs, per-step implementation plans, API contracts, data-model proposals, infra/migration plans, anything under `docs/plans/`. Open the review request before code starts; the doc is the spec, so a bad spec costs more than bad code.

**Skip review** for: trivial docs (READMEs, notes, handoffs), formatting/lint, dependency bumps with no code change, fixtures/test data, trivial UI copy.

When in doubt: review.

## Review file convention

Filenames under `docs/reviews/`:

```
<topic>-<author>-<role>.md

author ∈ claude | codex | human
role   ∈ request | response | resolution
```

Flow for one review:

```
signed-urls-claude-request.md     # Claude wrote the code, asks for review
signed-urls-codex-response.md     # Codex responds with findings
signed-urls-claude-resolution.md  # Claude addresses each finding
```

### Review request template

```markdown
# Review request: <topic>

**Author:** Claude   **Date:** YYYY-MM-DD
**Issue:** #N   **Branch:** claude/<task>   **Build step:** v1 step N

## What changed
- ...

## Why
Implements §X of docs/plans/<your-design-doc>.md.

## What to look at hardest
- ...

## What I'm explicitly NOT asking about
- ...

## How to verify
- ...
```

### Review response template (Codex writes)

```markdown
# Review response: <topic>

**Reviewer:** Codex   **Date:** YYYY-MM-DD
**Reviewing:** signed-urls-claude-request.md @ <commit>

## Summary
<one paragraph — overall verdict>

## Findings

### Finding 1: <one-line summary>
**Severity:** blocker | high | medium | low | nit
**Location:** path/to/file.ts:LL
**Detail:** <what's wrong and why>
**Suggested fix:** <concrete change>

### Finding 2: ...
```

### Resolution template (Claude writes back)

```markdown
# Review resolution: <topic>

**Date:** YYYY-MM-DD   **Resolved commit:** <hash>

## Finding 1: <one-line>
**Verdict:** accepted | rejected | partial
**Rationale:** <why>
**Action:** <commit hash> | "no change (rationale)"
```

Push back on bad findings. Don't blindly accept. Use the `superpowers:receiving-code-review` skill for the disciplined version.

## Handoff notes

When a session ends with open work, write `docs/notes/YYYY-MM-DD-<topic>-<author>-handoff.md`:

```markdown
# Handoff: <topic>

**Date:** YYYY-MM-DD HH:MM   **Agent:** claude | codex
**Status:** in-progress | blocked | complete

## What I was doing
<one paragraph>

## State of the world
- Issue: #N
- Branch: <name>
- Last pushed commit: <hash>
- Files touched: <list>

## Where I left off
<exact next step the next agent should take>

## Open questions for the human
<numbered list — block progress until answered>

## Gotchas
<env quirks, weird stack traces, anything>
```

## Autopilot

`scripts/autopilot.sh` is the active dispatcher on the autopilot host. It watches `docs/reviews/` and:

- On `*-claude-request.md` / `*-claude-response.md` → fires `codex exec --dangerously-bypass-approvals-and-sandbox` with a prompt instructing it to reply, commit, push, and flip the GitHub label.
- On `*-codex-request.md` / `*-codex-response.md` → fires `claude -p --dangerously-skip-permissions` the same way.
- On `*-resolution.md`, `*-note.md`, `*-handoff.md`, or `*-human-*` → notifies only; loop is closed or informational.
- Lock files in `.agent-state/autopilot/` prevent re-dispatch when the agent's own writes land.

Start it: `./scripts/autopilot.sh` (foreground) or `nohup ./scripts/autopilot.sh >/dev/null 2>&1 &`.
Tail it: `tail -f .agent-state/autopilot.log`.

`scripts/watch-agents.sh` (notification-only) is retained for non-autopilot machines or for running alongside autopilot when you want desktop notifications without dispatching.

## When agents disagree

If Codex flags something Claude believes is correct, Claude writes the rejection rationale in the resolution doc and leaves the code as-is. A human reads both and breaks the tie via a `needs:human` issue.

If a finding is ambiguous: stop, label `needs:human`, do not ship. Internal tool with one user — no urgency that beats correctness.

## Schedule reminder (optional autonomy)

For "agents that grind without you," either Claude or Codex can be scheduled via cron-style routines to poll their inbox label periodically and pick up unblocked work. Off by default — turn on per agent when you want hands-off operation.

## Decision log

Architectural decisions get a row in the design doc's decisions table. The longer rationale, especially for reversals, goes into `docs/notes/YYYY-MM-DD-decision-<topic>.md`.
