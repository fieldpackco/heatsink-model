#!/usr/bin/env bash
# autopilot-watchdog.sh
# Diagnoses + self-heals the autopilot dispatcher for the current repo.
#
# Checks every POLL_INTERVAL seconds (default 60):
#
#   1. Is autopilot.sh running for THIS repo's docs/reviews/ ?
#        - If not: restart it (nohup) and log.
#   2. Is fswatch running for THIS repo's docs/reviews/ ?
#        - If autopilot.sh is alive but fswatch is dead: autopilot's loop has
#          dropped out. Restart autopilot (the catch-up scan on start will
#          pick up anything that landed during the gap).
#   3. Are there pending actionable artifacts in docs/reviews/ without a
#      .dispatched lock that have been sitting for > STALE_PENDING_SECS ?
#        - fswatch may have missed the Create event. Touch the file via
#          rename-out-and-back to force a fresh fswatch event.
#   4. Are there .dispatched locks older than STUCK_DISPATCH_MINS without a
#      matching response/resolution sibling?
#        - Probably a crashed subprocess. Log a warning. Do NOT auto-clear
#          the lock — that could double-dispatch real work; require human.
#
# Usage:
#   ./scripts/autopilot-watchdog.sh                     # foreground loop
#   nohup ./scripts/autopilot-watchdog.sh >/dev/null 2>&1 &
#
# Recommended deployment: install as a launchd `KeepAlive` job so the
# watchdog itself self-restarts. The template ships a sample plist at
# scripts/autopilot-watchdog.plist.example.
#
# Requires: pgrep, fswatch (so autopilot.sh can restart cleanly), nohup, mv.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
WATCH_DIR="$REPO_ROOT/docs/reviews"
STATE_DIR="$REPO_ROOT/.agent-state/autopilot"
LOG_FILE="$REPO_ROOT/.agent-state/watchdog.log"
PID_FILE="$REPO_ROOT/.agent-state/autopilot.pid"
AUTOPILOT="$REPO_ROOT/scripts/autopilot.sh"

POLL_INTERVAL="${WATCHDOG_POLL_INTERVAL:-60}"      # seconds between checks
STALE_PENDING_SECS="${WATCHDOG_STALE_PENDING_SECS:-120}"  # missed-event threshold
STUCK_DISPATCH_MINS="${WATCHDOG_STUCK_DISPATCH_MINS:-25}" # max codex/claude run = ~20m

mkdir -p "$STATE_DIR"
touch "$LOG_FILE"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

# ---- Checks --------------------------------------------------------------

# Is autopilot.sh running for THIS repo? The PID file is the authoritative
# signal: autopilot writes it on start, removes it on exit via trap. A pgrep
# fallback would falsely match orphan subshells (the `fswatch | while ...`
# consumer is a child shell process with the same cmdline as the parent,
# and survives parent SIGTERM unless the whole pgrp is killed). We require
# the PID file AND a live PID; anything else means the dispatcher is gone
# even if zombie children are still running, and the restart path cleans
# those up.
autopilot_alive() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid=$(cat "$PID_FILE" 2>/dev/null)
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

# Aggressive cleanup: kill any autopilot.sh subshell and any fswatch on
# this repo's watch dir, regardless of whether they're parents or children.
# Used by restart_autopilot to make sure a fresh autopilot doesn't compete
# with zombie subshells / fswatches from the previous run.
kill_orphans() {
  local pid cwd
  for pid in $(pgrep -f "scripts/autopilot.sh" 2>/dev/null); do
    cwd=$(lsof -p "$pid" 2>/dev/null | awk '$4=="cwd" {print $NF; exit}')
    if [[ "$cwd" == "$REPO_ROOT" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  for pid in $(pgrep -fl fswatch 2>/dev/null | grep "$WATCH_DIR" | awk '{print $1}'); do
    kill "$pid" 2>/dev/null || true
  done
}

fswatch_alive() {
  pgrep -fl "fswatch .* $WATCH_DIR" 2>/dev/null | grep -v grep >/dev/null
}

restart_autopilot() {
  log "watchdog: restarting autopilot ($AUTOPILOT)"
  kill_orphans
  rm -f "$PID_FILE"
  sleep 1
  nohup "$AUTOPILOT" >/dev/null 2>&1 &
  disown
  sleep 3
  if autopilot_alive; then
    log "watchdog: autopilot restarted OK"
  else
    log "watchdog: ERROR — autopilot failed to come back up; will retry next cycle"
  fi
}

# Walk pending request/response files in docs/reviews/. A file is "stuck
# pending" if it's older than STALE_PENDING_SECS and has no .dispatched
# lock — fswatch must have missed the event when it landed.
poke_stale_pending() {
  [[ -d "$WATCH_DIR" ]] || return 0
  local now
  now=$(date +%s)
  local poked=0
  while IFS= read -r path; do
    [[ -f "$path" ]] || continue
    local base
    base="$(basename "$path")"
    # Only request / response files are actionable; resolutions / notes /
    # human-decision files are informational.
    case "$base" in
      *-claude-request.md|*-claude-response.md|*-codex-request.md|*-codex-response.md) ;;
      *) continue ;;
    esac
    local lock="$STATE_DIR/${base}.dispatched"
    [[ -e "$lock" ]] && continue
    local mtime
    mtime=$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo "$now")
    local age=$((now - mtime))
    if (( age > STALE_PENDING_SECS )); then
      log "watchdog: poking stale pending $base (age=${age}s)"
      # Rename-out-and-back to force fswatch Created+Renamed events.
      local tmp="${path}.watchdog-poke-$$"
      if mv "$path" "$tmp" 2>/dev/null && mv "$tmp" "$path" 2>/dev/null; then
        poked=$((poked + 1))
      else
        log "watchdog: WARN — could not rename $base for poke"
      fi
    fi
  done < <(ls -1 "$WATCH_DIR"/*.md 2>/dev/null)
  if (( poked > 0 )); then
    log "watchdog: poked $poked stale artifact(s)"
  fi
}

# Surface stuck dispatches — .dispatched lock older than STUCK_DISPATCH_MINS
# without a sibling response / resolution file. Don't auto-clear; a stuck
# dispatch with the work half-done is ambiguous (was it written? was it
# pushed? clearing the lock could double-fire).
warn_stuck_dispatches() {
  [[ -d "$STATE_DIR" ]] || return 0
  local cutoff=$((STUCK_DISPATCH_MINS * 60))
  local now
  now=$(date +%s)
  while IFS= read -r lock; do
    [[ -f "$lock" ]] || continue
    local base
    base="$(basename "$lock" .dispatched)"
    # A dispatch is resolved only when the EXPECTED reply author has written a
    # response/resolution that is NEWER than the lock. Deriving the reply author
    # from the locked artifact matters: a response-round lock
    # (e.g. some-topic-claude-response.md.dispatched) is itself a *-response.md,
    # so a topic-only `*-response.md` glob would match the locked artifact and
    # silently self-resolve. We instead look only for the other agent's reply.
    # The `-newer "$lock"` guard stops a stale earlier-round reply for the same
    # base topic from false-resolving a newer dispatch.
    local reply_author
    case "$base" in
      *-claude-request.md|*-claude-response.md) reply_author=codex ;;
      *-codex-request.md|*-codex-response.md)   reply_author=claude ;;
      *) continue ;;  # not a dispatch lock we recognize
    esac
    local topic
    topic="$(echo "$base" | sed -E 's/-(claude|codex)-(request|response)\.md$//' | sed -E 's/-r[0-9]+$//')"
    # Match ONLY the exact base topic plus an optional -r<N> round suffix — never a
    # prefix-greedy glob. Topic families like phase2c-execution / phase2c-execution-iii
    # coexist in this repo, so a `${topic}*-...` glob would let an unrelated
    # phase2c-execution-iii reply false-resolve a stuck phase2c-execution lock.
    # Broad-glob via find, then anchor-filter basenames to the four legal reply
    # shapes: ${topic}[-r<N>]-${reply_author}-{response,resolution}.md.
    local reply_re="^${topic}(-r[0-9]+)?-${reply_author}-(response|resolution)\.md$"
    local resolved=0
    while IFS= read -r match; do
      [[ -n "$match" ]] || continue
      if [[ "$(basename "$match")" =~ $reply_re ]]; then
        resolved=1
        break
      fi
    done < <(find "$WATCH_DIR" -maxdepth 1 -type f -newer "$lock" \
              -name "${topic}*-${reply_author}-*.md" 2>/dev/null)
    if (( resolved )); then
      continue
    fi
    local mtime
    mtime=$(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null || echo "$now")
    local age=$((now - mtime))
    if (( age > cutoff )); then
      log "watchdog: WARN — dispatch '$base' stuck for ${age}s (lock $lock); investigate manually before clearing"
    fi
  done < <(ls -1 "$STATE_DIR"/*.dispatched 2>/dev/null)
}

# ---- Main loop -----------------------------------------------------------

log "watchdog: started (PID $$, watching $WATCH_DIR, poll=${POLL_INTERVAL}s)"

while true; do
  if ! autopilot_alive; then
    log "watchdog: autopilot is DOWN"
    restart_autopilot
  elif ! fswatch_alive; then
    log "watchdog: autopilot alive but fswatch is DOWN — restarting autopilot"
    restart_autopilot
  else
    poke_stale_pending
    warn_stuck_dispatches
  fi
  sleep "$POLL_INTERVAL"
done
