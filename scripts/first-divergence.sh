#!/usr/bin/env bash
# first-divergence: compare one case's stdout, stderr and exit with goldens.
# usage: first-divergence.sh <case> <cases.tsv> <goldens-dir> [--timeout S]
#          -- <port command...>
# Reports a heuristic EXIT, MESSAGE, ORDER, NUMERIC, FORMAT, MISSING, EXTRA,
# TEXT or NO-GOLDEN class and the relevant spec section. Missing stderr or
# exit goldens cannot pass. Execution failures are INCONCLUSIVE. Default 5s.
# TSV argv accepts JSON string arrays or legacy whitespace-separated words.
# Last line JSON: case, class, open, detail. Exit 0 match, 1 mismatch, 2 usage.
set -uo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
  exit 0
fi
exec python3 -B "$(dirname "$0")/case_manifest.py" first "$@"
