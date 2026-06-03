# AGENTS.md — multi-agent autopilot workspace (Fieldpack member repo)

Source of truth for any AI agent (Claude Code, Codex, Cursor, others) working in
this repo. Read this before doing anything else.

## First three actions, every session

1. **Read `.fieldpack/CHARTER.md`** (pointer to the canonical charter in Shopkeep)
   and the canonical `AGENTS.md` in Shopkeep
   (https://github.com/fieldpackco/Shopkeep/blob/main/AGENTS.md). That is the
   long-form contract.
2. **Read `.fieldpack/safety.yaml`** to know the safety classification of this
   repo. Behavior changes accordingly: `hardware` repos require physical-loop
   review; `safety-adjacent` repos require data-integrity review; `software`
   repos follow normal review cadence.
3. **Check `docs/reviews/` and `.agent-state/autopilot.log`** (if present). Your
   inbox is whatever request/response files are addressed to you.

If state looks unexpected, **stop and reconcile** before starting anything new.

## Hard rules (mirror of Shopkeep canonical)

1. **One branch per task.** Name: `<agent>/<short-name>`
   (`claude/feature-x`, `codex/review-y`).
2. **Handoffs happen by writing files.** Drop `<topic>-<author>-<role>.md` into
   `docs/reviews/`. Autopilot routes notifications based on the author tag.
3. **No invented APIs, columns, or fields.** If the design doc doesn't specify
   it, open a `kind:decision` issue or write a `*-decision.md` first.
4. **No clicking in admin dashboards.** Infrastructure ops via CLI/API.
5. **Leave a handoff note** before ending any session with open work.
6. **Codex auto-reviews at every gate.** When Claude completes any reviewable
   artifact, Claude MUST drop a `docs/reviews/<topic>-claude-request.md` file
   without being asked. Inverse holds for Codex.

## File naming convention (for docs/reviews/, docs/notes/)

```
<topic>-<author>-<role>.md
```

- author ∈ `claude` | `codex` | `human`
- role ∈ `request` | `response` | `resolution` | `note` | `handoff` | `decision`

## Safety-profile addendum

This repo's profile is declared in `.fieldpack/safety.yaml`. Hardware and
safety-adjacent repos additionally require:

- All physical-effect changes (motor control, energy gating, actuator commands)
  reviewed by Codex BEFORE any code is run on real hardware.
- Bench tests and simulation results recorded under `docs/reviews/` before
  energizing real hardware.
- No autonomous physical actions from autopilot — the loop driver is files +
  GitHub state; the physical actuation step is always gated by a human.

For full guidance, defer to the Shopkeep canonical AGENTS.md.
