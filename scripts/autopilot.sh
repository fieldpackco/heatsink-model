#!/usr/bin/env bash
# autopilot.sh
# fswatch-driven autonomous review loop for the Fieldpack multi-agent workflow.
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

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
REPO_NAME="$(basename "$REPO_ROOT")"
WATCH_DIR="$REPO_ROOT/docs/reviews"
STATE_DIR="$REPO_ROOT/.agent-state/autopilot"
LOG_FILE="$REPO_ROOT/.agent-state/autopilot.log"
PID_FILE="$REPO_ROOT/.agent-state/autopilot.pid"

mkdir -p "$WATCH_DIR" "$STATE_DIR"
touch "$LOG_FILE"

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

# Central-secrets warning (ADR 0005): if this repo's service.yaml declares any
# `secrets:` but no .env.local exists on disk, the wrapped service almost
# certainly can't boot. Warn, don't fail — the autopilot loop itself doesn't
# need the secrets, only the wrapped dev server / build does.
if [[ -f "$REPO_ROOT/service.yaml" ]] && grep -qE '^secrets:' "$REPO_ROOT/service.yaml"; then
  if [[ ! -f "$REPO_ROOT/.env.local" ]]; then
    log "WARN: service.yaml declares secrets but $REPO_ROOT/.env.local is absent;"
    log "      run \`fieldpack secrets sync\` from Shopkeep to populate it."
  fi
fi

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
You are Codex running in --full-auto autopilot mode inside the ${REPO_NAME} workspace (Fieldpack member repo).

Before doing anything else: read .fieldpack/AGENT_RULES.md and AGENTS.md.

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
You are Claude running in autopilot mode inside the ${REPO_NAME} workspace (Fieldpack member repo).

Before doing anything else: read .fieldpack/AGENT_RULES.md and AGENTS.md.

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
        notify "${REPO_NAME} autopilot" "informational: $base"
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

# PID-file contract: the watchdog (scripts/autopilot-watchdog.sh) treats
# .agent-state/autopilot.pid + a live `kill -0` as the authoritative liveness
# signal — a pgrep fallback false-matches orphan subshells. Write our PID on
# start and remove it on exit so the watchdog never restarts a healthy loop.
echo $$ > "$PID_FILE"
# Owner-safe cleanup: only remove the PID file if it still names *us*. The
# watchdog restart path (and any manual duplicate start) allows two autopilots
# to overlap briefly; an unconditional `rm -f` on EXIT would let the older
# process delete the newer one's liveness file, tricking the watchdog into
# restarting a healthy dispatcher.
cleanup_pidfile() {
  if [[ "$(cat "$PID_FILE" 2>/dev/null)" == "$$" ]]; then
    rm -f "$PID_FILE"
  fi
}
trap cleanup_pidfile EXIT
trap 'exit' INT TERM

log "autopilot watching $WATCH_DIR (PID $$)"
notify "${REPO_NAME} autopilot" "started (PID $$)"

fswatch -0 --event Created --event Renamed --event Updated "$WATCH_DIR" \
  | while IFS= read -r -d '' path; do
      [[ -f "$path" ]] || continue
      route "$path"
    done
