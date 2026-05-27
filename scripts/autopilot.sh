#!/usr/bin/env bash
# autopilot.sh
# fswatch-driven autonomous review loop for the sitrep multi-agent workflow.
#
# Watches docs/reviews/ and dispatches the OTHER agent (codex or claude) in
# --full-auto mode the moment a request/response artifact lands. Local files
# are the source of routing truth on this machine. Git is used for history
# and cross-device sync, not for inbox state.
#
# Filename convention (drives dispatch):
#   <topic>-<author>-<role>.md
#   author ∈ {claude, codex, human}
#   role   ∈ {request, response, resolution, note, handoff}
#
# Dispatch table:
#   *-claude-request.md   -> fire codex
#   *-codex-response.md   -> fire claude
#   *-codex-request.md    -> fire claude
#   *-claude-response.md  -> fire codex
#   *-*-resolution.md     -> no dispatch (loop closed)
#   *-human-*.md          -> notify only
#   *-*-note.md           -> notify only
#   *-*-handoff.md        -> notify only
#
# Each dispatched artifact is locked in .agent-state/autopilot/<artifact>.dispatched
# so the agent's own subsequent writes don't re-trigger the loop.
#
# Usage:
#   ./scripts/autopilot.sh                  # foreground (Ctrl-C to stop)
#   nohup ./scripts/autopilot.sh >/dev/null 2>&1 &
#
# Requires: fswatch, codex CLI, claude CLI, gh CLI.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WATCH_DIR="$REPO_ROOT/docs/reviews"
STATE_DIR="$REPO_ROOT/.agent-state/autopilot"
LOG_FILE="$REPO_ROOT/.agent-state/autopilot.log"
PID_FILE="$REPO_ROOT/.agent-state/autopilot.pid"

mkdir -p "$WATCH_DIR" "$STATE_DIR"
touch "$LOG_FILE"

# Write our PID so autopilot-watchdog.sh can detect liveness without
# relying on pgrep's command-line string-matching, which is brittle across
# absolute vs relative invocation paths. Cleared on normal exit; a stale
# file from a crashed run is harmless because watchdog falls back to
# kill -0 to check liveness.
echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT

for bin in fswatch codex claude gh gtimeout; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "autopilot: missing dependency '$bin'. Install before running." >&2
    [[ "$bin" == "gtimeout" ]] && echo "  (run: brew install coreutils)" >&2
    exit 1
  fi
done

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

notify() {
  local title="$1" body="$2"
  osascript -e "display notification \"$body\" with title \"$title\"" >/dev/null 2>&1 || true
}

# Returns the agent to dispatch (codex|claude|"") for a given artifact filename.
target_agent() {
  local base="$1"
  case "$base" in
    *-claude-request.md|*-claude-response.md)   echo "codex" ;;
    *-codex-request.md|*-codex-response.md)     echo "claude" ;;
    *) echo "" ;;
  esac
}

# Strip "-<author>-<role>" from the end of a basename to extract the topic slug.
topic_of() {
  local base="$1"
  echo "$base" | sed -E 's/-(claude|codex|human)-(request|response|resolution|note|handoff|decision)\.md$//'
}

# Compute a unique target filename in docs/reviews/ for a reply.
# Args: incoming-artifact-path, reply-author, reply-role
# If <topic>-<author>-<role>.md is free, returns it; otherwise returns the
# first available -r2, -r3, ... suffix. The returned path is relative to
# REPO_ROOT to keep the agent prompt concise.
compute_target() {
  local incoming="$1" reply_author="$2" reply_role="$3"
  local dir base topic candidate n prefix
  prefix="${REPO_ROOT}/"
  dir="$(dirname "$incoming")"
  base="$(basename "$incoming")"
  topic="$(topic_of "$base")"
  # Strip any existing -r<N> suffix from the topic so successive rounds use the
  # base topic (e.g. "feature-r2" → "feature").
  topic="$(echo "$topic" | sed -E 's/-r[0-9]+$//')"
  candidate="${dir}/${topic}-${reply_author}-${reply_role}.md"
  if [[ ! -e "$candidate" ]]; then
    echo "${candidate#$prefix}"
    return
  fi
  # Encode the round-counter as a TOPIC prefix segment (-r2-...), not a filename
  # suffix, so the dispatch globs ("*-claude-response.md") keep matching.
  n=2
  while [[ -e "${dir}/${topic}-r${n}-${reply_author}-${reply_role}.md" ]]; do
    n=$((n+1))
  done
  candidate="${dir}/${topic}-r${n}-${reply_author}-${reply_role}.md"
  echo "${candidate#$prefix}"
}

dispatch_codex() {
  local artifact="$1" base target_response target_resolution
  base="$(basename "$artifact")"
  target_response="$(compute_target "$artifact" codex response)"
  target_resolution="$(compute_target "$artifact" codex resolution)"
  log "dispatching codex on $base"
  notify "autopilot" "codex working on $base"

  local prompt
  prompt=$(cat <<EOF
You are Codex running in --full-auto autopilot mode inside the sitrep workspace.

Before doing anything else: read AGENTS.md and docs/multi-agent-workflow.md.

A new artifact from Claude is waiting for you:
  $artifact

Write your reply at one of these EXACT paths (do not invent a different name):
- ${target_response}    — for a further response (you have findings or want another round).
- ${target_resolution}  — ONLY if the loop is genuinely closed (you have no remaining concerns).

After writing:
- Commit (descriptive message, Co-Authored-By footer for Codex) and push to origin/<current-branch>.
- Find the matching GitHub issue (kind:review with this topic) and flip its label from needs:codex to needs:claude using gh CLI. If your reply is a resolution AND nothing else needs human attention, flip to needs:human instead. If no matching issue exists, do not invent one.

Constraints:
- Stay on the current git branch. Do NOT push to origin/main; push to whatever branch is checked out.
- You may patch the design doc at docs/plans/ if that is the right way to address findings — autopilot allows it for design-doc work.
- Do not invent endpoints, columns, or fields. If the design doc does not specify it, raise the gap as a finding rather than inventing.
- Push back if Claude got something wrong. Do not rubber-stamp.
EOF
)
  # Hard timeout protects against codex's post-completion hang (process stays alive
  # at 0% CPU after writing its work). 20 min is generous; observed runs complete
  # in 5–10 min.
  gtimeout --kill-after=10s 1200 codex exec \
    --dangerously-bypass-approvals-and-sandbox \
    -C "$REPO_ROOT" \
    "$prompt" \
    </dev/null \
    >>"$LOG_FILE" 2>&1 \
    && log "codex finished on $base" \
    || log "codex FAILED on $base (see log)"
}

dispatch_claude() {
  local artifact="$1" base target_response target_resolution
  base="$(basename "$artifact")"
  target_response="$(compute_target "$artifact" claude response)"
  target_resolution="$(compute_target "$artifact" claude resolution)"
  log "dispatching claude on $base"
  notify "autopilot" "claude working on $base"

  local prompt
  prompt=$(cat <<EOF
You are Claude running in autopilot mode inside the sitrep workspace.

Before doing anything else: read AGENTS.md and docs/multi-agent-workflow.md.

A new artifact from Codex is waiting for you:
  $artifact

Write your reply at one of these EXACT paths (do not invent a different name):
- ${target_response}    — for a further response (you accept findings + need another codex pass, or have pushback).
- ${target_resolution}  — ONLY if the loop is genuinely closed.

After writing:
- Commit (descriptive message, Co-Authored-By footer) and push to origin/<current-branch>.
- Find the matching GitHub issue and flip its label from needs:claude to needs:codex using gh CLI. If your reply is a resolution AND nothing else needs human attention, flip to needs:human instead. If no matching issue exists, do not invent one.

Constraints:
- Stay on the current git branch. Do NOT push to origin/main; push to whatever branch is checked out.
- You may patch the design doc at docs/plans/ if that is the right way to address codex findings — autopilot allows it for design-doc work.
- Do not invent endpoints, columns, or fields. If the design doc does not specify it, raise the gap as a finding rather than inventing.
- Push back on bad findings from codex. Do not rubber-stamp.
EOF
)
  gtimeout --kill-after=10s 1200 claude -p "$prompt" \
    --dangerously-skip-permissions \
    </dev/null \
    >>"$LOG_FILE" 2>&1 \
    && log "claude finished on $base" \
    || log "claude FAILED on $base (see log)"
}

route() {
  local path="$1" base agent lock
  base="$(basename "$path")"

  [[ "$base" == *.md ]] || return
  case "$base" in .*|README.md) return ;; esac

  agent="$(target_agent "$base")"
  if [[ -z "$agent" ]]; then
    case "$base" in
      *-human-*|*-note.md|*-handoff.md|*-resolution.md)
        log "no-dispatch (informational): $base"
        notify "sitrep autopilot" "informational: $base"
        ;;
      *) log "no-dispatch (unrecognized): $base" ;;
    esac
    return
  fi

  lock="$STATE_DIR/${base}.dispatched"
  if [[ -e "$lock" ]]; then
    log "skip (already dispatched): $base"
    return
  fi
  : > "$lock"

  case "$agent" in
    codex)  dispatch_codex  "$path" ;;
    claude) dispatch_claude "$path" ;;
  esac
}

log "autopilot watching $WATCH_DIR (PID $$)"
notify "sitrep autopilot" "started (PID $$)"

# Catch-up scan: process any actionable files that landed in docs/reviews/
# while autopilot was down. fswatch only emits events for changes that happen
# AFTER it starts watching, so a file pushed to the repo while the dispatcher
# was crashed (or in another worktree) would otherwise sit silently forever.
#
# `route` already checks the per-file `.dispatched` lock, so this is a no-op
# for anything already handled. Sorted by mtime so the oldest pending artifact
# fires first — preserves rough request/response ordering across restarts.
scan_pending() {
  local n=0
  while IFS= read -r path; do
    [[ -f "$path" ]] || continue
    local base lock
    base="$(basename "$path")"
    lock="$STATE_DIR/${base}.dispatched"
    if [[ -e "$lock" ]]; then continue; fi
    local agent
    agent="$(target_agent "$base")"
    # Only catch up actionable artifacts (request/response). Informational
    # ones (resolution, note, handoff, human decision) don't have dispatch
    # side effects worth replaying.
    if [[ -z "$agent" ]]; then continue; fi
    log "catch-up: routing pending $base"
    route "$path"
    n=$((n+1))
  done < <(ls -tr "$WATCH_DIR"/*.md 2>/dev/null)
  if [[ $n -gt 0 ]]; then
    log "catch-up: routed $n pending artifact(s)"
  fi
}

scan_pending

# Run fswatch and process events. If fswatch (or the pipe consumer) ever exits
# we log it explicitly — the previous version exited silently when fswatch
# crashed, which made "autopilot is down" look identical to "autopilot is just
# quiet."
set +e
fswatch -0 --event Created --event Renamed --event Updated "$WATCH_DIR" \
  | while IFS= read -r -d '' path; do
      [[ -f "$path" ]] || continue
      route "$path"
    done
fswatch_status=$?
log "autopilot: fswatch loop exited (status $fswatch_status) — run /start-autopilot to resume"
notify "sitrep autopilot" "stopped (PID $$)"
exit "$fswatch_status"
