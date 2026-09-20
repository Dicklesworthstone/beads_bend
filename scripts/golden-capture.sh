#!/usr/bin/env bash
# golden-capture: freeze the ORIGINAL's stdout, stderr and exit per case.
# usage: golden-capture.sh <cases.tsv> <goldens-dir> [--timeout S]
#          [--repin "reason" | --disc DISC-nnn] -- <original command...>
# TSV argv accepts JSON string arrays or legacy whitespace-separated words.
# Timeout defaults to 5 seconds. Empty/invalid manifests and infrastructure
# failures are refused before any golden is changed. A recapture requires a
# reason and preserves all previous files in a new TMPDIR backup directory.
# MANIFEST.txt records full SHA-256 digests, lossless original_argv JSON and
# resolved original_identity. Stdin must be a regular file; symlink golden
# destinations are refused. Source/input changes during capture are inconclusive.
# Exit: 0 captured, 1 inconclusive run, 2 usage, 3 recapture refused.
set -uo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
  exit 0
fi
exec python3 -B "$(dirname "$0")/case_manifest.py" capture "$@"
