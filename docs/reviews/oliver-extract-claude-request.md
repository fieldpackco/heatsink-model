# Review request: Oliver-knowledge extraction

**Author:** Claude (orchestrator)   **Date:** 2026-05-26
**Branch:** claude/oliver-extract
**Repo context:** heatsink-model — Jupyter notebook(s) and supporting files modeling thermal behavior, likely for battery / power-electronics heatsinking. Potentially safety-relevant for understanding pack thermal limits.

## Background

Oliver Krause originally authored this repo and is no longer with the company. He was the sole source of domain expertise. The code in this repo may be operationally relevant — running on field-deployed hardware that we now need to be able to troubleshoot ourselves.

This is **preservation work, not feature work.** The goal is to extract everything we can infer from the existing code, commit history, and artifacts into documentation that future agents and humans can rely on for diagnostics and reflashing.

## What to produce

Read every file in the repo end-to-end. Then write or refine:

1. **`README.md`** — top-level overview. What this is, what hardware it runs on, current status, link to extraction docs.
2. **`docs/architecture.md`** — internal-tier mental model. Modules / components, data flow, hardware interfaces, configuration parameters, anything the code clearly does.
3. **`docs/runbook.md`** — operational steps. How to build, how to flash (if firmware), how to read/debug. What each LED/button/serial output means. Any boot or fault sequences inferable from code.
4. **`docs/troubleshooting.md`** — failure modes inferred from fault-handling code paths, error logs, watchdog/timeout logic, defensive checks. For each failure mode: symptom, what the code does about it, what a human should check.
5. **`docs/llms.md`** — dense agent-facing doc per the Charter. File map, conventions, gotchas, cross-references.
6. **`service.yaml`** — refine the stub I left. Get language, stack, deploy, depends_on right based on what's actually in the repo.

## Hard rules for this extraction

- **Every claim must be traceable to source code or a specific commit.** No invention. If something is unclear, write "Unclear from the code — see <file:line> for the only context I could find." Do not fill gaps with plausible-sounding inference.
- **Every doc must open with this banner:**
  > ⚠️ This document was extracted from code and commit history by an LLM. No human EE / firmware / hardware expert reviewed it. It describes what the code does, not what is safe, correct, or sufficient. Treat as a starting point for diagnostics, not as authoritative.
- Cite the file and line for non-trivial claims. e.g., "Charge current is written to register CURVE_CC (`chg_control.c:42`)."
- Where commit messages provide context that the code doesn't, cite the commit SHA.
- If the repo is mostly artifacts (KiCad, Eagle, Jupyter), produce an inventory document rather than forcing the "module" frame.

## What Codex will look at hardest in review

Subsequent Codex review passes will scrutinize:
- Hallucinated claims (anything stated without a code/commit citation).
- Missed failure modes (error paths in the code that the troubleshooting doc didn't surface).
- Wrong hardware claims (pin assignments, register addresses, etc. that don't match the source).
- Vague language that masks lack of understanding ("typically", "generally", "should").
- Whether the README + architecture + runbook + troubleshooting + llms set is internally consistent.

The loop continues until Codex writes a `oliver-extract-codex-resolution.md` confirming no remaining concerns.

## How to verify after writing

1. Open every file you wrote and confirm every non-trivial claim has a citation.
2. Confirm the limitation banner is at the top of every `docs/*.md` you produced.
3. Run `fieldpack validate` if/when the Shopkeep CLI is available (this is forward-looking; skip for now if the CLI doesn't exist on this machine).
4. Reply with your output at `docs/reviews/oliver-extract-codex-response.md`.
