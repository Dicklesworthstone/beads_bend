# core/query — the issue-listing relation of `list` and `count` (S4.100–S4.136, S4.144–S4.150).
# A Filter is built from the option occurrences (refusing what S4.105, S4.107,
# S4.108 and S4.118 refuse, in that order), every issue is judged against it,
# the survivors are ordered by one total comparator per S4.115–S4.117, and the
# page is cut. `--overdue` needs the clock and is not here yet.
# Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./cli.bend as Cli

# S4.100–S4.132 (data) what a listing keeps. An empty list means "no such filter"; the three
# `drop_*` flags are the visibility rule of S4.100; `pmin`/`pmax` default to the whole range
type Filter is Data:
  Filter{statuses: List<&2, String>, drop_closed: Bool, drop_tombstone: Bool, drop_deferred: Bool, types: List<&2, String>, priorities: List<&2, U32>, assignee: Maybe<&2, String>, unassigned: Bool, ids: List<&2, String>, labels_all: List<&2, String>, labels_any: List<&2, String>, pmin: U32, pmax: U32, title_has: Maybe<&2, String>, desc_has: Maybe<&2, String>, notes_has: Maybe<&2, String>, templates: Bool}

# S4.105 S4.107 S4.108 (data) a filter, or the refusal that stops the command before any query
type Built is Data:
  BuildBad{failure: Failure.Failure}
  BuildOk{filter: Filter}

# ---------------------------------------------------------------- words

# S4.105 (spec twin) ASCII lower case of one code point
def lower_char(+c: U32, up: Bool) -> U32:
  match up:
    case True{}:
      (c + 32 : U32)
    case False{}:
      c

# S4.105 S4.109 S4.112 (spec twin) a string with the 26 ASCII capitals folded to lower case and every other code point kept
def folded(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{lower_char(c, ((c >= 65 : U32) && (c <= 90 : U32)))}, folded(rest)}

# S4.107 (spec twin) ASCII upper case of one code point
def upper_char(+c: U32, low: Bool) -> U32:
  match low:
    case True{}:
      (c - 32 : U32)
    case False{}:
      c

# S4.107 (spec twin) a string with the 26 ASCII small letters folded to upper case
def shouted(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{upper_char(c, ((c >= 97 : U32) && (c <= 122 : U32)))}, shouted(rest)}

# S4.122 (spec twin) is this word in the list
def among(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{y, rest}:
      (String.eq(y, x) || among(rest, x))

# S4.107 (spec twin) is this number in the list
def among_u32(xs: List<&2, U32>, +x: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{y, rest}:
      (U32.is_eq(y, x) || among_u32(rest, x))

# S4.122 (spec twin) every word folded to lower case
def folded_all(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, rest}:
      folded(x) <> folded_all(rest)

# S4.146 (spec twin) keep a piece that is not empty after trimming
def piece_keep(piece: String, empty: Bool, rest: List<&2, String>) -> List<&2, String>:
  match empty:
    case True{}:
      rest
    case False{}:
      piece <> rest

# S4.107 S4.146 (spec twin) the trimmed, non-empty pieces of comma-separated words
def pieces_of(parts: List<&2, String>) -> List<&2, String>:
  match parts:
    case Nil{}:
      Nil{}
    case Con{+p, rest}:
      piece_keep(String.trim(p), String.is_empty(String.trim(p)), pieces_of(rest))

# S4.107 S4.146 (spec twin) every occurrence split on `,`, the pieces trimmed and the empty ones skipped
def comma_split(values: List<&2, String>) -> List<&2, String>:
  match values:
    case Nil{}:
      Nil{}
    case Con{v, rest}:
      List.append(&2, String, pieces_of(String.split(v, Chr{44})), comma_split(rest))

# ---------------------------------------------------------------- priorities (S4.107, S4.108)

# S9.15 (spec twin) every code point an ASCII digit, and at least one
def all_digits(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, +rest}:
      ((c >= 48 : U32) && (c <= 57 : U32) && (String.is_empty(rest) || all_digits(rest)))

# S9.15 (spec twin) the value as the refusal quotes it: a `P` in front of digits is dropped (`P9` → `9`)
def quoted_priority(+shown: String) -> String:
  Bool.pick(String, (String.starts_with(shown, "P") && all_digits(String.drop(shown, 1n))), String.drop(shown, 1n), shown)

# S9.15 (spec twin) the generic hint of a priority refusal
def priority_hint() -> String:
  "Priority must be 0-4 or P0-P4 (0=critical, 4=backlog); list filters also accept ranges and comma lists such as 0-1 or 0,2."

# S9.15 (spec twin) the number a priority WORD means, "" for any other word: CRITICAL and URGENT 0, HIGH 1, MEDIUM 2,
# LOW 3, BACKLOG 4 (the value is judged in upper case)
def word_rank(+shown: String) -> String:
  Bool.pick(String, (String.eq(shown, "CRITICAL") || String.eq(shown, "URGENT")), "0", Bool.pick(String, String.eq(shown, "HIGH"), "1", Bool.pick(String, String.eq(shown, "MEDIUM"), "2", Bool.pick(String, String.eq(shown, "LOW"), "3", Bool.pick(String, String.eq(shown, "BACKLOG"), "4", "")))))

# S9.15 (spec twin) the hint a priority word earns: `Did you mean --priority <n>?`, else the generic one
def word_hint(+rank: String) -> String:
  Bool.pick(String, String.is_empty(rank), priority_hint(), "Did you mean --priority " ++ rank ++ "?")


# S4.107 (spec twin) one priority's digit after the optional `P`: exactly one of `0`..`4`; 9 means "not a priority"
def priority_digit(cs: String) -> U32:
  match cs:
    case SCon{Chr{48}, SNil{}}:
      0
    case SCon{Chr{49}, SNil{}}:
      1
    case SCon{Chr{50}, SNil{}}:
      2
    case SCon{Chr{51}, SNil{}}:
      3
    case SCon{Chr{52}, SNil{}}:
      4
    case other:
      9

# S4.107 (spec twin) a priority word, already trimmed and in upper case: an optional leading `P`, then the digit
def priority_word(s: String) -> U32:
  match s:
    case SCon{Chr{80}, rest}:
      priority_digit(rest)
    case other:
      priority_digit(other)

# S4.107 (data) the priorities selected so far (REVERSED), or the first refusal
type Picked is Data:
  PickBad{failure: Failure.Failure}
  PickOk{values: List<&2, U32>}

# S4.107 (spec twin) add one priority unless it is already selected
def pick_add(+values: List<&2, U32>, +p: U32, known: Bool) -> List<&2, U32>:
  match known:
    case True{}:
      values
    case False{}:
      p <> values

# S4.107 (data) a token cut at its first `-`: the text before it, the text after it, and whether there was one
type Cut is Data:
  Cut{left: String, right: String, found: Bool}

# S4.107 (spec twin) cut a token at its first `-`; `acc` is the text before it, REVERSED
def cut_at_dash(s: String, acc: List<&2, U32>) -> Cut:
  match s:
    case SNil{}:
      Cut{Cli.text_rev(acc, ""), "", False{}}
    case SCon{Chr{45}, rest}:
      Cut{Cli.text_rev(acc, ""), rest, True{}}
    case SCon{Chr{c}, rest}:
      cut_at_dash(rest, c <> acc)

# S9.15 (spec twin) the top-level hint of a backwards range `<hi>-<lo>`: `Ranges run low to high: use <lo>-<hi>.`
def range_hint(c: Cut, +fallback: String) -> String:
  match c:
    case Cut{+left, +right, True{}}:
      Bool.pick(String, (all_digits(left) && all_digits(right) && (Maybe.default(&2, U32, U32.read(left), 0) > Maybe.default(&2, U32, U32.read(right), 0) : U32)), "Ranges run low to high: use " ++ right ++ "-" ++ left ++ ".", fallback)
    case Cut{left, right, False{}}:
      fallback

# S9.15 (spec twin) the refusal of a priority: the value is quoted as it was judged, in upper case, with a leading `P`
# of a number dropped; a priority word suggests its number (in the hint and the context's hint), and a backwards range
# says so in the top-level hint only (the context keeps the generic hint)
def bad_priority(+shown: String) -> Failure.Failure:
  Failure.Failure{"INVALID_PRIORITY", "Priority must be 0-4, got: " ++ quoted_priority(shown), Some{range_hint(cut_at_dash(shown, Nil{}), word_hint(word_rank(shown)))}, True{}, [Failure.CtxMember{"priority", Failure.CStr{quoted_priority(shown)}}, Failure.CtxMember{"hint", Failure.CStr{word_hint(word_rank(shown))}}], 4}

# S4.107 (spec twin) keep priority `p` when both ends are priorities and lo <= p <= hi
def span_keep(+p: U32, lo: U32, +hi: U32, +rest: List<&2, U32>) -> List<&2, U32>:
  Bool.pick(List<&2, U32>, ((lo <= p : U32) && (p <= hi : U32) && (hi <= 4 : U32)), p <> rest, rest)

# S4.107 (spec twin) the priorities from `lo` to `hi` inclusive, ascending; none when an end is not a priority (9) or lo > hi
def span(+lo: U32, +hi: U32) -> List<&2, U32>:
  span_keep(0, lo, hi, span_keep(1, lo, hi, span_keep(2, lo, hi, span_keep(3, lo, hi, span_keep(4, lo, hi, Nil{})))))

# S4.107 (spec twin) the priorities one token selects; none means the token is refused. A token with a `-` and text
# on both sides is a closed range; any other token is one priority
def picks_of(c: Cut) -> List<&2, U32>:
  match c:
    case Cut{+left, +right, True{}}:
      Bool.pick(List<&2, U32>, (String.is_empty(left) || String.is_empty(right)), Nil{}, span(priority_word(String.trim(left)), priority_word(String.trim(right))))
    case Cut{left, right, False{}}:
      span(priority_word(left), priority_word(left))

# S4.107 (spec twin) add every selected priority that is new
def pick_all(picks: List<&2, U32>, +values: List<&2, U32>) -> List<&2, U32>:
  match picks:
    case Nil{}:
      values
    case Con{+p, rest}:
      pick_all(rest, pick_add(values, p, among_u32(values, p)))

# S4.107 (spec twin) fold one token in: a refusal is sticky; a token that selects nothing is refused, quoted in upper case
def pick_one(sofar: Picked, token: String, picks: List<&2, U32>) -> Picked:
  match sofar picks:
    case PickBad{f} _:
      PickBad{f}
    case PickOk{values} Nil{}:
      PickBad{bad_priority(token)}
    case PickOk{values} Con{p, rest}:
      PickOk{pick_all(p <> rest, values)}

# S4.107 (spec twin) every token of every `--priority` occurrence; a token is trimmed and upper-cased before it is judged
def pick_go(tokens: List<&2, String>, sofar: Picked) -> Picked:
  match tokens:
    case Nil{}:
      sofar
    case Con{+t, rest}:
      pick_go(rest, pick_one(sofar, shouted(t), picks_of(cut_at_dash(shouted(t), Nil{}))))

# S4.108 (spec twin) a bound the argument parser already read as 0..=255; "" means "not given" and answers the fallback
def bound_of(digits: Maybe<&2, String>, fallback: U32) -> U32:
  match digits:
    case None{}:
      fallback
    case Some{text}:
      Maybe.default(&2, U32, U32.read(text), 255)

# ---------------------------------------------------------------- statuses (S4.101–S4.106)

# S4.105 (data) the built-in status names, as `--status` accepts them after lower-casing
def builtin_statuses() -> List<&2, String>:
  ["open", "in_progress", "inprogress", "blocked", "deferred", "draft", "closed", "tombstone", "pinned", "all"]

# S4.105 (spec twin) `inprogress` is a second spelling of `in_progress`
def status_name(+s: String) -> String:
  Bool.pick(String, String.eq(s, "inprogress"), "in_progress", s)

# S4.106 (spec twin) does a stored issue carry this status (both lower-cased)
def status_stored(issues: List<&2, Model.Issue>, +s: String) -> Bool:
  match issues:
    case Nil{}:
      False{}
    case Con{i, rest}:
      (String.eq(folded(Model.status_of(i)), s) || status_stored(rest, s))

# S4.105 (spec twin) the refusal of a status nobody knows; the value is quoted as the user typed it
def bad_status(+typed: String) -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: status: unknown status '" ++ typed ++ "'. Built-in statuses: open, in_progress, blocked, deferred, draft, closed, tombstone, pinned. Custom statuses must be declared in .beads/policy.yaml (workflow.statuses) or exist on at least one issue. Use --status all to include every status", None{}, True{}, [Failure.CtxMember{"field", Failure.CStr{"status"}}, Failure.CtxMember{"reason", Failure.CStr{"unknown status '" ++ typed ++ "'. Built-in statuses: open, in_progress, blocked, deferred, draft, closed, tombstone, pinned. Custom statuses must be declared in .beads/policy.yaml (workflow.statuses) or exist on at least one issue. Use --status all to include every status"}}], 4}

# S4.105 (spec twin) the first `--status` value that is neither built in nor carried by a stored issue; "" when every value is known
def unknown_status(values: List<&2, String>, +issues: List<&2, Model.Issue>) -> String:
  match values:
    case Nil{}:
      ""
    case Con{+v, rest}:
      Bool.pick(String, (among(builtin_statuses(), folded(String.trim(v))) || status_stored(issues, folded(String.trim(v)))), unknown_status(rest, issues), v)

# S4.122 (spec twin) the `--status` values as the filter compares them: trimmed, lower-cased, one spelling per status
def status_names(values: List<&2, String>) -> List<&2, String>:
  match values:
    case Nil{}:
      Nil{}
    case Con{v, rest}:
      status_name(folded(String.trim(v))) <> status_names(rest)

# ---------------------------------------------------------------- building the filter

# S4.118 (spec twin) the refusal of a sort key nobody knows; the value is quoted verbatim
def bad_sort(+typed: String) -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: sort: invalid sort field '" ++ typed ++ "'", None{}, True{}, [Failure.CtxMember{"field", Failure.CStr{"sort"}}, Failure.CtxMember{"reason", Failure.CStr{"invalid sort field '" ++ typed ++ "'"}}], 4}

# S4.116 (spec twin) a sort key as a number: 0 priority (also the default), 1 created, 2 updated, 3 title; 9 unknown
def sort_key(given: Maybe<&2, String>) -> U32:
  match given:
    case None{}:
      0
    case Some{+k}:
      Bool.pick(U32, String.eq(k, "priority"), 0, Bool.pick(U32, (String.eq(k, "created_at") || String.eq(k, "created")), 1, Bool.pick(U32, (String.eq(k, "updated_at") || String.eq(k, "updated")), 2, Bool.pick(U32, String.eq(k, "title"), 3, 9))))

# S4.100 S4.122 (spec twin) the filter once its statuses and priorities are known; `closed` and `deferred`
# are include_closed and include_deferred; `explicit` says a status was named. A tombstone is listed only when
# `tombstone` itself is named: `--status all` hides them as `--all` does (`scn_list_status_all`, OQ-039)
def filter_of(+opts: List<&2, Cli.Occ>, +statuses: List<&2, String>, priorities: List<&2, U32>, +closed: Bool, deferred: Bool, explicit: Bool, split_types: Bool) -> Filter:
  Filter{Bool.pick(List<&2, String>, among(statuses, "all"), Nil{}, statuses), Bool.not(closed), Bool.not((closed && explicit && among(statuses, "tombstone"))), (Bool.not(closed) && Bool.not(deferred)), folded_all(Bool.pick(List<&2, String>, split_types, comma_split(Cli.values(opts, "type")), Cli.values(opts, "type"))), priorities, Cli.value(opts, "assignee"), Cli.given(opts, "unassigned"), Cli.values(opts, "id"), Cli.values(opts, "label"), Cli.values(opts, "label-any"), bound_of(Cli.value(opts, "priority-min"), 0), bound_of(Cli.value(opts, "priority-max"), 4), Cli.value(opts, "title-contains"), Cli.value(opts, "desc-contains"), Cli.value(opts, "notes-contains"), Cli.given(opts, "include-templates")}

# S4.108 (spec twin) a bound outside 0..=4 is refused, the lower one first; the value is quoted in decimal
def bounds_pick(f: Filter, pmin: U32, pmax: U32, low_bad: Bool, high_bad: Bool) -> Built:
  match low_bad high_bad:
    case True{} _:
      BuildBad{bad_priority(U32.show(pmin))}
    case False{} True{}:
      BuildBad{bad_priority(U32.show(pmax))}
    case False{} False{}:
      BuildOk{f}

# S4.108 (spec twin) the bounds of a built filter are judged
def bounds_checked(f: Filter) -> Built:
  match f:
    case Filter{statuses, drop_closed, drop_tombstone, drop_deferred, types, priorities, assignee, unassigned, ids, labels_all, labels_any, +pmin, +pmax, title_has, desc_has, notes_has, templates}:
      bounds_pick(Filter{statuses, drop_closed, drop_tombstone, drop_deferred, types, priorities, assignee, unassigned, ids, labels_all, labels_any, pmin, pmax, title_has, desc_has, notes_has, templates}, pmin, pmax, (pmin > 4 : U32), (pmax > 4 : U32))

# S4.107 (spec twin) the priorities are judged after the statuses; the selected set is kept in ascending order
def with_priorities(picked: Picked, +opts: List<&2, Cli.Occ>, statuses: List<&2, String>, closed: Bool, deferred: Bool, explicit: Bool, split_types: Bool) -> Built:
  match picked:
    case PickBad{f}:
      BuildBad{f}
    case PickOk{values}:
      bounds_checked(filter_of(opts, statuses, List.sort(~U32, ~U32.is_le, values), closed, deferred, explicit, split_types))

# S4.101 S4.102 S4.144 (spec twin) the visibility a command derives from its options, once every status is known:
# `closed` is include_closed (`--all`, `--include-closed`, the word `all`, or a terminal status named);
# `deferred` is include_deferred (`--deferred`, `--all`, the word `all`, `deferred` named, or, for `list`
# alone, no status named at all)
def with_statuses(+opts: List<&2, Cli.Occ>, +names: List<&2, String>, lists_deferred: Bool, split: Bool) -> Built:
  with_priorities(pick_go(comma_split(Cli.values(opts, "priority")), PickOk{Nil{}}), opts, names, (Cli.given(opts, "all") || Cli.given(opts, "include-closed") || among(names, "all") || among(names, "closed") || among(names, "tombstone")), (Cli.given(opts, "deferred") || Cli.given(opts, "all") || among(names, "all") || among(names, "deferred") || (lists_deferred && List.is_empty(&2, String, names))), Bool.not(List.is_empty(&2, String, names)), split)

# S4.105 (spec twin) an unknown status stops everything else
def status_gate(unknown: String, +opts: List<&2, Cli.Occ>, values: List<&2, String>, lists_deferred: Bool, split: Bool) -> Built:
  match unknown:
    case SCon{h, t}:
      BuildBad{bad_status(SCon{h, t})}
    case SNil{}:
      with_statuses(opts, status_names(values), lists_deferred, split)

# S4.146 (spec twin) `count` splits its `--status` values on `,`; `list` does not (S1.33, S1.47)
def status_values(+opts: List<&2, Cli.Occ>, split: Bool) -> List<&2, String>:
  match split:
    case True{}:
      comma_split(Cli.values(opts, "status"))
    case False{}:
      Cli.values(opts, "status")

# S4.100–S4.108 (spec twin) the filter of `list` (`lists_deferred` true, no comma splitting of statuses and
# types) or of `count` (false, split), or the first refusal: statuses, then priorities, then the bounds
def build(+opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, lists_deferred: Bool, +split: Bool) -> Built:
  status_gate(unknown_status(status_values(opts, split), issues), opts, status_values(opts, split), lists_deferred, split)

# ---------------------------------------------------------------- judging one issue

# S4.122 S4.123 (spec twin) an empty list of wanted words keeps everything
def word_ok(wanted: List<&2, String>, have: String) -> Bool:
  match wanted:
    case Nil{}:
      True{}
    case Con{w, rest}:
      among(w <> rest, have)

# S4.107 (spec twin) an empty list of wanted priorities keeps everything
def priority_ok(wanted: List<&2, U32>, have: U32) -> Bool:
  match wanted:
    case Nil{}:
      True{}
    case Con{w, rest}:
      among_u32(w <> rest, have)

# S4.100 (spec twin) the visibility rule on the stored, lower-cased status
def visible(+status: String, drop_closed: Bool, drop_tombstone: Bool, drop_deferred: Bool) -> Bool:
  Bool.not(((drop_closed && String.eq(status, "closed")) || (drop_tombstone && String.eq(status, "tombstone")) || (drop_deferred && String.eq(status, "deferred"))))

# S4.124 (spec twin) `--assignee` is byte equality with a present assignee
def assignee_ok(wanted: Maybe<&2, String>, have: Maybe<&2, String>) -> Bool:
  match wanted have:
    case None{} _:
      True{}
    case Some{w} None{}:
      False{}
    case Some{w} Some{h}:
      String.eq(w, h)

# S4.124 (spec twin) `--unassigned` keeps an absent or empty assignee
def unassigned_ok(wanted: Bool, have: Maybe<&2, String>) -> Bool:
  match wanted have:
    case False{} _:
      True{}
    case True{} None{}:
      True{}
    case True{} Some{h}:
      String.is_empty(h)

# S4.126 (spec twin) every wanted label is carried
def labels_all_ok(wanted: List<&2, String>, +have: List<&2, String>) -> Bool:
  match wanted:
    case Nil{}:
      True{}
    case Con{w, rest}:
      (among(have, w) && labels_all_ok(rest, have))

# S4.127 (spec twin) at least one wanted label is carried; no wanted label keeps everything
def labels_any_go(wanted: List<&2, String>, +have: List<&2, String>) -> Bool:
  match wanted:
    case Nil{}:
      False{}
    case Con{w, rest}:
      (among(have, w) || labels_any_go(rest, have))

# S4.127 (spec twin) `--label-any`
def labels_any_ok(wanted: List<&2, String>, have: List<&2, String>) -> Bool:
  match wanted:
    case Nil{}:
      True{}
    case Con{w, rest}:
      labels_any_go(w <> rest, have)

# S4.109 S4.129 (spec twin) a needle, when given, occurs in the haystack, both with ASCII capitals folded;
# an absent haystack is the empty string
def has_text(needle: Maybe<&2, String>, hay: Maybe<&2, String>) -> Bool:
  match needle hay:
    case None{} _:
      True{}
    case Some{n} None{}:
      String.is_empty(n)
    case Some{n} Some{h}:
      String.contains(folded(h), folded(n))

# S4.107 S4.130 (spec twin) a stored priority as a number; anything that is not a small number compares as 255
def priority_number(digits: String) -> U32:
  Maybe.default(&2, U32, U32.read(digits), 255)

# S4.103 S4.114 S4.133 (spec twin) does the listing keep this issue: every filter at once
def keeps(f: Filter, +i: Model.Issue) -> Bool:
  match f:
    case Filter{statuses, drop_closed, drop_tombstone, drop_deferred, types, priorities, assignee, unassigned, ids, labels_all, labels_any, pmin, pmax, title_has, desc_has, notes_has, templates}:
      (visible(folded(Model.status_of(i)), drop_closed, drop_tombstone, drop_deferred) && (templates || Bool.not(Model.is_template(i))) && word_ok(statuses, folded(Model.status_of(i))) && word_ok(types, folded(Model.type_of(i))) && priority_ok(priorities, priority_number(Model.priority_of(i))) && assignee_ok(assignee, Model.assignee_of(i)) && unassigned_ok(unassigned, Model.assignee_of(i)) && word_ok(ids, Model.id_of(i)) && labels_all_ok(labels_all, Model.labels_of(i)) && labels_any_ok(labels_any, Model.labels_of(i)) && (priority_number(Model.priority_of(i)) >= pmin : U32) && (priority_number(Model.priority_of(i)) <= pmax : U32) && has_text(title_has, Some{Model.title_of(i)}) && has_text(desc_has, Model.description_of(i)) && has_text(notes_has, Model.notes_of(i)))

# S4.114 (spec twin) keep an issue the filter keeps
def kept_put(i: Model.Issue, keep: Bool, rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match keep:
    case True{}:
      i <> rest
    case False{}:
      rest

# S4.114 (spec twin) the issues the filter keeps, in store order
def kept(issues: List<&2, Model.Issue>, +f: Filter) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      kept_put(i, keeps(f, i), kept(rest, f))

# ---------------------------------------------------------------- order (S4.110–S4.117)

# S4.110–S4.112 (data) an issue with its sort keys read once: priority, the instant the order uses
# (created_at or updated_at), the title folded for S4.112, the id
type Row is Data:
  Row{p: U32, at: Time.Instant, title: String, id: String, issue: Model.Issue}

# S4.116 (spec twin) the instant a sort key orders by: `updated_at` for key 2, `created_at` otherwise
def row_instant(+i: Model.Issue, by_updated: Bool) -> Time.Instant:
  match by_updated:
    case True{}:
      Model.updated_of(i)
    case False{}:
      Model.created_of(i)

# S4.110–S4.112 (spec twin) the rows of the kept issues
def rows_of(issues: List<&2, Model.Issue>, +key: U32) -> List<&2, Row>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      Row{priority_number(Model.priority_of(i)), row_instant(i, U32.is_eq(key, 2)), folded(Model.title_of(i)), Model.id_of(i), i} <> rows_of(rest, key)

# S4.114 (spec twin) the issues of the rows, in row order
def issues_of(rows: List<&2, Row>) -> List<&2, Model.Issue>:
  match rows:
    case Nil{}:
      Nil{}
    case Con{Row{p, at, title, id, issue}, rest}:
      issue <> issues_of(rest)

# S4.111 (spec twin) a three-key less-or-equal: strictly first by the first key, then by the second, then the id
def le3(lt1: Bool, eq1: Bool, lt2: Bool, eq2: Bool, le_id: Bool) -> Bool:
  (lt1 || (eq1 && (lt2 || (eq2 && le_id))))

# S4.115 (spec twin) `priority ASC, created_at DESC, id ASC`: the default order and `--sort priority`
def le_priority(x: Row, y: Row) -> Bool:
  match x y:
    case Row{+xp, +xa, xt, xi, xo} Row{+yp, +ya, yt, yi, yo}:
      le3((xp < yp : U32), U32.is_eq(xp, yp), Bool.not(Time.le(xa, ya)), Time.eq(xa, ya), String.is_le(xi, yi))

# S4.117 (spec twin) `priority DESC, created_at ASC, id ASC`: the same two orders under `--reverse`
def le_priority_rev(x: Row, y: Row) -> Bool:
  match x y:
    case Row{+xp, +xa, xt, xi, xo} Row{+yp, +ya, yt, yi, yo}:
      le3((xp > yp : U32), U32.is_eq(xp, yp), Bool.not(Time.le(ya, xa)), Time.eq(xa, ya), String.is_le(xi, yi))

# S4.116 (spec twin) `<instant> DESC, id ASC`: `--sort created_at` and `--sort updated_at`
def le_newest(x: Row, y: Row) -> Bool:
  match x y:
    case Row{xp, +xa, xt, xi, xo} Row{yp, +ya, yt, yi, yo}:
      (Bool.not(Time.le(xa, ya)) || (Time.eq(xa, ya) && String.is_le(xi, yi)))

# S4.117 (spec twin) `<instant> ASC, id ASC`: the same two under `--reverse`
def le_oldest(x: Row, y: Row) -> Bool:
  match x y:
    case Row{xp, +xa, xt, xi, xo} Row{yp, +ya, yt, yi, yo}:
      (Bool.not(Time.le(ya, xa)) || (Time.eq(xa, ya) && String.is_le(xi, yi)))

# S4.112 S4.116 (spec twin) `title ASC` under the ASCII-only case-insensitive collation, then id ASC
def le_title(x: Row, y: Row) -> Bool:
  match x y:
    case Row{xp, xa, +xt, xi, xo} Row{yp, ya, +yt, yi, yo}:
      (String.is_lt(xt, yt) || (String.eq(xt, yt) && String.is_le(xi, yi)))

# S4.117 (spec twin) `title DESC`, then id ASC
def le_title_rev(x: Row, y: Row) -> Bool:
  match x y:
    case Row{xp, xa, +xt, xi, xo} Row{yp, ya, +yt, yi, yo}:
      (String.is_gt(xt, yt) || (String.eq(xt, yt) && String.is_le(xi, yi)))

# S4.115–S4.117 (spec twin) the rows under the chosen order: `order` is the sort key (0 priority, 1 created,
# 2 updated, 3 title) plus 10 under `--reverse`
def ordered_rows(+rows: List<&2, Row>, order: U32) -> List<&2, Row>:
  match order:
    case 0:
      List.sort(~Row, ~le_priority, rows)
    case 10:
      List.sort(~Row, ~le_priority_rev, rows)
    case 1:
      List.sort(~Row, ~le_newest, rows)
    case 2:
      List.sort(~Row, ~le_newest, rows)
    case 11:
      List.sort(~Row, ~le_oldest, rows)
    case 12:
      List.sort(~Row, ~le_oldest, rows)
    case 3:
      List.sort(~Row, ~le_title, rows)
    case _:
      List.sort(~Row, ~le_title_rev, rows)

# S4.115–S4.117 (spec twin) the kept issues under the chosen order
def ordered(issues: List<&2, Model.Issue>, +key: U32, reverse: Bool) -> List<&2, Model.Issue>:
  issues_of(ordered_rows(rows_of(issues, key), (key + Bool.pick(U32, reverse, 10, 0) : U32)))

# ---------------------------------------------------------------- the page (S4.119, S4.120)

# S4.119 (spec twin) a count the argument parser accepted as an unsigned integer; one too large to read answers a
# number beyond any store (2^32 - 1)
def count_of(given: Maybe<&2, String>) -> Nat:
  match given:
    case None{}:
      0n
    case Some{SCon{Chr{43}, digits}}:
      Maybe.default(&2, Nat, Nat.read(digits), 4294967295n)
    case Some{text}:
      Maybe.default(&2, Nat, Nat.read(text), 4294967295n)

# S4.119 (spec twin) `--limit 0` keeps everything
def limited(+rows: List<&2, Model.Issue>, +limit: Nat, unlimited: Bool) -> List<&2, Model.Issue>:
  match unlimited:
    case True{}:
      rows
    case False{}:
      List.take(&2, Model.Issue, rows, limit)

# S4.119 (spec twin) skip `offset` rows, then keep at most `limit` rows
def page(rows: List<&2, Model.Issue>, offset: Nat, +limit: Nat) -> List<&2, Model.Issue>:
  limited(List.drop(&2, Model.Issue, rows, offset), limit, Nat.is_eq(limit, 0n))

# S4.120 (spec twin) rows remain beyond the page: never when the limit is 0
def has_more(+total: Nat, offset: Nat, +limit: Nat) -> Bool:
  (Bool.not(Nat.is_eq(limit, 0n)) && Nat.is_gt(total, Nat.add(offset, limit)))

# S5.33 (spec twin) how many edges of the whole store point at this id
def dependents_go(deps: List<&2, Model.Dependency>, +id: String, acc: U32) -> U32:
  match deps:
    case Nil{}:
      acc
    case Con{d, rest}:
      dependents_go(rest, id, (acc + Bool.to_u32(String.eq(Model.target_of(d), id)) : U32))

# S5.33 (spec twin) `dependent_count`: over every issue's own edges
def dependents(issues: List<&2, Model.Issue>, +id: String, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{i, rest}:
      dependents(rest, id, dependents_go(Model.deps_of(i), id, acc))

# ---------------------------------------------------------------- count (S4.144–S4.150)

# S4.148 (data) one group of a grouped count
type Group is Data:
  Group{key: String, count: U32}

# S4.148 S4.149 (spec twin) route one step of the ordered insertion: the same key counts up; a smaller key opens
# its group here; a larger key goes further
def tally_pick(k: String, n: U32, rest: List<&2, Group>, key: String, same: Bool, before: Bool, later: List<&2, Group>) -> List<&2, Group>:
  match same before:
    case True{} _:
      Group{k, (n + 1 : U32)} <> rest
    case False{} True{}:
      Group{key, 1} <> Group{k, n} <> rest
    case False{} False{}:
      Group{k, n} <> later

# S4.148 (spec twin) add 1 to the group with this key, or open it; the groups are kept in ascending byte order of
# the key (S4.149), so the insertion is the sort
def tally(groups: List<&2, Group>, +key: String) -> List<&2, Group>:
  match groups:
    case Nil{}:
      Group{key, 1} <> Nil{}
    case Con{Group{+k, +n}, +rest}:
      tally_pick(k, n, rest, key, String.eq(k, key), String.is_lt(key, k), tally(rest, key))

# S4.148 (spec twin) the key of an absent value
def key_or(value: Maybe<&2, String>, missing: String) -> String:
  match value:
    case None{}:
      missing
    case Some{v}:
      v

# S4.148 (spec twin) an issue without labels is counted under `(no labels)`
def label_keys(labels: List<&2, String>) -> List<&2, String>:
  match labels:
    case Nil{}:
      "(no labels)" <> Nil{}
    case Con{l, rest}:
      l <> rest

# S4.148 (spec twin) the group keys one issue contributes to: `by` is 0 status, 1 priority, 2 type, 3 assignee, 4 label
def group_keys(i: Model.Issue, by: U32) -> List<&2, String>:
  match by:
    case 0:
      Model.status_of(i) <> Nil{}
    case 1:
      ("P" ++ Model.priority_of(i)) <> Nil{}
    case 2:
      Model.type_of(i) <> Nil{}
    case 3:
      key_or(Model.assignee_of(i), "(unassigned)") <> Nil{}
    case _:
      label_keys(Model.labels_of(i))

# S4.148 (spec twin) count one issue under each of its keys
def tally_keys(keys: List<&2, String>, groups: List<&2, Group>) -> List<&2, Group>:
  match keys:
    case Nil{}:
      groups
    case Con{k, rest}:
      tally_keys(rest, tally(groups, k))

# S4.148–S4.150 (spec twin) the groups of the kept issues, ascending by key; a group is never empty
def grouped(issues: List<&2, Model.Issue>, +by: U32, groups: List<&2, Group>) -> List<&2, Group>:
  match issues:
    case Nil{}:
      groups
    case Con{i, rest}:
      grouped(rest, by, tally_keys(group_keys(i, by), groups))

# ---------------------------------------------------------------- search (S4.137–S4.143)

# S4.143 (spec twin) the refusal of a query that is empty after trimming
def empty_query() -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: query: search query cannot be empty", None{}, True{}, [Failure.CtxMember{"field", Failure.CStr{"query"}}, Failure.CtxMember{"reason", Failure.CStr{"search query cannot be empty"}}], 4}

# S4.137 (spec twin) does any comment's text hold the needle (both with ASCII capitals folded)
def comments_hold(comments: List<&2, Model.Comment>, +needle: String) -> Bool:
  match comments:
    case Nil{}:
      False{}
    case Con{Model.Comment{id, issue_id, author, text, created_at}, rest}:
      (String.contains(folded(text), needle) || comments_hold(rest, needle))

# S4.137 (spec twin) an absent description never matches
def text_holds(hay: Maybe<&2, String>, needle: String) -> Bool:
  match hay:
    case None{}:
      False{}
    case Some{h}:
      String.contains(folded(h), needle)

# S4.137 S4.138 (spec twin) a record matches when the needle is a SUBSTRING of its title, its description, its id or
# the text of one of its comments; `needle` is already trimmed and folded
def matches(+i: Model.Issue, +needle: String) -> Bool:
  (String.contains(folded(Model.title_of(i)), needle) || text_holds(Model.description_of(i), needle) || String.contains(folded(Model.id_of(i)), needle) || comments_hold(Model.comments_of(i), needle))

# S4.140 (spec twin) keep a record that matches
def matching_put(i: Model.Issue, keep: Bool, rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match keep:
    case True{}:
      i <> rest
    case False{}:
      rest

# S4.140 (spec twin) the records that match the needle, in the given order
def matching(issues: List<&2, Model.Issue>, +needle: String) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      matching_put(i, matches(i, needle), matching(rest, needle))

# S4.142 (spec twin) does the filter hide closed records
def hides_closed(f: Filter) -> Bool:
  match f:
    case Filter{statuses, drop_closed, drop_tombstone, drop_deferred, types, priorities, assignee, unassigned, ids, labels_all, labels_any, pmin, pmax, title_has, desc_has, notes_has, templates}:
      drop_closed

# S4.142 (spec twin) the same filter asking for exactly the closed records it hid
def closed_only(f: Filter) -> Filter:
  match f:
    case Filter{statuses, drop_closed, drop_tombstone, drop_deferred, types, priorities, assignee, unassigned, ids, labels_all, labels_any, pmin, pmax, title_has, desc_has, notes_has, templates}:
      Filter{"closed" <> Nil{}, False{}, drop_tombstone, drop_deferred, types, priorities, assignee, unassigned, ids, labels_all, labels_any, pmin, pmax, title_has, desc_has, notes_has, templates}

# S4.142 (spec twin) `hidden_closed_count`: the closed matches the default exclusion hid, under the same other filters; 0 when nothing is hidden
def hidden_closed(+issues: List<&2, Model.Issue>, +f: Filter, needle: String) -> Nat:
  Bool.pick(Nat, hides_closed(f), List.length(&2, Model.Issue, matching(kept(issues, closed_only(f)), needle)), 0n)

# S4.141 (spec twin) `search` keeps 50 rows unless told otherwise
def search_limit(given: Maybe<&2, String>) -> Nat:
  match given:
    case None{}:
      50n
    case Some{text}:
      count_of(Some{text})
