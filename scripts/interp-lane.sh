#!/usr/bin/env bash
# interp-lane: run `bend <file.bend> -- <args>` as the interpreter lane and drop
# the note the CLI prints on stderr BEFORE the program runs:
#   2.0.13-2.0.16  one line when the book has @unsafe defs or (2.0.16) template
#                  instances: "All terms check, with N unsafe annotation(s)."
#   2.0.17+        a BLOCK naming every def that relies on @unsafe (2.0.18+: or
#                  on FOREIGN code — every program that calls a custom effect):
#                  "All terms check, but N defs rely on unsafe or foreign code:"
#                  followed by one "- <def>" line per def (the 2.0.17 header,
#                  before foreign reliance was counted, was not observed: both
#                  "... unsafe code:" and "... unsafe or foreign code:" match).
# The note is the checker's, not the program's stderr; the goldens were
# captured from the original, which never prints it. Everything else on
# stderr, all of stdout and the exit code pass through unchanged. The note is
# removed only when the run's stderr BEGINS with exactly the lines the
# check-only emission printed for this program; otherwise stderr is untouched
# (a program that dies before printing keeps its message). The dropped note is
# written once to fd 3 when the caller opened it (lanes.sh does: it prints
# "interpreter note: ..." after the lane row so the count stays visible).
#
# stderr is captured through a PIPE, as on every other lane and as at capture
# time: a plain file would change what `-o /dev/stderr` means (the program's
# second open of the file starts at offset 0 and the writers overwrite each
# other).
#
# INTERP_NOTE_CACHE=1 (opt-in): the note belongs to the PROGRAM, not to the
# case, so on a large port it is computed once and cached under TMPDIR, keyed
# on the CLI words, the bytes of every file among them (a wrapper, `bun`'s
# `bend2/main.ts` and the other `bend2/*.ts` of that checkout), the binary
# `BEND_BIN` names (a wrapper's target), and the content of every
# .bend/.c/.js file below the program's directory (without it each case pays a
# second full type-check: beads_bend 46 s -> 17 s per case). Leave it unset
# when the compiler's note can change for another reason (a compiler under
# test driven by environment variables). Inside a sandbox, TMPDIR must be
# writable or the cache is skipped.
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
note=""; lines=1; cache=""
if [[ "${INTERP_NOTE_CACHE:-0}" == 1 && -n "$file" && $emit -eq 0 && ${#cli[@]} -gt 0 ]]; then
  # content-keyed (POSIX cksum, no GNU find -printf): an edit to the program or a new compiler makes a new key
  compiler=()   # every file that decides what the compiler prints
  for w in "${cli[@]}"; do
    p="$(command -v "$w" 2>/dev/null || true)"; [[ -f "$w" ]] && p="$w"
    [[ -n "$p" && -f "$p" ]] && compiler+=("$p")
    [[ "$w" == */bend2/main.ts && -d "${w%/main.ts}" ]] && for t in "${w%/main.ts}"/*.ts; do [[ -f "$t" ]] && compiler+=("$t"); done
  done
  [[ -n "${BEND_BIN:-}" && -f "$BEND_BIN" ]] && compiler+=("$BEND_BIN")
  key="$( { printf '%s\n' "${cli[@]}" "$file"; for c in "${compiler[@]}"; do cksum < "$c"; done
            ( cd "$(dirname "$file")" && find . -type f \( -name '*.bend' -o -name '*.c' -o -name '*.js' \) | LC_ALL=C sort | while IFS= read -r f; do printf '%s ' "$f"; cksum < "$f"; done ); } 2>/dev/null | cksum | cut -d' ' -f1)"
  [[ -n "$key" ]] && cache="${TMPDIR:-/tmp}/interp-note.$(id -u).$key"
fi
if [[ -n "$cache" && -f "$cache" ]]; then
  note="$(cat "$cache")"; [[ -z "$note" ]] || lines="$(printf '%s\n' "$note" | wc -l | tr -d ' ')"
elif [[ -n "$file" && $emit -eq 0 && ${#cli[@]} -gt 0 ]]; then
  if "${cli[@]}" "$file" -o "$TMP/check.js" >"$TMP/check.out" 2>"$TMP/check.err"; then
    first="$(head -1 "$TMP/check.err")"
    if [[ "$first" =~ ^All\ terms\ check,\ with\ [1-9][0-9]*\ unsafe\ annotations?\.$ ]]; then
      note="$first"; lines=1
    elif [[ "$first" =~ ^All\ terms\ check,\ but\ [1-9][0-9]*\ defs?\ rel(y|ies)\ on\ unsafe(\ or\ foreign)?\ code:$ ]]; then
      note="$(cat "$TMP/check.err")"; lines="$(wc -l < "$TMP/check.err" | tr -d ' ')"
    fi
    # remember the verdict for this exact program (an empty file means "prints no note")
    if [[ -n "$cache" ]]; then
      if [[ -n "$note" ]]; then printf '%s\n' "$note" > "$cache.$$" 2>/dev/null; else : > "$cache.$$" 2>/dev/null; fi
      mv -f "$cache.$$" "$cache" 2>/dev/null || true
    fi
  fi
fi
{ "$@" 2>&1 >&4 4>&- | cat > "$TMP/err"; ec=${PIPESTATUS[0]}; } 4>&1
if [[ -n "$note" && "$(head -n "$lines" "$TMP/err")" == "$note" ]]; then
  { printf '%s\n' "$note" >&3; } 2>/dev/null || true
  tail -n +"$(( lines + 1 ))" "$TMP/err" >&2
else
  cat "$TMP/err" >&2
fi
exit "$ec"
