# core/resolve — from what the user typed to one stored id (S4.28, S4.40–S4.47).
# Four steps in order: the exact id; the default prefix put in front of a word
# without `-`; a substring of the hash part; not found. Several substring
# candidates are a refusal that lists them in ascending byte order (DISC-005).
# The lower-casing is ASCII here; the original's is full Unicode (S4.36, OQ-118).
# Nothing here consults the original.
import Base
import ./failure.bend as Failure

# S4.45–S4.47 (data) the stored id an input names, or the refusal
type Found is Data:
  FoundBad{failure: Failure.Failure}
  FoundOk{id: String}

# S4.28 (data) a text cut at a separator: what is before it, what is after it, and whether it was there
type Cut is Data:
  Cut{left: String, right: String, found: Bool}

# S4.36 (spec twin) ASCII lower case of one code point
def lower_char(+c: U32, up: Bool) -> U32:
  match up:
    case True{}:
      (c + 32 : U32)
    case False{}:
      c

# S4.36 (spec twin) the input lower-cased for lookup
def lowered(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{lower_char(c, ((c >= 65 : U32) && (c <= 90 : U32)))}, lowered(rest)}

# S4.28 (spec twin) a REVERSED code-point list as a String, in order
def text_rev(rev: List<&2, U32>, acc: String) -> String:
  match rev:
    case Nil{}:
      acc
    case Con{c, rest}:
      text_rev(rest, SCon{Chr{c}, acc})

# S4.30 (spec twin) cut at the FIRST occurrence of a separator; `acc` is the text before it, REVERSED
def cut_first(s: String, +sep: U32, +acc: List<&2, U32>) -> Cut:
  match s:
    case SNil{}:
      Cut{text_rev(acc, ""), "", False{}}
    case SCon{Chr{+c}, +rest}:
      Bool.pick(Cut, U32.is_eq(c, sep), Cut{text_rev(acc, ""), rest, True{}}, cut_first(rest, sep, c <> acc))

# S4.28 (spec twin) the halves of a cut of the REVERSED text, turned back
def cut_back(c: Cut) -> Cut:
  match c:
    case Cut{left, right, found}:
      Cut{String.reverse(right), String.reverse(left), found}

# S4.28 (spec twin) cut at the LAST occurrence of a separator: a prefix may itself contain `-`
def cut_last(s: String, sep: U32) -> Cut:
  cut_back(cut_first(String.reverse(s), sep, Nil{}))

# S4.41 (spec twin) is this id stored
def stored(ids: List<&2, String>, +id: String) -> Bool:
  match ids:
    case Nil{}:
      False{}
    case Con{x, rest}:
      (String.eq(x, id) || stored(rest, id))

# S4.43 (spec twin) what follows the last `-` of an id; the whole id when it has none
def remainder_of(c: Cut) -> String:
  match c:
    case Cut{left, right, True{}}:
      right
    case Cut{left, right, False{}}:
      left

# S4.28 S4.43 (spec twin) does an input split into a prefix and a remainder: it has a `-` with text on both sides
def splits(c: Cut) -> Bool:
  match c:
    case Cut{left, right, found}:
      (found && Bool.not(String.is_empty(left)) && Bool.not(String.is_empty(right)))

# S4.43 (spec twin) the prefix a split input requires; "" when it does not split
def wanted_prefix(c: Cut, split: Bool) -> String:
  match c split:
    case Cut{left, right, found} True{}:
      left
    case Cut{left, right, found} False{}:
      ""

# S4.43 (spec twin) the search pattern of an input: its remainder when it splits, the whole input otherwise
def pattern_of(c: Cut, whole: String, split: Bool) -> String:
  match c split:
    case Cut{left, right, found} True{}:
      right
    case Cut{left, right, found} False{}:
      whole

# S4.43 (spec twin) one stored id against the pattern: its base hash (the remainder up to the first `.`) contains the
# pattern's base; a pattern with a `.` also needs the same child path exactly; a required prefix must lead the id
def hash_matches(hash: Cut, pattern: Cut, +id: String, +prefix: String) -> Bool:
  match hash pattern:
    case Cut{base, child, has_child} Cut{want, want_child, wants_child}:
      (String.contains(base, want) && (Bool.not(wants_child) || (has_child && String.eq(child, want_child))) && (String.is_empty(prefix) || String.starts_with(id, prefix ++ "-")))

# S4.43 (spec twin) keep a qualifying id
def candidate_put(id: String, keep: Bool, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      id <> rest
    case False{}:
      rest

# S4.43 (spec twin) every stored id that qualifies, in store order
def candidates(ids: List<&2, String>, +pattern: Cut, +prefix: String) -> List<&2, String>:
  match ids:
    case Nil{}:
      Nil{}
    case Con{+id, rest}:
      candidate_put(id, hash_matches(cut_first(remainder_of(cut_last(id, 45)), 46, Nil{}), pattern, id, prefix), candidates(rest, pattern, prefix))

# S9.9 (spec twin) no stored id answers the input: the trimmed input is quoted as it was typed
def not_found(+typed: String) -> Failure.Failure:
  Failure.Failure{"ISSUE_NOT_FOUND", "Issue not found: " ++ typed, Some{"Run 'br list' to see available issues."}, False{}, [Failure.CtxMember{"searched_id", Failure.CStr{typed}}], 3}

# S9.11 (spec twin) an input that is empty after trimming; the message ends with its space
def invalid_id() -> Failure.Failure:
  Failure.Failure{"INVALID_ID", "Invalid issue ID format: ", None{}, False{}, [Failure.CtxMember{"id", Failure.CStr{""}}], 3}

# S4.46 (spec twin) the ids as Rust's debug formatting prints a list of strings: `["a", "b"]`
def debug_list(ids: List<&2, String>, first: Bool) -> List<&2, String>:
  match ids first:
    case Nil{} _:
      Nil{}
    case Con{id, rest} True{}:
      Failure.quoted(id) <> debug_list(rest, False{})
    case Con{id, rest} False{}:
      ", " <> Failure.quoted(id) <> debug_list(rest, False{})

# S4.44 S4.46 S9.10 (spec twin) several candidates: the input in single quotes, the candidates in ascending byte order
def ambiguous(+typed: String, +matches: List<&2, String>) -> Failure.Failure:
  Failure.Failure{"AMBIGUOUS_ID", "Ambiguous ID '" ++ typed ++ "': matches [" ++ String.concat(debug_list(matches, True{})) ++ "]", Some{"Provide more characters of the ID"}, True{}, [Failure.CtxMember{"partial_id", Failure.CStr{typed}}, Failure.CtxMember{"matches", Failure.CList{matches}}], 3}

# S4.45–S4.47 (spec twin) step 3's verdict: one candidate is the id; none is "not found"; several are ambiguous
def by_candidates(found: List<&2, String>, typed: String) -> Found:
  match found:
    case Nil{}:
      FoundBad{not_found(typed)}
    case Con{id, Nil{}}:
      FoundOk{id}
    case Con{id, more}:
      FoundBad{ambiguous(typed, List.sort(~String, ~String.is_le, id <> more))}

# S4.43 (spec twin) step 3: an empty pattern skips the search
def by_substring(+ids: List<&2, String>, +whole: String, +typed: String, +cut: Cut) -> Found:
  by_candidates(Bool.pick(List<&2, String>, String.is_empty(pattern_of(cut, whole, splits(cut))), Nil{}, candidates(ids, cut_first(pattern_of(cut, whole, splits(cut)), 46, Nil{}), wanted_prefix(cut, splits(cut)))), typed)

# S4.41 S4.42 (spec twin) steps 1 and 2: the exact id wins; then, for a word without `-`, the default prefix put in front
def by_exact(+ids: List<&2, String>, +lower: String, +typed: String, +prefix: String, exact: Bool, prefixed: Bool) -> Found:
  match exact prefixed:
    case True{} _:
      FoundOk{lower}
    case False{} True{}:
      FoundOk{prefix ++ "-" ++ lower}
    case False{} False{}:
      by_substring(ids, lower, typed, cut_last(lower, 45))

# S4.40 (spec twin) an input that is empty after trimming is refused before any lookup
def resolve_trimmed(+ids: List<&2, String>, +typed: String, +prefix: String, empty: Bool) -> Found:
  match empty:
    case True{}:
      FoundBad{invalid_id()}
    case False{}:
      by_exact(ids, lowered(typed), typed, prefix, stored(ids, lowered(typed)), (Bool.not(String.contains(lowered(typed), "-")) && stored(ids, prefix ++ "-" ++ lowered(typed))))

# S4.40–S4.47 (spec twin) the stored id an input names, among `ids` (every stored id), with the workspace's default prefix
def resolve(ids: List<&2, String>, +input: String, prefix: String) -> Found:
  resolve_trimmed(ids, String.trim(input), prefix, String.is_empty(String.trim(input)))

# S4.45–S4.47 S9.2 (spec twin) what a resolution prints on stderr in plain mode: the refusal, or, for a hit, the id and a newline
def report(f: Found) -> String:
  match f:
    case FoundBad{failure}:
      Failure.plain_text(failure)
    case FoundOk{id}:
      id ++ "\n"
