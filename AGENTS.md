# AGENTS.md — multi-agent autopilot workspace (Fieldpack member repo)

Source of truth for any AI agent (Claude Code, Codex, Cursor, others) working
in this repo. Read this before doing anything else.

<!-- shopkeep-conformance-contract: do not edit between markers -->
## Multi-agent contract (Shopkeep-aligned)

This repo is part of the Fieldpack multi-agent autopilot workspace. Source of
truth lives in Shopkeep; this section is synced and should not be hand-edited
between the markers below.

### First three actions, every session

1. **Read `.fieldpack/AGENT_RULES.md`** — the local agent-rule entry point.
2. **Read `.fieldpack/CHARTER.md`** — the full synced engineering charter.
3. **Read `.fieldpack/safety.yaml`** — this repo's safety classification.
   `hardware` repos require physical-loop review before any code runs on real
   hardware; `safety-adjacent` repos require data-integrity review; `software`
   repos follow normal review cadence.

Then check `docs/reviews/` and (if present) `.agent-state/autopilot.log` for
any open requests addressed to you.

### Hard rules (mirror of Shopkeep canonical)

1. **One branch per task** — `<agent>/<short-name>` (e.g. `claude/feature-x`).
2. **Handoffs by file** — drop `<topic>-<author>-<role>.md` into `docs/reviews/`.
3. **No invented APIs, columns, or fields.** Raise a `*-decision.md` first.
4. **No clicking in admin dashboards** — infrastructure ops via CLI/API.
5. **Codex auto-reviews at every gate.** Filing the review is part of completing
   the work; Claude must drop `*-claude-request.md` without being asked.
6. **Verify before claiming complete.** Run tests; report concrete results.

### File naming convention (docs/reviews/, docs/notes/)

```
<topic>-<author>-<role>.md
```

- author ∈ `claude` | `codex` | `human`
- role ∈ `request` | `response` | `resolution` | `note` | `handoff` | `decision`

### Safety-profile addendum

Hardware and safety-adjacent repos additionally require:

- All physical-effect changes (motor control, energy gating, actuator commands)
  reviewed by Codex BEFORE any code is run on real hardware.
- Bench tests / simulation results recorded under `docs/reviews/` before
  energizing real hardware.
- No autonomous physical actions from autopilot — actuation is always
  gated by a human.

For full guidance, defer to `.fieldpack/CHARTER.md` and the Shopkeep canonical
`AGENTS.md` (https://github.com/fieldpackco/Shopkeep/blob/main/AGENTS.md).
<!-- /shopkeep-conformance-contract -->
