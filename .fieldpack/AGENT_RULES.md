# Agent rules — read first

Before doing any work in this repo:

1. Read `.fieldpack/CHARTER.md` (synced from `fieldpackco/Shopkeep`). It is the engineering contract for every Fieldpack repo.
2. Read this repo's `AGENTS.md` for repo-specific rules.
3. Read `STATUS.md` to know what's in flight.
4. Read `docs/superpowers/specs/` for the v1 design.

## Hard rules (excerpted from CHARTER.md §4)

- File-based handoffs via `docs/reviews/` using `<topic>-<author>-<role>.md`.
- Codex auto-reviews at every gate. Filing the review is part of completing the work.
- One branch per task: `<agent>/<short-name>`.
- No invented APIs, columns, or fields. If undefined, raise a `kind:decision`.
- No clicking in admin UIs.
- **Verify before claiming complete.** Run tests, report concrete results.
- Don't bypass safety checks (`--no-verify`, `--no-gpg-sign`, `git reset --hard`, force-push) without explicit human authorization.

## You must update

As part of finishing any non-trivial task:
- `STATUS.md` — what shipped, what's blocked.
- `docs/architecture.md` — if components/data flow changed.
- `docs/llms.md` — if file map / conventions / gotchas changed.
- `docs/prd/` — new file before code starts for non-trivial features.
- `docs/decisions/` — new ADR for non-trivial technical decisions.

## You must not edit

- `.fieldpack/` — synced from Shopkeep. Local edits are overwritten.

When the charter and a local `AGENTS.md` conflict, the charter wins.
