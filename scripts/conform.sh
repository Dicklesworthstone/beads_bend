#!/usr/bin/env bash
# conform: compare every case's stdout, stderr and exit with captured goldens.
# usage: conform.sh <cases.tsv> <goldens-dir> [--lane NAME] [--no-stderr]
#          [--timeout S] [--oracle-command JSON] -- <port command...>
# TSV: name<TAB>argv[<TAB>stdin-file[<TAB>annotation...]]. argv is a JSON string
# array or legacy whitespace-separated words; no shell interpretation occurs.
# Default timeout: 5 seconds per case. Missing input/executable, signals and
# reserved exits 124..255 are INCONCLUSIVE, never matching passes (including
# timeout's 125 and shell-wrapped signals). Stdin must be a regular file.
# New golden manifests identify the original automatically; for older ones,
# supply --oracle-command '["python3","legacy/tool.py"]'. Exact command identity
# is checked, not semantic equivalence of arbitrary wrappers. Use floor.sh for
# original-on-original runs. The last stdout line is the JSON scorecard.
# Exit: 0 PASS, 1 FAIL/INCONCLUSIVE, 2 usage/invalid manifest.
set -uo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
  exit 0
fi
exec python3 -B "$(dirname "$0")/case_manifest.py" conform "$@"
