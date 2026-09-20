#!/usr/bin/env bash
# claims-lint: scan the port's claim-bearing documents (PORT_STATE, PORT_REPORT,
# DISCREPANCIES, perf/*.md, the README) for the phrases the method forbids.
# Two families:
#   deferrals (ledgers must carry a predicate, not a promise): "later" used as
#     a deferral (end of clause, or after fix/revisit/handle/address/do it/for/
#     until), "if it seems important", "we should revisit", "tracked
#     elsewhere", "TODO";
#   hedges (claims must name an artifact): "should be", "probably", "roughly",
#     "flaky", "usually passes", "within noise" without a cv figure on the
#     line, "100% parity" (exclusions make it false), "faster" with no digit on
#     the line, "verified" with no law/golden/lanes word on the line.
# Skipped: an explicit rule line (Forbidden: / never say / do not claim),
# the quoted word "later" itself, and a phrase glued to a hyphen
# (re-verified). "later" as a plain adverb of sequence ("a later line") is
# not flagged; only the deferral shapes are.
#
# usage: claims-lint.sh <file.md> [more files...]   (a missing requested file fails)
# exit: 0 clean, 1 hits (each printed as file:line: phrase | text), 2 usage or no file checked.
set -uo pipefail
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -eq 0 ]] && { usage; [[ $# -eq 0 ]] && exit 2; exit 0; }
hits=0; checked=0; missing=0
B='(^|[^a-z-])'; E='([^a-z-]|$)'    # word boundaries that do not split hyphenated words
hedges=("should be" "probably" "roughly" "flaky" "usually passes")
deferrals=("if it seems important" "we should revisit" "tracked elsewhere" "todo")
for f in "$@"; do
  [[ -f "$f" ]] || { echo "error: $f not found" >&2; missing=$((missing+1)); continue; }
  checked=$((checked+1)); n=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n+1)); l="$(printf '%s' "$line" | tr 'A-Z' 'a-z')"
    case "$l" in forbidden:*|'# forbidden '*|'- forbidden '*) continue;; esac
    # A quoted word is not permission to suppress unrelated claims on its line.
    l="${l//\"later\"/quoted-later}"; l="${l//\'later\'/quoted-later}"
    if printf '%s' "$l" | grep -qE '(never|do not) (say|claim|write|describe|call|use) '; then continue; fi
    hit() { printf '%s:%d: %s | %s\n' "$f" "$n" "$1" "${line:0:110}"; hits=$((hits+1)); }
    for ph in "${hedges[@]}" "${deferrals[@]}"; do
      printf '%s' "$l" | grep -qE "${B}${ph}${E}" && hit "$ph"
    done
    # "later" only in deferral shapes
    if printf '%s' "$l" | grep -qE "${B}later([.,;:)]|$)|(revisit|fix|handle|address|do (it|this|that)|save (it|this)|for|until|come back to it) later${E}"; then hit "later (deferral)"; fi
    if printf '%s' "$l" | grep -q "within noise" && ! printf '%s' "$l" | grep -qE 'cv[ :=]*[0-9]+([.][0-9]+)?'; then hit "within noise (no numeric cv)"; fi
    if printf '%s' "$l" | grep -qE '100 ?% parity'; then hit '"100% parity"'; fi
    if printf '%s' "$l" | grep -qE "${B}faster${E}" && ! printf '%s' "$l" | grep -qE '[0-9]'; then hit "faster (no number)"; fi
    if printf '%s' "$l" | grep -qEi '(unsafe [0-9]+|[0-9]+ unsafe)' && ! printf '%s' "$l" | grep -qE 'bend v?[0-9]+[.][0-9]+([.][0-9]+)?'; then hit "unsafe count without bend version"; fi
    if printf '%s' "$l" | grep -qE "${B}verified${E}" && ! printf '%s' "$l" | grep -qE 'law|proof|all terms check|golden|lanes|conform|probe|floor|case'; then hit "verified (no law/golden named)"; fi
  done <"$f"
done
[[ $checked -gt 0 ]] || { echo "error: no file checked" >&2; exit 2; }
echo "claims-lint: $hits hit(s) in $checked file(s)"
[[ $hits -eq 0 && $missing -eq 0 ]]
