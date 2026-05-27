# AGENTS.md — multi-agent autopilot workspace

Source of truth for any AI agent (Claude Code, Codex, Cursor, others) working in this workspace. Read this before doing anything else.

## First three actions, every session

1. **`./scripts/status.sh`** — snapshot of the workspace (issues, branches, dashboard).
2. **Read `.agent-state/current.md`** — the committed dashboard.
3. **Check `docs/reviews/` and `.agent-state/autopilot.log`** — your inbox is whatever request/response files are addressed to you. If autopilot is running, anything in flight has probably already been picked up.

If state looks unexpected, **stop and reconcile** before starting anything new.

## What this workspace is

A multi-agent collaboration setup where Claude and Codex hand off work to each other via files dropped in `docs/reviews/`. On any machine that runs `scripts/autopilot.sh`, the local fswatch dispatcher fires the other agent in `--full-auto` the moment an artifact lands.

- `docs/plans/` — design docs, implementation plans, anything that warrants review before code starts.
- `docs/notes/` — running notes, handoffs, decisions.
- `docs/reviews/` — code / spec review threads. Naming convention is load-bearing; see below.
- `.agent-state/current.md` — committed dashboard.
- `scripts/autopilot.sh` — fswatch-driven dispatcher.
- `scripts/status.sh` — status snapshot.
- `scripts/watch-agents.sh` — notification-only watcher (for non-autopilot machines).

## Hard rules

1. **Autopilot host is the routing source of truth.** On the machine running `scripts/autopilot.sh`, local files in `docs/reviews/` drive routing. Push commits to GitHub for history and sync, but don't gate handoffs on GitHub state.
2. **One branch per task.** Name: `<agent>/<short-name>` (`claude/feature-x`, `codex/review-y`).
3. **Handoffs happen by writing files.** Drop `<topic>-<author>-<role>.md` into `docs/reviews/` and autopilot fires the other agent. GitHub issues + `needs:*` labels are updated by agents at the end of a turn, but they mirror the file state — they don't drive it.
4. **No invented APIs, columns, or fields.** If the design doc doesn't specify it, open a `kind:decision` issue or write a `*-decision.md` before adding.
5. **No clicking in admin dashboards.** Infrastructure operations run via CLI/API. If you find yourself recommending a click-through, find the CLI command first.
6. **Leave a handoff note** before ending any session with open work.

## Coordination model in one diagram

```
                          ┌────────────────────────────────────┐
                          │  Autopilot host (this mac)         │
                          │  autopilot.sh watches docs/reviews │
                          └──────────────┬─────────────────────┘
                  drop file               │ fswatch fires
                  ────────────►           ▼
                                  ┌──────────────────┐
                                  │ codex --full-auto│  (on *-claude-*.md)
                                  └────────┬─────────┘
                                  ┌────────┴─────────┐
                                  │ claude --full-auto│ (on *-codex-*.md)
                                  └────────┬─────────┘
                                           │ commit + push
                                           ▼
                                   GitHub (mirror, history, sync)
```

Loop driver: drop a properly-named file in `docs/reviews/`. The other agent picks it up, replies, commits, pushes.

## File naming convention

For artifacts under `docs/reviews/` and `docs/notes/`:

```
<topic>-<author>-<role>.md
```

- **author** ∈ `claude` | `codex` | `human`
- **role** ∈ `request` | `response` | `resolution` | `note` | `handoff` | `decision`

Example: `feature-x-claude-request.md` → `feature-x-codex-response.md` → `feature-x-claude-resolution.md`.

Autopilot routes notifications based on the author tag in the filename. Always include it.

## Code review triggers

Request a review (open a `kind:review` issue, drop a `*-request.md`) at these checkpoints:

- End of each numbered step in any design / implementation plan.
- Before merging any change to security-sensitive code (auth, signed URLs, webhook verification, secret handling, migrations).
- After a refactor touching more than ~3 files.
- **Before acting on any significant design or planning doc** — anything under `docs/plans/`, API contracts, data-model proposals, infra/migration plans. The doc is the spec, so a bad spec costs more than bad code.

Skip review for: trivial docs (READMEs, notes, handoffs), formatting/lint, dependency bumps, fixtures/test data, trivial copy/UI tweaks.

## Project-specific addendum

Each project that adopts this template should append a "## Project context" section here with: what the project does, what stack it uses, what its specific hard rules are (API-first? Append-only events? Versioned API?), and pointers to its design docs.

## Pointers

- `CLAUDE.md` → points here. AGENTS.md is canonical for all agents.
- `docs/multi-agent-workflow.md` → the full protocol, templates, examples.

## Project context

**heatsink-model** is a Fieldpack repo originally authored by Oliver Krause (HumbleOliverKrause / OllieKrause), who is no longer with the company. This repo is under **Oliver-knowledge preservation** mode.

### What this means

- Oliver was the sole source of domain expertise on this code. No human in the company currently has the same depth.
- This repo's deployed artifacts may be running in the field on customer-deployed batteries; we must be able to troubleshoot them.
- We are extracting and documenting everything we can infer from the code, commits, and artifacts.
- **No human EE / firmware / hardware expert is in the review loop.** The extracted documentation is "what the code says happens," not "what is safe or correct." Every extracted doc must include a banner reflecting this.
- All changes (even doc changes) go through Codex review with extra rigor: every claim must be traceable to source code or a specific commit.

### Repo summary

Jupyter notebook(s) and supporting files modeling thermal behavior, likely for battery / power-electronics heatsinking. Potentially safety-relevant for understanding pack thermal limits.

