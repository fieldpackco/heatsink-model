#!/usr/bin/env bash
# watch-agents.sh
# Bidirectional local notifier for the multi-agent autopilot workflow.
#
# Watches docs/reviews/ and docs/notes/ for new files. When an agent (claude
# or codex) drops an artifact, fires a macOS notification AND appends to the
# OTHER agent's pending log. This is a LOCAL SPEEDUP only — GitHub is the
# canonical store. Don't rely on this for correctness across devices.
#
# Filename convention:
#   <topic>-<author>-<role>.md
#   author ∈ {claude, codex, human}
#   role   ∈ {request, response, resolution, note, handoff}
#
# Usage:
#   ./scripts/watch-agents.sh              # foreground
#   nohup ./scripts/watch-agents.sh &      # background
#   See scripts/README.md for launchd auto-start.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WATCH_DIRS=("$REPO_ROOT/docs/reviews" "$REPO_ROOT/docs/notes")
STATE_DIR="$REPO_ROOT/.claude"
LOG_FILE="$STATE_DIR/watch-agents.log"
CLAUDE_INBOX="$STATE_DIR/pending-for-claude.log"
CODEX_INBOX="$STATE_DIR/pending-for-codex.log"

mkdir -p "${WATCH_DIRS[@]}" "$STATE_DIR"
touch "$LOG_FILE" "$CLAUDE_INBOX" "$CODEX_INBOX"

if ! command -v fswatch >/dev/null 2>&1; then
  echo "fswatch not installed. Run: brew install fswatch" >&2
  exit 1
fi

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

notify() {
  local title="$1" body="$2"
  osascript -e "display notification \"$body\" with title \"$title\"" >/dev/null 2>&1 || true
}

route() {
  local path="$1"
  local base
  base="$(basename "$path")"

  # Skip dotfiles, READMEs, and anything not ending in .md
  case "$base" in
    .*|README.md|*.md) ;;
    *) return ;;
  esac
  [[ "$base" == *.md ]] || return

  # Infer author from filename: <topic>-<author>-<role>.md
  local author=""
  case "$base" in
    *-claude-*) author="claude" ;;
    *-codex-*)  author="codex" ;;
    *-human-*)  author="human" ;;
    *)
      # No author tag — log but don't route, since we don't know who wrote it.
      log "untagged file (no author): $base"
      return
      ;;
  esac

  case "$author" in
    claude)
      printf '%s\n' "$path" >> "$CODEX_INBOX"
      log "claude -> codex: $base"
      notify "autopilot: Codex action needed" "$base"
      ;;
    codex)
      printf '%s\n' "$path" >> "$CLAUDE_INBOX"
      log "codex -> claude: $base"
      notify "autopilot: Claude action needed" "$base"
      ;;
    human)
      printf '%s\n' "$path" >> "$CLAUDE_INBOX"
      printf '%s\n' "$path" >> "$CODEX_INBOX"
      log "human -> both: $base"
      notify "autopilot: human note dropped" "$base"
      ;;
  esac
}

log "watching ${WATCH_DIRS[*]} (PID $$)"

fswatch -0 --event Created --event Renamed "${WATCH_DIRS[@]}" \
  | while IFS= read -r -d '' path; do
      [[ -f "$path" ]] || continue
      route "$path"
    done
