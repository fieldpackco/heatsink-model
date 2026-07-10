#!/usr/bin/env bash
# Layer 1: write-time validator. Runs in the repo's CI and locally.
# Delegates to the vendored Fieldpack validator; this script is propagated
# verbatim from fieldpackco/Shopkeep and must not be edited locally.

set -euo pipefail

if ! command -v node >/dev/null 2>&1; then
  echo "validate.sh: node not found — install Node 20+ and retry" >&2
  exit 2
fi

node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
if [[ ! "$node_major" =~ ^[0-9]+$ ]] || (( node_major < 20 )); then
  echo "validate.sh: Node 20+ required (found ${node_major:-unknown})" >&2
  exit 2
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
repo_root="$(cd "$script_dir/../.." && pwd -P)"
validator="$script_dir/../bin/fieldpack-validate.mjs"

if [[ ! -f "$validator" ]]; then
  echo "validate.sh: vendored validator missing at .fieldpack/bin/fieldpack-validate.mjs" >&2
  exit 2
fi

cd "$repo_root"
exec node "$validator" "$@"
