#!/usr/bin/env bash
# floor: repeat the ORIGINAL against its goldens to measure reproducibility.
# usage: floor.sh <cases.tsv> <goldens-dir> [--repeat K] [--no-stderr]
#          [--timeout S] -- <original command...>
# The sanctioned original-on-original path. Infrastructure failures are
# INCONCLUSIVE rather than evidence of nondeterminism. Default K=3, timeout=5s.
# Captured original argv/identity must match; legacy manifests without either
# report oracle_identity_checked=false. Changed source/inputs are INCONCLUSIVE.
# Last line JSON: repeat, stable, unstable, inconclusive, verdict.
# Exit: 0 STABLE, 1 UNSTABLE/INCONCLUSIVE, 2 usage/invalid manifest.
set -uo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
  exit 0
fi
exec python3 -B "$(dirname "$0")/case_manifest.py" floor "$@"
