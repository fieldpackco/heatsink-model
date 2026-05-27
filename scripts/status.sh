#!/usr/bin/env bash
# status.sh
# One-command status check for the multi-agent autopilot workflow.
# Works from any device with a clone of the repo + gh CLI.
#
# Shows:
#   1. .agent-state/current.md (committed dashboard)
#   2. Open GitHub issues, grouped by needs:* label (the inbox)
#   3. Recent branches by author (who's working on what)
#   4. Local fswatch pending logs, if present
#   5. Recent commits

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

bold()    { printf '\033[1m%s\033[0m\n' "$*"; }
dim()     { printf '\033[2m%s\033[0m\n' "$*"; }
section() { printf '\n'; bold "── $* ──"; }

REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')"

section "agent-state dashboard"
if [[ -f .agent-state/current.md ]]; then
  cat .agent-state/current.md
else
  dim "(no .agent-state/current.md yet)"
fi

if [[ -n "$REPO_SLUG" ]]; then
  section "open issues by inbox label  ($REPO_SLUG)"
  for label in needs:claude needs:codex needs:human; do
    bold "$label"
    out="$(gh issue list --label "$label" --state open \
      --json number,title,updatedAt \
      --template '{{range .}}  #{{.number}}  {{.title}}  ({{timeago .updatedAt}}){{"\n"}}{{end}}' \
      2>/dev/null || true)"
    if [[ -n "$out" ]]; then
      printf '%s' "$out"
      [[ "$out" == *$'\n' ]] || printf '\n'
    else
      dim "  (none)"
    fi
  done

  section "recent branches (last 10)"
  git fetch --quiet 2>/dev/null || true
  git for-each-ref --sort=-committerdate refs/remotes/origin \
    --format='  %(refname:short)  %(committerdate:relative)  %(authorname)' \
    | grep -v 'origin/HEAD' | head -10 || dim "  (no remote branches)"
else
  section "github"
  dim "  not on github yet (run: gh repo create <owner>/<repo> --private --source=. --push)"
fi

section "local fswatch inbox (this mac only)"
for who in claude codex; do
  log=".claude/pending-for-$who.log"
  if [[ -f "$log" && -s "$log" ]]; then
    bold "pending-for-$who"
    awk 'NF' "$log" | tail -10 | sed 's/^/  /'
  fi
done

section "recently changed (last 7 days)"
git log --since='7 days ago' --pretty=format:'  %h  %ad  %an  %s' --date=short 2>/dev/null \
  | head -15 || dim "  (no commits yet)"

printf '\n'
