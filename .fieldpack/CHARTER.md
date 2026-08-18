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

A candidate or onboarding repo cannot enter `strict` until every §6
build-fail check passes on its default branch.

## How this document is changed

- The canonical copy lives in `fieldpackco/Shopkeep`.
- Changes go through a PR on Shopkeep with Codex review.
- **Propagation is pull-based and manual.** Each repo runs `fieldpack sync` to copy `.fieldpack/` from the canonical source into itself. Merging a change on Shopkeep updates the canonical copy and nothing else — no repo learns of it until someone syncs that repo.
- **Repos cannot edit their local copy.** Local edits are overwritten on the next sync. To propose a change, open a PR on Shopkeep.

> **A merged Charter change is not a deployed Charter change.** An earlier version of this
> document claimed a sync GitHub Action opened PRs against every included repo on merge. No such
> workflow exists — `.github/workflows/` holds only `ci.yml`. Corrected 2026-08-13 rather than
> left standing, because a governing document that misdescribes its own propagation is the
> worst place for that error to live: every reader downstream assumes a reach it does not have.
>
> Until a push mechanism exists, rolling a change out fleet-wide means running `fieldpack sync`
> in each repo and committing the result there. Repo count and sync state are not tracked
> anywhere, so there is no way to answer "which repos are on the current Charter" without
> checking each one.

## The exemplar

**There is no exemplar repo.** This Charter is self-contained: when it is
ambiguous, the answer is an explicit amendment, not an inferred precedent.

Earlier versions named `sitrep@v1.0` as a planned reference whose behavior would
resolve ambiguity once that tag existed. Sitrep has been deprecated and the tag
will never be cut, so that pointer is removed rather than left dangling. No
behavior may be inferred from any repository to fill a gap in this document.

Strict enforcement is available to any repo whose default branch passes every
§6 build-fail check. Strict repos are held to the explicit Charter and schema
requirements. An ambiguous requirement stays **report-only** until a reviewed
Charter decision resolves it — a repo is never failed for a rule this document
does not actually state.

Resolving an ambiguity means one of two things:

- a **Charter amendment**, by PR on Shopkeep with Codex review, which then syncs
  to every opted-in repo; or
- a **domain exception** granted by the Priest for that domain — scoped,
  time-boxed, and recorded as an ADR naming the rule, the scope, the expiry, and
  the reason. An expired exception is a compliance finding, not a silent
  renewal. No exception may cover a physical-effect path or bypass Amit's gate
  over synthesis, critical, and hardware decisions.

Should a reference repo be designated later, that is a deliberate
charter-level decision requiring a PR on Shopkeep with Codex review.

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
| `.fieldpack/version` | The `.fieldpack/` standard version this repo is pinned to (current: `1.1`). |
| `.fieldpack/CHARTER.md` | This file, synced from Shopkeep. |
| `.fieldpack/AGENT_RULES.md` | Synced from Shopkeep. |
| `.fieldpack/schemas/<version>/service.yaml.schema.json` | Mirror of the versioned schema(s) this repo's `service.yaml` declares. |
| `.fieldpack/templates/` (directory) | Synced templates. |
| `.fieldpack/scripts/validate.sh` | Local + CI validator, synced from Shopkeep. |
| `.fieldpack/bin/fieldpack-validate.mjs` | Validate-only Node.js bundle used by `validate.sh`; runs offline without a package registry. Required from standard `1.1` onward. |

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

### Rendered guide rule

User-facing guides, instructions, and tutorial deliverables must ship as rendered or programmatic artifacts (for example HTML, app routes, generated PDFs, or source-backed UI), not as loose Markdown files under guide delivery paths such as `projects/guides/` or `guides/`. Markdown remains valid for required docs, PRDs, ADRs, source notes, and internal LLM context under the documented paths above.

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
- **No invented APIs, columns, or fields.** If the design does not specify it, file a `kind:decision` issue in Linear (§4.2) or write a `*-decision.md` *before* adding.
- **No clicking in admin UIs.** All infrastructure operations run via CLI/API. Find the CLI command before recommending a click-through.
- **Verify before claiming complete.** Run the tests. Hit the endpoint. Read the output. Report what you observed, not what you expected.
- **Leave a handoff note** before ending any session with open work.
- **Do not bypass safety checks** (`--no-verify`, `--no-gpg-sign`, `git reset --hard`, `git push --force`) without explicit human authorization.

### 4.1 Crossing a repo boundary

`docs/reviews/` handoffs coordinate agents **inside** one repo. They do not reach another repo, and no agent reads another repo's review files. When work touches a boundary, the rules below apply.

- **Report outward, do not reach in.** When you find a defect, a gap, or a needed change in a repo you are not working in, file it in Linear (§4.2) labelled with the owning repo: `kind:blocker` if it blocks you, `kind:decision` if it needs a call someone else must make. State what you observed, what you expected, and the repo and commit you were working in. The owning repo owns the fix.
- **Never work around it silently.** A local workaround for someone else's defect leaves the defect in place, undocumented, and now load-bearing. If you must proceed to stay unblocked, the issue goes up first and your workaround cites it.
- **Never fix a shared contract by editing your own copy of it.** A contract is shared precisely so that both sides cannot disagree. Patching your side to match your expectation reintroduces the divergence the contract exists to prevent, and it does so invisibly — both repos build, and the disagreement surfaces later as wrong values rather than a failed build.
- **Changing a shared contract is the owning repo's job**, in this order: the owning repo changes it, regenerates any fixtures or vectors that pin it, and versions the change; consumers then move to the new version deliberately. A consumer never front-runs that sequence.
- **If you cannot file** — no access, no network, repo unknown — say so plainly and stop at that boundary. Do not substitute a guess about what the other side intended.

Mechanical agreement is preferred over reporting wherever it is available. A shared fixture that both sides test against turns a boundary disagreement into a failing test rather than a message someone has to notice, read, and act on. Reporting is for what fixtures cannot catch: a missing field, a wrong assumption, a design that needs a decision.

### 4.2 Where work is tracked

**Linear is the tracker. GitHub is where code is executed.** Each has one job, and state flows in one direction only.

- **File work in Linear**, not in a repo: bugs, tasks, decisions to be made, tech debt, anything not yet done. One workspace covers the whole fleet, so a cross-repo report has somewhere to go that a per-repo tracker cannot provide.
- **Label every issue with its owning repo.** An issue nobody can route is an issue nobody fixes.
- **Reference the Linear issue in the branch name and the PR body.** The PR closes the issue on merge; nothing marks an issue done by hand while its work is unmerged.
- **State flows from execution to intent, never the reverse.** A merged PR closes a Linear issue. A Linear edit never changes code, a branch, or a repo's state.

Do **not** move these into the tracker — they are versioned with the code they explain, and a decision separated from its codebase loses the thing that made it worth writing:

- `docs/decisions/` (ADRs) and `docs/prd/` — decisions already made.
- `docs/reviews/` — in-repo agent handoffs.
- `STATUS.md` — what this repo shipped and what blocks it *now*.

The test is tense. **Work not yet done goes to Linear. A decision already made stays in the repo.** `STATUS.md` keeps "Now" and "Recently shipped"; its "Up next" belongs in Linear.

### 4.3 Autonomous work

Agents file, dispatch, and merge on their own. Continuous development is the point; a loop that pauses for approval at every step is not a loop. Autonomy is bounded rather than approved — the limits below are **caps and kill switches, not gates**, so work proceeds without a human in the path and stops hard at a known edge.

- **An agent may file** an issue in Linear, and **may dispatch** by assigning one to an agent identity. It may not close an issue except by merging the PR that resolves it, because closing without merging asserts an outcome that did not happen.
- **Merge is gated on `safety_profile`, not on a human.** `software` and `safety-adjacent` repos auto-merge on green CI. **`hardware` repos require human merge** — §3 already requires hardware-in-the-loop testing and manual sign-off for firmware, and a physical-effect path is the one place a green check cannot stand in for a bench.
- **Green CI must mean something.** Auto-merge is only honest where the tests actually cover the change. A repo whose suite cannot exercise what changed must not auto-merge on it; say so and leave the PR open rather than let a passing check that proves nothing act as a merge authority.
- **Bounds that stop a runaway**, all of which exist rather than being requested per-task: the autopilot parallel and host-lock caps, the budget caps of §5b, and a documented kill switch that halts dispatch without halting in-flight work.
- **Every autonomous action is attributable.** A dispatched session records the issue that triggered it; a merged PR records the session that produced it. Autonomy without a trail is indistinguishable from an accident.

This is a deliberate trade made while no unit is deployed. Revisit it when hardware is in the field, where a bad merge stops being a revert and starts being a truck.

## 5. Security & secrets

- **No secrets in the repo.** `.env*` is gitignored. A pre-commit hook scans for common secret patterns; commits matching are blocked.
- **`.env.example`** documents every required env var for the service.
- **Per-service tokens.** Service-to-service auth uses tokens scoped to the calling service, individually revocable. Token rotation is supported and documented.
- **Production credentials never live on a dev machine.** Production secrets stay in the deployment platform's secret store (Netlify env, Supabase service-role only on server, etc.).
- **Leaks.** Any token leaked or suspected leaked is revoked immediately. A leaked-credential event is filed via `fieldpack event` and surfaces on the dev-status feed.

## 5a. Type-strictness contract (mechanical rigor)

Every repo in `strict` or `onboarding` state must clear language-appropriate strict-typing rules in CI. The rules below are the floor; repos may be stricter.

### What strict means per language

| Language | Mechanical requirement |
|---|---|
| **TypeScript** | `tsconfig.json` has `strict: true`, `noUncheckedIndexedAccess: true`, `exactOptionalPropertyTypes: true`. No explicit `any` in first-party authored source or test code, enforced by ESLint (`unknown` is acceptable when narrowed before use). Generated clients, vendor declarations, and third-party shims are excluded **only** if they are not hand-edited and are consumed through a typed wrapper or zod-validated boundary; a hand-edited file is first-party and the rule applies. No `// @ts-ignore` without an adjacent comment explaining the workaround and a TODO with an issue link. `zod` (or equivalent) validates every external boundary input — HTTP request bodies, env vars, file reads. Functions whose failure is expected return `Result<T, E>` instead of throwing. |
| **Python** | Default floor is `mypy --strict`. A repo may standardize on `pyright` (strict config, `--level error`) instead via an ADR in `docs/decisions/`. `mypy` and `pyright` are **not** interchangeable in coverage, so the repo must declare its chosen checker in CI/config and keep that command pinned; the declared command is the one Codex verifies. Type hints on every public function. `pydantic` (or equivalent) validates every external boundary input. Bare `except:` is banned; catch specific exceptions or wrap in a `Result`-equivalent. |
| **Rust** | `cargo clippy --all-targets --all-features -- -D warnings -W clippy::pedantic` passes. No `unwrap()` or `expect()` outside test code. Embedded `no_std` exempt from clippy::pedantic where the target lints conflict, but `clippy::all` still applies. |
| **Swift** | `-warnings-as-errors` enabled. No `as!` outside tests. Force-unwraps (`!`) require a comment explaining why the optional is guaranteed non-nil. |
| **Embedded C / C++** | `-Wall -Wextra -Werror` minimum. Static analysis (`clang-tidy`) runs in CI. Function declarations are explicit; no implicit-int. |

### Enforcement

- Each repo's `.github/workflows/ci.yml` runs the language-appropriate typecheck and lint as required steps, with `--max-warnings 0` / `-W error` semantics. A PR with strict-mode violations fails CI and cannot merge.
- Codex review of any PR in a `strict` repo MUST verify the typecheck/lint output was clean. A green CI status from the workflow run is the verifiable signal.
- For `onboarding` repos: the same checks should be on CI, but a missing or red check renders on the repo's compliance page and does not fail Shopkeep's build.

### What this contract does NOT promise

- That all bugs are caught. Strict typing catches type errors and a class of obvious correctness mistakes. It does not catch:
  - Wrong abstractions that happen to typecheck.
  - Domain-knowledge mistakes (a Modbus register that compiles fine but maps the wrong meaning).
  - PII-leakage patterns where the types are correct but the field flows are not.
- Codex review and human review of those is still required for change-set significance beyond local refactors.

### Promise we DO make

Every required mechanical gate (typecheck, lint, tests, Charter-file presence, STATUS.md freshness, CI status) is encoded in CI and Shopkeep and **cannot be waived silently** — a red or missing gate surfaces structurally. Judgment-call moments (architecture drift, soft correctness, security boundaries) are surfaced to a human for decision.

Two gates are detectors, not proofs: **secret-scan** and **license-scan** are required and their findings surface structurally, but they catch known patterns and can miss unknown ones (novel secret shapes, misconfigured allowlists, unpublished license metadata, generated artifacts). Residual risk on those two still goes to human review. The promise is structural enforcement and no silent waiver — not that the scanners are complete.

## 5b. CLI control layer

Every Fieldpack service with a writable HTTP API must be drivable from the **central `fieldpack` CLI** (the one shipped by Shopkeep). Pattern:

```
fieldpack <service> <verb> <noun>           # standard shape
fieldpack dispatch jobs create              # examples
fieldpack sitrep batteries status 47
fieldpack ch estimates compute < input.json
fieldpack loadout catalog list --industry=audio
```

Agents drive services through the CLI by preference; raw HTTP is allowed but discouraged. One tool to learn, one binary to update, one place to enforce auth + retry + rate-limit semantics.

### Mechanism

- Each service exposes its API as an **OpenAPI spec + zod schema** (or equivalent) checked into its repo at `openapi.json` or `schemas/`.
- Shopkeep's `fieldpack` CLI generates subcommands per service from those schemas at build time.
- Per-service CLI handlers can override generated behavior where needed (interactive prompts, streaming output) via a small per-service handler in Shopkeep's `cli/src/services/<name>.ts`.

### Exempt repos

The CLI requirement does NOT apply to:
- `kind: docs` (marketing/support sites, design references) — they have no API surface.
- `kind: hardware` (firmware, board designs) — they expose serial/Modbus/USB, not HTTP.
- Repos where the only writable surface is `git push` itself (no runtime API).

A `kind: tool` repo that ships its own CLI as its primary interface (e.g., `loadout-ingest`) keeps that CLI but the central `fieldpack` CLI should still wrap its programmatic interface for agent use where applicable.

### Authentication

The `fieldpack` CLI uses the same per-repo bearer-token pattern as service-to-service auth. The caller's identity (which repo or human is invoking) is part of the token, so every mutation reaches a service authenticated and attributable. **Each service owns mutation auditability in its own API contract** — it logs the mutations it accepts, since it alone knows which operations mutate and what the audit shape should be.

Central audit logging (one cross-service feed of every mutating CLI invocation) is **not** required by this amendment: it would need a defined event model, storage owner, retention policy, and auth scope that no current spec provides, and mandating it here would force implementers to invent an audit surface. If central audit logging is wanted, it gets its own decision/spec defining the event model before it becomes a Charter requirement.

## 5c. Enforcement-through-tooling (the mechanical floor)

The complete mechanical-rigor floor every `strict` repo must pass on every PR:

| Check | Language scope | What it catches |
|---|---|---|
| **`typecheck`** | TS/Python/Rust/Swift/C/C++ | Type errors, missing strict-mode flags, `any` usage |
| **`lint`** | All | Style, deprecated APIs, common bugs, dead code |
| **`test`** (unit) | All | Pure-function regressions per §3 |
| **`test:integration`** | Services | Cross-boundary behavior per §3 |
| **`test:e2e`** | Services with user flows | User flows per PRD per §3 |
| **`fieldpack validate`** | All | Required Charter files present, schema valid, STATUS.md fresh, no loose Markdown guide deliverables. **Shipped** — `fieldpack validate` exists in the CLI today and is an enforceable gate now. |
| **`fieldpack policy-check`** | All | Type-strictness §5a compliance, CLI shape §5b compliance for applicable repos. **Report-only until shipped** — this command does not yet exist in the Shopkeep CLI. It is a planned gate; it cannot fail a build until it ships in a declared `.fieldpack` standard version with an enforceable contract. Until then, §5a/§5b are enforced via the per-language `typecheck`/`lint` rows above, not via `policy-check`. |
| **secret-scan** | All | Hardcoded credentials, API keys, certificates |
| **license-scan** | Repos that bundle dependencies | Disallowed licenses in the dependency tree |

Each repo's `.github/workflows/ci.yml` must run every applicable row above. PRs with any red status cannot merge. Codex review on every gate must verify the run is green before approving.

Per-language minimum commands (these go in each repo's CI):

- **TypeScript:** `pnpm typecheck && pnpm lint && pnpm test`
- **Python:** `mypy --strict . && ruff check . && pytest`
- **Rust:** `cargo clippy --all-targets -- -D warnings && cargo test`
- **Swift:** `xcodebuild -warnings-as-errors test`
- **Embedded:** language-specific equivalent + `clang-tidy`

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
| No loose Markdown guide deliverables under `projects/guides/` or `guides/`; guides must be rendered/programmatic artifacts | Build fails |
| Default branch CI is green | Repo marked non-compliant, excluded from public surfaces |
| Tests directory exists per blessed structure | Repo marked non-compliant, excluded from public surfaces |
| Strict-mode typecheck + lint pass on default branch (§5a) | Build fails |
| Applicable repo has central CLI coverage (§5b) — generated from its checked-in OpenAPI/zod schema, **or** an explicit `cli/src/services/<name>.ts` handler. "Applicable" = a writable HTTP API, or a `kind: tool` with a programmatic interface intended for agent use. The exemptions in §5b (`kind: docs`, `kind: hardware`, git-push-only surfaces) are not applicable and never fail this row. | Repo marked non-compliant, excluded from public surfaces |
| `.fieldpack/` content matches the canonical version pinned by `.fieldpack/version` | PR opened against the repo (not a build failure) |

Non-compliance details appear at `/internal/services/<name>/compliance` for each repo, in both onboarding and strict state.
