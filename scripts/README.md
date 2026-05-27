# scripts/

Operational scripts for the multi-agent autopilot workflow. All committed to the repo so any clone on any device has them. See [`../docs/multi-agent-workflow.md`](../docs/multi-agent-workflow.md).

## `status.sh` — the status check

```
./scripts/status.sh
```

Reads `.agent-state/current.md`, hits the GitHub API via `gh`, prints open issues by inbox label, recent branches, recent commits, and the local fswatch pending logs (if present). Runs in ~1s. Use from any clone.

Requires `gh` CLI authenticated.

## `autopilot.sh` — the fswatch dispatcher (autonomous mode)

```
brew install fswatch    # one-time
./scripts/autopilot.sh  # foreground
```

Background:

```
nohup ./scripts/autopilot.sh >/dev/null 2>&1 &
```

Tail:

```
tail -f .agent-state/autopilot.log
```

Watches `docs/reviews/`. On `*-claude-*.md` fires `codex exec --dangerously-bypass-approvals-and-sandbox` against the repo; on `*-codex-*.md` fires `claude -p --dangerously-skip-permissions`. Resolution / note / handoff / human-authored files notify only. Lock files in `.agent-state/autopilot/` prevent re-dispatch on the agent's own writes.

Requires: `fswatch`, `codex`, `claude`, `gh` on PATH.

**Per-machine, opt-in.** Run only on the machine where you want autonomous building. Other clones get notifications via `watch-agents.sh` or nothing.

## `watch-agents.sh` — notifier (no dispatch)

```
./scripts/watch-agents.sh
```

Same fswatch hooks as `autopilot.sh` but only logs to `.claude/pending-for-<agent>.log` and fires a macOS notification. Use this on non-autopilot machines.

## `seed-labels.sh` — GitHub label bootstrap

```
./scripts/seed-labels.sh
```

Idempotently creates the inbox labels (`needs:claude`, `needs:codex`, `needs:human`, `kind:task`, `kind:review`, `kind:decision`, `from:claude`, `from:codex`, `from:human`) from `.github/labels.yml`. Safe to re-run.

## Auto-start on login (optional)

Create `~/Library/LaunchAgents/com.<your-org>.autopilot.plist` — substitute your own paths:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.example.autopilot</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>/absolute/path/to/your/repo/scripts/autopilot.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/absolute/path/to/your/repo/.agent-state/autopilot.out.log</string>
  <key>StandardErrorPath</key><string>/absolute/path/to/your/repo/.agent-state/autopilot.err.log</string>
</dict>
</plist>
```

Then `launchctl load` / `launchctl unload`.
