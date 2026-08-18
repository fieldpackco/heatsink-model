# Agent rules — read first

Before doing any work in this repo:

1. Read `.fieldpack/CHARTER.md` (synced from `fieldpackco/Shopkeep`). It is the engineering contract.
2. Read this repo's `AGENTS.md` for repo-specific rules.
3. Read `STATUS.md` to know what's in flight.

## Hard rules (excerpted from CHARTER.md §4)

- File-based handoffs via `docs/reviews/` using `<topic>-<author>-<role>.md`. These coordinate
  agents **inside this repo only**. No agent reads another repo's review files.
- Codex auto-reviews at every gate. Filing the review is part of completing the work.
- One branch per task: `<agent>/<short-name>`.
- No invented APIs, columns, or fields. If undefined, raise a `kind:decision`.
- No clicking in admin UIs.
- User-facing guides/instructions/tutorials must be rendered or programmatic artifacts, not loose Markdown files under `projects/guides/` or `guides/`.
- **Verify before claiming complete.** Run tests, report concrete results.
- Don't bypass safety checks (`--no-verify`, `--no-gpg-sign`, `git reset --hard`, force-push) without explicit human authorization.

## Crossing a repo boundary (CHARTER.md §4.1)

Found a defect or a needed change in a repo you are **not** working in?

- **File it in Linear**, labelled with the owning repo — `kind:blocker` if it blocks you,
  `kind:decision` if someone else must make a call. Say what you observed, what you expected,
  and your repo and commit. Linear is the tracker; GitHub is where code is executed.
- **Never work around it silently.** If you must proceed, file first and cite the issue.
- **Never fix a shared contract by editing your own copy.** Both repos would still build and
  the disagreement would surface later as wrong values instead of a failed build.
- **The owning repo changes a contract first**, regenerates whatever fixtures pin it, and
  versions it. Consumers move to the new version afterwards, deliberately.
- **Can't file?** Say so and stop at the boundary. Do not guess what the other side intended.

## Where work is tracked (CHARTER.md §4.2)

Work not yet done goes to **Linear**. A decision already made stays **in the repo**.

- File bugs, tasks, decisions and tech debt in Linear, labelled with the owning repo.
- Keep ADRs (`docs/decisions/`), PRDs (`docs/prd/`) and review handoffs (`docs/reviews/`) here.
- `STATUS.md` keeps "Now" and "Recently shipped". "Up next" belongs in Linear.
- Reference the Linear issue in your branch name and PR body; merging closes it.
- You may **file** and **dispatch** in Linear. You may not close an issue except by merging
  the PR that resolves it.
- **Auto-merge on green CI** in `software` and `safety-adjacent` repos. **`hardware` repos need
  a human** — check `.fieldpack/safety.yaml` before merging anything.
- If the test suite cannot actually exercise what you changed, say so and leave the PR open. A
  passing check that proves nothing is not merge authority.

## You must update

As part of finishing any non-trivial task:
- `STATUS.md` — what shipped, what's blocked.
- `docs/architecture.md` — if components/data flow changed.
- `docs/llms.md` — if file map / conventions / gotchas changed.
- `docs/prd/` — new file before code starts for non-trivial features.
- `docs/decisions/` — new ADR for non-trivial technical decisions.

## You must not edit

- `.fieldpack/` — synced from Shopkeep. Local edits are overwritten.
- Run `.fieldpack/scripts/validate.sh` for the repo compliance gate. It uses the
  vendored validator and must not download packages or require registry access.

When the charter and a local `AGENTS.md` conflict, the charter wins.
