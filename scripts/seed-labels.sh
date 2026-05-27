#!/usr/bin/env bash
# seed-labels.sh
# One-time bootstrap of GitHub labels for the multi-agent workflow.
# Idempotent: re-running updates existing labels rather than failing.

set -euo pipefail

cd "$(dirname "$0")/.."

declare -a LABELS=(
  "needs:claude|1f77b4|Inbox: Claude should act on this next"
  "needs:codex|9467bd|Inbox: Codex should act on this next"
  "needs:human|d62728|Inbox: human (Amit) needs to decide"
  "from:claude|aec7e8|Author tag — last action by Claude"
  "from:codex|c5b0d5|Author tag — last action by Codex"
  "from:human|ff9896|Author tag — last action by human"
  "kind:review|2ca02c|Code review thread"
  "kind:task|ff7f0e|Implementation task"
  "kind:blocker|8c564b|Open question that blocks progress"
  "kind:decision|17becf|Architectural or process decision under discussion"
)

for entry in "${LABELS[@]}"; do
  IFS='|' read -r name color desc <<<"$entry"
  if gh label list --json name -q '.[].name' | grep -qxF "$name"; then
    gh label edit "$name" --color "$color" --description "$desc" >/dev/null
    echo "updated  $name"
  else
    gh label create "$name" --color "$color" --description "$desc" >/dev/null
    echo "created  $name"
  fi
done
