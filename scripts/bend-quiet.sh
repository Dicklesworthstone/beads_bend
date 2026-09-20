#!/usr/bin/env bash
# bend-quiet: run Bend and drop the checker's verdict line from stderr, keeping
# every other stderr byte, all of stdout and the exit code. Why: since 2.0.16 the
# interpreter lane (`bend file.bend -- args`) prints
#   All terms check, with N unsafe annotations.
# to STDERR at every run of a program that instantiates a Base template
# (List.sort, List.show, List.map, ...). conform.sh compares stderr byte for byte,
# so every interpreter case of a real port fails with stderr=DIFF although the
# program is correct. Use this wrapper as the CLI the harness calls:
#   BEND_REAL_CLI="bun /path/bend/bend2/main.ts" BEND_CLI="$PWD/scripts/bend-quiet.sh" ./scripts/lanes.sh ...
# (BEND_CLI is whitespace-split argv, so the wrapper path must not contain spaces.)
# The real CLI is $BEND_REAL_CLI (whitespace-split), else `bend` on PATH. Only the
# compiler-owned first note is removed after a check-only emission establishes it;
# a refusal, a runtime error or the program's own stderr pass through untouched.
# Stderr is buffered until the command exits (it is compared as a file, never
# interleaved with stdout by the harness).
#
# usage: bend-quiet.sh <bend arguments...>      e.g. bend-quiet.sh main.bend -- a b
# exit: the wrapped command's exit code; 2 usage; 127 when no real bend is found.
set -uo pipefail
if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; [[ $# -eq 0 ]] && exit 2; exit 0; fi
if [[ -n "${BEND_REAL_CLI:-}" ]]; then read -ra REAL <<<"$BEND_REAL_CLI"; else REAL=(bend); fi
[[ ${#REAL[@]} -gt 0 ]] || { echo 'bend-quiet: BEND_REAL_CLI is empty' >&2; exit 2; }
[[ "${REAL[0]}" == *bend-quiet.sh ]] && { echo "bend-quiet: BEND_REAL_CLI points at this wrapper (would recurse); set it to the real bend" >&2; exit 2; }
command -v "${REAL[0]}" >/dev/null 2>&1 || { echo "bend-quiet: no real bend (${REAL[0]}): set BEND_REAL_CLI" >&2; exit 127; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$HERE/interp-lane.sh" "${REAL[@]}" "$@"
