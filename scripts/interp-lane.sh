#!/usr/bin/env bash
# interp-lane: run `bend <file.bend> -- <args>` as the interpreter lane and drop
# the note the CLI prints on stderr BEFORE the program runs: in 2.0.16 one line
# when the book has @unsafe defs or template instances,
#   "All terms check, with N unsafe annotation(s)."
# and since 2.0.18 a block when a def reaches @unsafe or FOREIGN code (this
# port's shell reaches its custom effects),
#   "All terms check, but N defs rely on unsafe or foreign code:" + "- <def>" lines.
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
# The note belongs to the BOOK, not to the case: without a cache every case of a
# lane run recomputes the same text with a full type-check (19 s for this port
# under bend 2.0.20). The key is the CLI words plus the name, size and mtime of
# every source file below the program's directory, so any edit to the book makes
# a new key. An empty cache file means "this book prints no note".
cache=""
if [[ -n "$file" && $emit -eq 0 && ${#cli[@]} -gt 0 ]]; then
  key="$( { printf '%s\n' "${cli[@]}" "$file"; cd "$(dirname "$file")" && find . -type f \( -name '*.bend' -o -name '*.c' -o -name '*.js' \) -printf '%p %s %T@\n' | LC_ALL=C sort; } 2>/dev/null | cksum | cut -d' ' -f1)"
  cache="${TMPDIR:-/tmp}/interp-note.$(id -u).$key"
fi
if [[ -n "$cache" && -f "$cache" ]]; then
  note="$(cat "$cache")"; lines="$(wc -l < "$cache")"
elif [[ -n "$file" && $emit -eq 0 && ${#cli[@]} -gt 0 ]]; then
  if "${cli[@]}" "$file" -o "$TMP/check.js" >"$TMP/check.out" 2>"$TMP/check.err"; then
    first="$(head -1 "$TMP/check.err")"
    # 2.0.16: one line, "All terms check, with N unsafe annotation(s)."
    # 2.0.18+ (this port's pin is 2.0.20; VERSION-DRIFT, OQ-009): a BLOCK,
    #   "All terms check, but N defs rely on unsafe or foreign code:" and then
    #   one "- <def>" line per def. The note is whatever the check-only
    #   emission printed, whole; its line count is `lines`.
    if [[ "$first" =~ ^All\ terms\ check,\ with\ [1-9][0-9]*\ unsafe\ annotations?\.$ ]]; then
      note="$first"; lines=1
    elif [[ "$first" =~ ^All\ terms\ check,\ but\ [1-9][0-9]*\ defs?\ rel(y|ies)\ on\ unsafe\ or\ foreign\ code:$ ]]; then
      note="$(cat "$TMP/check.err")"; lines="$(wc -l < "$TMP/check.err")"
    fi
    # remember the verdict for this exact book (an empty file when it printed no note)
    if [[ -n "$note" ]]; then printf '%s\n' "$note" >> "$cache"; else : >> "$cache"; fi
  fi
fi
"$@" 2>"$TMP/err"; ec=$?
# Remove the note only when the run's stderr BEGINS with exactly the lines the
# compiler printed for this book; anything else passes through untouched.
if [[ -n "$note" && "$(head -n "${lines:-1}" "$TMP/err")" == "$note" ]]; then
  { printf '%s\n' "$note" >&3; } 2>/dev/null || true
  tail -n +"$(( ${lines:-1} + 1 ))" "$TMP/err" >&2
else
  cat "$TMP/err" >&2
fi
exit $ec
