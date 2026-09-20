#!/usr/bin/env bash
# interp-lane: run `bend <file.bend> -- <args>` as the interpreter lane and drop
# the one stderr line the CLI prints BEFORE the program runs when the book has
# @unsafe defs or (2.0.16+) template instances:
#   "All terms check, with N unsafe annotation(s)."
# That line is the checker's note, not the program's stderr; the goldens were
# captured from the original, which never prints it. Everything else on
# stderr, all of stdout and the exit code pass through unchanged. When the
# first stderr line is anything else, stderr is untouched (a program that dies
# before printing keeps its message). The dropped line is written once to
# fd 3 when the caller opened it (lanes.sh does: it prints "interpreter note:
# …" after the lane row so the count stays visible).
# usage: interp-lane.sh <bend cli...> <file.bend> -- <program args...>
# exit: the program's exit code.
set -uo pipefail
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0; }
[[ $# -gt 0 ]] || { echo 'error: interp-lane needs a Bend command' >&2; exit 2; }
# bend-quiet already applies this filter. Nesting it could remove a second,
# identical line emitted by the application itself.
[[ "${1##*/}" != bend-quiet.sh ]] || exec "$@"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/interp-lane.XXXXXX")"
# Establish the compiler-owned note without running main. Pattern matching
# stderr alone would erase a program's legitimate "All terms check." output.
# JS emission runs the same book checker as C emission, with less setup work;
# the emitted file is never executed. The actual CLI invocation below is unchanged.
cli=(); file=""; emit=0
for arg in "$@"; do
  [[ "$arg" == -- ]] && break
  [[ "$arg" == -o ]] && emit=1
  if [[ -z "$file" && "$arg" == *.bend ]]; then file="$arg"
  elif [[ -z "$file" ]]; then cli+=("$arg"); fi
done
note=""
if [[ -n "$file" && $emit -eq 0 && ${#cli[@]} -gt 0 ]]; then
  if "${cli[@]}" "$file" -o "$TMP/check.js" >"$TMP/check.out" 2>"$TMP/check.err"; then
    first="$(head -1 "$TMP/check.err")"
    [[ "$first" =~ ^All\ terms\ check,\ with\ [1-9][0-9]*\ unsafe\ annotations?\.$ ]] && note="$first"
  fi
fi
"$@" 2>"$TMP/err"; ec=$?
if [[ -n "$note" && "$(head -1 "$TMP/err")" == "$note" ]]; then
  { printf '%s\n' "$note" >&3; } 2>/dev/null || true
  tail -n +2 "$TMP/err" >&2
else
  cat "$TMP/err" >&2
fi
exit $ec
