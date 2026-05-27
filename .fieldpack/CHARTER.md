# Fieldpack Engineering Charter

**Version:** v1.0
**Owner:** fieldpackco/Shopkeep
**Canonical location:** https://github.com/fieldpackco/Shopkeep/blob/main/.fieldpack/CHARTER.md
**Synced into:** every opted-in fieldpack repo at `.fieldpack/CHARTER.md`

## What this is

The engineering contract for every Fieldpack repo. Every human and every AI agent working in an opted-in fieldpack repo must follow this. Shopkeep (`dev.fieldpack.co`) enforces what it can mechanically and surfaces violations otherwise.

A repo's relationship to the charter is one of three explicit states:

- **`candidate`** — known fieldpack repo, not yet listed in Shopkeep's `portal.yaml`. No enforcement, no surfacing.
- **`onboarding`** — listed in `portal.yaml` with `onboarding: true`. Appears only on the internal compliance report at `/internal/services/<name>/compliance`, not in any public surface, catalog list, or architecture diagram. Requires an open `kind:tech-debt` sunset issue. Build-fail checks (§6) are reported but do not fail the Shopkeep build.
- **`strict`** — listed in `portal.yaml` without `onboarding: true`. All §6 build-fail checks fail the Shopkeep build. All §6 non-compliance checks exclude the repo from public surfaces.

A repo not in any of these states is simply not part of Shopkeep.

A repo cannot move from `onboarding` to `strict` until every §6 build-fail check passes on its default branch.

## How this document is changed

- The canonical copy lives in `fieldpackco/Shopkeep`.
- Changes go through a PR on Shopkeep with Codex review.
- When merged, Shopkeep's sync GitHub Action opens PRs against every included repo updating their `.fieldpack/CHARTER.md`.
- **Repos cannot edit their local copy.** Local edits are overwritten on the next sync. To propose a change, open a PR on Shopkeep.

## The exemplar

`sitrep` is the **planned** reference repo. When this charter is ambiguous, what `sitrep@v1.0` (pinned tag) does will be the answer once that tag exists.

**Adoption prerequisite:** before this charter is enforced as v1.0, `fieldpackco/sitrep` must conform to the charter and cut a `v1.0` tag. Until that tag exists, the charter operates in `pre-enforcement` mode: all §6 checks run in report-only form and no repo can be in `strict` state.

Once cut, sitrep@v1.0 sets the standard for:
- API contract style (versioning, error model, request/response shape).
- Documentation depth (architecture.md, PRDs, ADRs).
- Test coverage (unit + integration + end-to-end + user flows).
- Repo hygiene (structure, conventions, CI, secrets handling).

When the pinned tag bumps, that is a deliberate charter-level decision; it requires a PR on Shopkeep with Codex review.

## 1. Architecture (the Bezos rule, generalized)

The interface rule is per `kind`. `service.yaml` declares a `kind`; the rule that applies depends on it.

1. **Every repo exposes the explicit interface(s) required for its `kind`.** Those interfaces are the only sanctioned ways to use the repo.
   - `kind: service` — exposes exactly one of: HTTP API, CLI, or library.
   - `kind: tool` — exposes one of: CLI, library, or MCP server.
   - `kind: hardware` — exposes a firmware interface (serial / radio / bus protocol). A documented test-plan contract (likely under `docs/test-plans/`) is expected, but the exact directory and Shopkeep-side enforcement are deferred to the three-repo schema pilot (see below) rather than fixed in v1.0.
   - `kind: docs` — exposes the docs surface (rendered site or markdown). No service interface required.
2. **No back-channels** (applies to `service` and `tool`). Repo A does not read repo B's database, files, or internal state. Repo A calls repo B's interface.
3. **Interfaces are versioned.** Breaking changes get a new major version. Deprecations get an announced sunset window. No silent contract changes.
4. **Every interface must be externalizable.** Designed from day one to be safe to expose to a partner or customer. If you would not ship it to an external caller, do not ship it to an internal one.
5. **Cross-repo dependencies are declared** in `service.yaml` `depends_on`. If your repo calls another fieldpack repo's interface, it must be listed. Shopkeep validates this.

The exact `kind` enum, plus the `language` / `deploy.target` taxonomy, freezes in `service.yaml` v1.0 only after the three-repo pilot called out in the design spec passes. Until then, this section's per-`kind` list is the working draft.

## 2. Documentation

Every `portal.yaml` repo must contain the following. Shopkeep enforces state-aware: violations fail the build for `strict` repos and render on `/internal/services/<name>/compliance` (without aborting) for `onboarding` repos.

This list mirrors the canonical always-required set in the Shopkeep design spec; if the two ever drift, the spec wins and this table is updated.

| Required | Purpose |
|---|---|
| `service.yaml` | Metadata; declares `schema_version`; validates against the versioned schema. |
| `README.md` | Public overview. |
| `STATUS.md` | Agent-maintained, plain-English, PM-readable. Updated as agents work. Stale >30 days = Shopkeep build failure (strict state only). |
| `AGENTS.md` | Canonical agent guide. Opens with a pointer to `.fieldpack/AGENT_RULES.md` and references this charter. |
| `CLAUDE.md` | Pointer to `AGENTS.md` (or directly to `.fieldpack/AGENT_RULES.md`). |
| `docs/architecture.md` | Internal-tier mental model. |
| `docs/llms.md` | Dense LLM-tier doc. |
| `docs/prd/` (directory; `.gitkeep` allowed) | One file per non-trivial feature or major decision. |
| `docs/decisions/` (directory; `.gitkeep` allowed) | ADRs (Michael Nygard format) for non-trivial choices. |
| `.fieldpack/version` | The `.fieldpack/` standard version this repo is pinned to (e.g. `1.0`). |
| `.fieldpack/CHARTER.md` | This file, synced from Shopkeep. |
| `.fieldpack/AGENT_RULES.md` | Synced from Shopkeep. |
| `.fieldpack/schemas/<version>/service.yaml.schema.json` | Mirror of the versioned schema(s) this repo's `service.yaml` declares. |
| `.fieldpack/templates/` (directory) | Synced templates. |
| `.fieldpack/scripts/validate.sh` | Local + CI validator, synced from Shopkeep. |

### PRD rule

A new **non-trivial** feature must have a PRD merged in `docs/prd/` before code starts.

- "Non-trivial" means any of:
  - a new user flow, a new API endpoint, a new service boundary, a change to a data model, or a change visible to a non-technical stakeholder; **or**
  - a security-sensitive change — auth, session/token handling, signed URLs, webhook verification, secret handling, permission/ACL changes; **or**
  - a migration (schema, data backfill, irreversible state change); **or**
  - an infrastructure / deploy / CI change that affects production behavior or credential flow; **or**
  - a cross-repo contract change (anything that another fieldpack repo's `depends_on` points at).

  These require a PRD or ADR (see below for which) **before code starts**, even when not user-visible.
- "Trivial" — bug fixes, copy/UI tweaks, refactors that do not change interfaces, dependency bumps, internal cleanups — do not require a PRD.
- Each repo's `CLAUDE.md` should include 2-3 examples of where its line falls.

### ADR rule

Any non-trivial technical decision gets an ADR in `docs/decisions/`. Format: Michael Nygard's classic ADR (Context / Decision / Status / Consequences), ~200 words.

### `STATUS.md` rule

Agents update `STATUS.md` as they work, on every non-trivial task. Sections: "Now" (current work + blockers), "Recently shipped" (dated, plain English), "Up next."

PM-readable means: a non-technical executive can read it and understand what shipped and what is stuck. Oriented toward features and outcomes, not commits.

## 3. Testing (hard gate)

### Required

Every included repo must have:

- A tests directory with real tests (per-language structure below).
- CI configured to run those tests on every PR.
- A green CI status on the default branch.

### Coverage requirements

- **Unit tests** for any non-trivial pure logic — parsers, validators, transforms, calculations, business rules.
- **Integration tests** for every external boundary — DB, third-party API, queue, message bus, file system, hardware peripheral.
- **End-to-end / user-flow tests** for every user flow documented in any PRD. If a flow is in `docs/prd/`, there must be a test that exercises it end-to-end.

### Process rules

- A new feature ships with its tests in the same PR. **No "tests in a follow-up."**
- Agents run tests and report concrete results in review requests. "I think it works" is not acceptable; "I ran `pnpm test`, 47/47 passed" is.
- Tests are the contract. A passing test suite on the default branch is the deployment gate.

### Blessed test stacks per language

| Language | Unit | Integration | E2E / user-flow |
|---|---|---|---|
| TypeScript / Node | Vitest | Vitest + testcontainers (or real local services) | Playwright |
| Python | pytest | pytest + testcontainers | Playwright |
| Rust | `cargo test` | `cargo test` integration tests under `tests/` | Playwright for web; `cargo test` for non-web |
| Swift (macOS/iOS) | XCTest | XCTest | XCUITest |
| Embedded (firmware) | Host-side unit tests where logic can be extracted; on-device tests via probe-rs / defmt where applicable | Hardware-in-the-loop where feasible | Documented test plans + manual sign-off (exact directory layout deferred to the three-repo schema pilot in §1) |

If a repo needs a different stack, it requires an ADR in `docs/decisions/` explaining why.

### Enforcement

- Shopkeep checks each included repo's default branch for a green CI status via the GitHub Checks API.
- Shopkeep checks for the presence of a tests directory matching the language's blessed structure.
- Either check failing → the repo is shown as **non-compliant** in the Shopkeep catalog and excluded from public surfaces until fixed.
- New repos created via `fieldpack new-repo` ship with CI + passing test scaffolding from day one.
- Legacy repos onboarding to Shopkeep get a documented grace period via a `kind:tech-debt` issue with a sunset date.

## 4. Agent workflow

(Mirrors the multi-agent autopilot template, reproduced here so every repo carries the same rules.)

- **File-based handoffs** via `docs/reviews/` using the `<topic>-<author>-<role>.md` convention.
- **Codex auto-reviews at every gate.** Completing reviewable work includes filing the review request. Gates: spec, plan, finished subagent task, pre-merge. Claude reviews Codex's work for the inverse case.
- **One branch per task.** Name: `<agent>/<short-name>`.
- **No invented APIs, columns, or fields.** If the design does not specify it, raise a `kind:decision` issue or write a `*-decision.md` *before* adding.
- **No clicking in admin UIs.** All infrastructure operations run via CLI/API. Find the CLI command before recommending a click-through.
- **Verify before claiming complete.** Run the tests. Hit the endpoint. Read the output. Report what you observed, not what you expected.
- **Leave a handoff note** before ending any session with open work.
- **Do not bypass safety checks** (`--no-verify`, `--no-gpg-sign`, `git reset --hard`, `git push --force`) without explicit human authorization.

## 5. Security & secrets

- **No secrets in the repo.** `.env*` is gitignored. A pre-commit hook scans for common secret patterns; commits matching are blocked.
- **`.env.example`** documents every required env var for the service.
- **Per-service tokens.** Service-to-service auth uses tokens scoped to the calling service, individually revocable. Token rotation is supported and documented.
- **Production credentials never live on a dev machine.** Production secrets stay in the deployment platform's secret store (Netlify env, Supabase service-role only on server, etc.).
- **Leaks.** Any token leaked or suspected leaked is revoked immediately. A leaked-credential event is filed via `fieldpack event` and surfaces on the dev-status feed.

## 6. Compliance summary (what Shopkeep checks)

For each opted-in repo, on every Shopkeep build. "Failure mode" applies to **strict** state; in **onboarding** state every row is reported on the compliance page only and does not fail the build or hide the repo (the repo is already hidden from public surfaces by virtue of being in onboarding state).

| Check | Strict failure mode |
|---|---|
| `service.yaml` exists, declares `schema_version`, and validates against the matching versioned schema | Build fails |
| All required files in §2 exist | Build fails |
| All required directories in §2 exist (may be empty / `.gitkeep`) | Build fails |
| `STATUS.md` modified within 30 days | Build fails |
| `depends_on` entries reference known services | Build fails |
| `CLAUDE.md` points to `AGENTS.md` or `.fieldpack/AGENT_RULES.md`; `AGENTS.md` references this charter | Build fails |
| `.fieldpack/version` matches one of the versions Shopkeep currently supports | Build fails |
| Default branch CI is green | Repo marked non-compliant, excluded from public surfaces |
| Tests directory exists per blessed structure | Repo marked non-compliant, excluded from public surfaces |
| `.fieldpack/` content matches the canonical version pinned by `.fieldpack/version` | PR opened against the repo (not a build failure) |

Non-compliance details appear at `/internal/services/<name>/compliance` for each repo, in both onboarding and strict state.
