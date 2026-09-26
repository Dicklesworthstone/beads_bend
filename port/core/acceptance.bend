# core/acceptance — the checklist inside `acceptance_criteria` that `update
# --add-acceptance`, `--check-acceptance` and `--uncheck-acceptance` edit in
# place, and that `show --json` lists (S4.398). An item is a line `- [ ] text`
# or `* [x] text` after optional indentation; every other line, and every byte
# of an item but its mark, is kept. Selectors are judged against the items
# before this run's additions, and all of them before anything is written.
# Nothing here consults the original.
import Base
import ./failure.bend as Failure
import ./create.bend as Create
import ./model.bend as Model

# S4.398 (data) one line of the criteria: an item (the bytes before its mark, the mark, the bytes after it, its
# text) or any other line
type Line is Data:
  Item{lead: String, mark: U32, after: String, text: String}
  Other{text: String}

# S4.398 (data) one item as the listings show it
type Entry is Data:
  Entry{index: U32, text: String, checked: Bool}

# ---------------------------------------------------------------- reading the criteria

# S4.398 (spec twin) the indentation of a line: its leading spaces and tabs
def leading(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      Bool.pick(String, (U32.is_eq(c, 32) || U32.is_eq(c, 9)), SCon{Chr{c}, leading(rest)}, "")

# S4.398 (spec twin) the first code point of a text, 0 for the empty text
def code_at(s: String) -> U32:
  match s:
    case SNil{}:
      0
    case SCon{Chr{c}, rest}:
      c

# S4.398 (spec twin) is a mark one of ` `, `x`, `X`
def mark_ok(+c: U32) -> Bool:
  (U32.is_eq(c, 32) || U32.is_eq(c, 120) || U32.is_eq(c, 88))

# S4.398 (spec twin) does the text after the indentation open an item: `- [` or `* [`, a mark, `] `
def opens_item(+rest: String) -> Bool:
  ((String.starts_with(rest, "- [") || String.starts_with(rest, "* [")) && mark_ok(code_at(String.drop(rest, 3n))) && String.starts_with(String.drop(rest, 4n), "] "))

# S4.398 (spec twin) one line classified, from its indentation and the rest
def line_at(+ws: String, +rest: String, +line: String) -> Line:
  Bool.pick(Line, opens_item(rest), Item{ws ++ String.take(rest, 3n), code_at(String.drop(rest, 3n)), String.drop(rest, 4n), String.trim(String.drop(rest, 6n))}, Other{line})

# S4.398 (spec twin) one line of the criteria
def line_of(+line: String) -> Line:
  line_at(leading(line), String.drop(line, String.length(leading(line))), line)

# S4.398 (spec twin) every line of the criteria
def lines_of(ls: List<&2, String>) -> List<&2, Line>:
  match ls:
    case Nil{}:
      Nil{}
    case Con{+l, rest}:
      line_of(l) <> lines_of(rest)

# S4.398 (spec twin) is a line an item
def is_item(l: Line) -> Bool:
  match l:
    case Item{lead, mark, after, text}:
      True{}
    case Other{t}:
      False{}

# S4.398 (spec twin) keep an item as an entry numbered `next`
def entry_put(l: Line, next: U32, rest: List<&2, Entry>) -> List<&2, Entry>:
  match l:
    case Item{lead, mark, after, text}:
      Entry{next, text, Bool.not(U32.is_eq(mark, 32))} <> rest
    case Other{t}:
      rest

# S4.398 (spec twin) the items of some lines, numbered from `next` in line order
def entries_go(lines: List<&2, Line>, +next: U32) -> List<&2, Entry>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{+l, rest}:
      entry_put(l, next, entries_go(rest, (next + Bool.to_u32(is_item(l)) : U32)))

# S4.398 (spec twin) the items of a criteria text
def entries(+text: String) -> List<&2, Entry>:
  entries_go(lines_of(String.split(text, Chr{10})), 1)

# ---------------------------------------------------------------- the listings

# S4.398 (spec twin) one item as the listings print it: `  [x] <n>  <text>`
def item_line(e: Entry) -> String:
  match e:
    case Entry{index, text, checked}:
      String.concat(["  [", Bool.pick(String, checked, "x", " "), "] ", U32.show(index), "  ", text])

# S4.398 (spec twin) the item lines of some entries
def item_lines(es: List<&2, Entry>) -> List<&2, String>:
  match es:
    case Nil{}:
      Nil{}
    case Con{e, rest}:
      item_line(e) <> item_lines(rest)

# S4.398 (spec twin) one item as JSON: `{"index","text","checked"}`
def entry_json(e: Entry) -> String:
  match e:
    case Entry{index, text, checked}:
      String.concat(["{\"index\":", U32.show(index), ",\"text\":", Failure.quoted(text), ",\"checked\":", Bool.pick(String, checked, "true", "false"), "}"])

# S4.398 (spec twin) the item lines of some entries, each ended by a newline
def item_block(es: List<&2, Entry>) -> String:
  match es:
    case Nil{}:
      ""
    case Con{e, rest}:
      item_line(e) ++ "\n" ++ item_block(rest)

# S4.398 (spec twin) the JSON objects of some entries
def entry_objects(es: List<&2, Entry>) -> List<&2, String>:
  match es:
    case Nil{}:
      Nil{}
    case Con{e, rest}:
      entry_json(e) <> entry_objects(rest)

# S4.398 (spec twin) how many entries are checked
def checked_count(es: List<&2, Entry>, acc: U32) -> U32:
  match es:
    case Nil{}:
      acc
    case Con{Entry{index, text, checked}, rest}:
      checked_count(rest, (acc + Bool.to_u32(checked) : U32))

# S4.398 (spec twin, entry) the `acceptance_items` member of `show --json`: present only when the criteria hold an item
def items_member(text: Maybe<&2, String>) -> String:
  match text:
    case None{}:
      ""
    case Some{+t}:
      Bool.pick(String, List.is_empty(&2, Entry, entries(t)), "", ",\"acceptance_items\":[" ++ String.join(entry_objects(entries(t)), ",") ++ "]")

# ---------------------------------------------------------------- selectors

# S4.398 (data) what one selector picked: the item numbers, or the reason it was refused
type Pick is Data:
  PickOk{indices: List<&2, U32>}
  PickBad{reason: String}

# S4.398 (spec twin) is a text made of ASCII digits only
def digits_only(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      ((c >= 48 : U32) && (c <= 57 : U32) && digits_only(rest))

# S4.398 (spec twin) is every comma piece of a selector a number: then the selector is a number list
def all_numbers(ps: List<&2, String>) -> Bool:
  match ps:
    case Nil{}:
      True{}
    case Con{+p, rest}:
      (Bool.not(String.is_empty(p)) && digits_only(p) && all_numbers(rest))

# S4.398 (spec twin) one more item number in front of a pick
def pick_cons(+n: U32, p: Pick) -> Pick:
  match p:
    case PickOk{xs}:
      PickOk{n <> xs}
    case PickBad{r}:
      PickBad{r}

# S4.398 (spec twin) one item number judged: 0 and a number past the last item are refused, the first refusal wins
def number_one(+n: U32, +count: U32, rest: Pick) -> Pick:
  Bool.pick(Pick, U32.is_eq(n, 0), PickBad{"acceptance item numbers are 1-based; 0 is not an item"}, Bool.pick(Pick, (n > count : U32), PickBad{"acceptance item " ++ U32.show(n) ++ " does not exist (" ++ U32.show(count) ++ " items present)"}, pick_cons(n, rest)))

# S4.398 (spec twin) a number list judged against `count` items
def numbered(ps: List<&2, String>, +count: U32) -> Pick:
  match ps:
    case Nil{}:
      PickOk{Nil{}}
    case Con{p, rest}:
      number_one(Maybe.default(&2, U32, U32.read(p), 0), count, numbered(rest, count))

# S4.398 (spec twin) the text of an entry
def entry_text(e: Entry) -> String:
  match e:
    case Entry{index, text, checked}:
      text

# S4.398 (spec twin) the number of an entry
def entry_index(e: Entry) -> U32:
  match e:
    case Entry{index, text, checked}:
      index

# S4.398 (spec twin) keep an entry in front of the rest (the rest is computed once, whatever the verdict)
def entry_keep(e: Entry, keep: Bool, rest: List<&2, Entry>) -> List<&2, Entry>:
  match keep:
    case True{}:
      e <> rest
    case False{}:
      rest

# S4.398 (spec twin) the entries whose text equals a lowered selector, ignoring ASCII case
def exact_of(es: List<&2, Entry>, +low: String) -> List<&2, Entry>:
  match es:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      entry_keep(e, String.eq(Model.lowered(entry_text(e)), low), exact_of(rest, low))

# S4.398 (spec twin) the entries whose text contains a lowered selector, ignoring ASCII case
def subs_of(es: List<&2, Entry>, +low: String) -> List<&2, Entry>:
  match es:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      entry_keep(e, String.contains(Model.lowered(entry_text(e)), low), subs_of(rest, low))

# S4.398 (spec twin) a selector that names several items: refused, with the items it names
def ambiguous(+sel: String, +es: List<&2, Entry>) -> Pick:
  PickBad{Failure.quoted(sel) ++ " matches " ++ Nat.show(List.length(&2, Entry, es)) ++ " acceptance items; use the item number instead:\n" ++ String.join(item_lines(es), "\n")}

# S4.398 (spec twin) a text selector decided: one exact match wins, else one substring match; none is refused with
# every item, several with the ones it names
def text_pick(exact: List<&2, Entry>, subs: List<&2, Entry>, all: List<&2, Entry>, +sel: String) -> Pick:
  match exact subs:
    case Con{e, Nil{}} _:
      PickOk{entry_index(e) <> Nil{}}
    case Con{e, Con{f, more}} _:
      ambiguous(sel, e <> (f <> more))
    case Nil{} Nil{}:
      PickBad{"no acceptance item matches " ++ Failure.quoted(sel) ++ "; items are:\n" ++ String.join(item_lines(all), "\n")}
    case Nil{} Con{e, Nil{}}:
      PickOk{entry_index(e) <> Nil{}}
    case Nil{} Con{e, Con{f, more}}:
      ambiguous(sel, e <> (f <> more))

# S4.398 (spec twin) one selector judged against the entries: a number list when every comma piece is digits,
# else a text
def picked(+sel: String, +es: List<&2, Entry>) -> Pick:
  Bool.pick(Pick, all_numbers(String.split(sel, Chr{44})), numbered(String.split(sel, Chr{44}), U32.from_nat(List.length(&2, Entry, es))), text_pick(exact_of(es, Model.lowered(sel)), subs_of(es, Model.lowered(sel)), es, sel))

# S4.398 (data) the selectors of one flag, judged: the item numbers, or the failure
type Picks is Data:
  PicksOk{indices: List<&2, U32>}
  PicksBad{failure: Failure.Failure}

# S4.398 (spec twin) one judged selector folded in front of the rest; the first refusal wins
def picks_put(p: Pick, +field: String, +id: String, rest: Picks) -> Picks:
  match p rest:
    case PickBad{r} _:
      PicksBad{Create.invalid(field, id ++ ": " ++ r)}
    case PickOk{xs} PicksBad{f}:
      PicksBad{f}
    case PickOk{xs} PicksOk{ys}:
      PicksOk{List.append(&2, U32, xs, ys)}

# S4.398 (spec twin) every selector of one flag, in the order given; a refusal names the flag as its field
def picks(sels: List<&2, String>, +es: List<&2, Entry>, +field: String, +id: String) -> Picks:
  match sels:
    case Nil{}:
      PicksOk{Nil{}}
    case Con{+s, rest}:
      picks_put(picked(s, es), field, id, picks(rest, es, field, id))

# ---------------------------------------------------------------- applying

# S4.398 (spec twin) a number put into an ascending list without repeats
def u_insert(+x: U32, xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      x <> Nil{}
    case Con{+y, +rest}:
      Bool.pick(List<&2, U32>, (x < y : U32), x <> (y <> rest), Bool.pick(List<&2, U32>, U32.is_eq(x, y), y <> rest, y <> u_insert(x, rest)))

# S4.398 (spec twin) some numbers, ascending, each once
def u_sorted(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{x, rest}:
      u_sorted(rest, u_insert(x, acc))

# S4.398 (spec twin) is a number in a list
def u_among(xs: List<&2, U32>, +x: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{y, rest}:
      (U32.is_eq(x, y) || u_among(rest, x))

# S4.398 (spec twin) the mark of item `index` after the run: an uncheck writes ` `; a check writes `x` over ` ` and
# leaves `x` and `X` as they are
def mark_after(+index: U32, +mark: U32, +checks: List<&2, U32>, +unchecks: List<&2, U32>) -> U32:
  Bool.pick(U32, u_among(unchecks, index), 32, Bool.pick(U32, (u_among(checks, index) && U32.is_eq(mark, 32)), 120, mark))

# S4.398 (spec twin) one line after the run: only an item's mark can change
def line_text(l: Line, +index: U32, +checks: List<&2, U32>, +unchecks: List<&2, U32>) -> String:
  match l:
    case Item{lead, mark, after, text}:
      lead ++ SCon{Chr{mark_after(index, mark, checks, unchecks)}, after}
    case Other{t}:
      t

# S4.398 (spec twin) every line after the run, items numbered from `next`
def lines_after(lines: List<&2, Line>, +next: U32, +checks: List<&2, U32>, +unchecks: List<&2, U32>) -> List<&2, String>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{+l, rest}:
      line_text(l, next, checks, unchecks) <> lines_after(rest, (next + Bool.to_u32(is_item(l)) : U32), checks, unchecks)

# S4.398 (spec twin) the new item lines, `- [ ] <text>` each
def added_lines(adds: List<&2, String>) -> List<&2, String>:
  match adds:
    case Nil{}:
      Nil{}
    case Con{a, rest}:
      ("- [ ] " ++ a) <> added_lines(rest)

# S4.398 (spec twin) the additions appended: alone onto empty criteria, after a newline onto a text that does not
# end in one, and followed by one onto a text that does
def appended(+base: String, adds: List<&2, String>) -> String:
  match adds:
    case Nil{}:
      base
    case Con{+a, +rest}:
      Bool.pick(String, String.is_empty(base), String.join(added_lines(a <> rest), "\n"), Bool.pick(String, String.ends_with(base, "\n"), base ++ String.join(added_lines(a <> rest), "\n") ++ "\n", base ++ "\n" ++ String.join(added_lines(a <> rest), "\n")))

# S4.398 (spec twin) the numbers the additions take, after the `count` existing items
def added_range(adds: List<&2, String>, +count: U32) -> List<&2, U32>:
  match adds:
    case Nil{}:
      Nil{}
    case Con{a, rest}:
      (count + 1 : U32) <> added_range(rest, (count + 1 : U32))

# S4.398 (data) the answer of the three flags on one issue: the refusal, or the new text, whether a byte changed, the
# items after the run and the numbers checked, unchecked and added
type Done is Data:
  AccBad{failure: Failure.Failure}
  AccOk{text: String, changed: Bool, items: List<&2, Entry>, checked: List<&2, U32>, unchecked: List<&2, U32>, added: List<&2, U32>}

# S4.398 (spec twin) the run's answer once the new text is known
def finished(+old: String, +new: String, checks: List<&2, U32>, unchecks: List<&2, U32>, added: List<&2, U32>) -> Done:
  AccOk{new, Bool.not(String.eq(old, new)), entries(new), checks, unchecks, added}

# S4.398 (spec twin) the checks and unchecks applied line by line, then the additions appended
def applied(+old: String, +checks: List<&2, U32>, +unchecks: List<&2, U32>, +adds: List<&2, String>, +count: U32) -> Done:
  finished(old, appended(String.join(lines_after(lines_of(String.split(old, Chr{10})), 1, checks, unchecks), "\n"), adds), checks, unchecks, added_range(adds, count))

# S4.398 (spec twin) the run once both flags' selectors are judged
def selected(+old: String, +count: U32, c: Picks, u: Picks, +adds: List<&2, String>) -> Done:
  match c u:
    case PicksBad{f} _:
      AccBad{f}
    case PicksOk{xs} PicksBad{f}:
      AccBad{f}
    case PicksOk{xs} PicksOk{ys}:
      applied(old, u_sorted(xs, Nil{}), u_sorted(ys, Nil{}), adds, count)

# S4.398 (spec twin) a check or uncheck over criteria that hold no item is refused, under `check-acceptance` either way
def no_items(+id: String) -> Failure.Failure:
  Create.invalid("check-acceptance", id ++ ": acceptance_criteria has no checklist items to tick; append items first (--add-acceptance / add_acceptance) or set the whole field (--acceptance-criteria)")

# S4.398 (spec twin) is any selector the number 0
def zero_given(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+x, rest}:
      (String.eq(String.trim(x), "0") || zero_given(rest))

# S4.398 (spec twin) the refusal of item number 0 under the flag that named it
def zero_refusal(+flag: String, +id: String) -> Failure.Failure:
  Create.invalid(flag, id ++ ": acceptance item numbers are 1-based; 0 is not an item")

# S4.398 (spec twin) the run once no selector is 0
def judged_items(+id: String, +old: String, +es: List<&2, Entry>, +checks: List<&2, String>, +unchecks: List<&2, String>, +adds: List<&2, String>) -> Done:
  Bool.pick(Done, (List.is_empty(&2, Entry, es) && Bool.not((List.is_empty(&2, String, checks) && List.is_empty(&2, String, unchecks)))), AccBad{no_items(id)}, selected(old, U32.from_nat(List.length(&2, Entry, es)), picks(checks, es, "check-acceptance", id), picks(unchecks, es, "uncheck-acceptance", id), adds))

# S4.398 (spec twin) the run over the entries of the criteria before it: an item number 0 (`--check-acceptance`
# first) is refused before the no-items check (round 17: `r17_check0`, `r17_uncheck0_with_items`)
def judged(+id: String, +old: String, +es: List<&2, Entry>, +checks: List<&2, String>, +unchecks: List<&2, String>, +adds: List<&2, String>) -> Done:
  Bool.pick(Done, zero_given(checks), AccBad{zero_refusal("check-acceptance", id)}, Bool.pick(Done, zero_given(unchecks), AccBad{zero_refusal("uncheck-acceptance", id)}, judged_items(id, old, es, checks, unchecks, adds)))

# S4.398 (spec twin, entry) the three flags on one issue's criteria (`""` when it has none)
def run(+id: String, +old: String, +checks: List<&2, String>, +unchecks: List<&2, String>, +adds: List<&2, String>) -> Done:
  judged(id, old, entries(old), checks, unchecks, adds)

# ---------------------------------------------------------------- rendering a run

# S4.398 (spec twin) the numbers after the first, each behind a `,`
def index_tail(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      "," ++ U32.show(x) ++ index_tail(rest)

# S4.398 (spec twin) the numbers of a list joined by `,`
def index_list(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, rest}:
      U32.show(x) ++ index_tail(rest)

# S4.398 (spec twin) one part of the summary for a flag that was given: `<word> <k> (<i,j>)`
def part(given: Bool, +word: String, +xs: List<&2, U32>) -> List<&2, String>:
  Bool.pick(List<&2, String>, given, (word ++ " " ++ Nat.show(List.length(&2, U32, xs)) ++ " (" ++ index_list(xs) ++ ")") <> Nil{}, Nil{})

# S4.398 (spec twin) the summary line: the parts of the flags given, then `<c> of <n> complete` and `<r> remaining`
def summary(+es: List<&2, Entry>, checked: List<&2, U32>, unchecked: List<&2, U32>, added: List<&2, U32>, given_c: Bool, given_u: Bool, given_a: Bool) -> String:
  String.join(List.concat(&2, String, [part(given_c, "checked", checked), part(given_u, "unchecked", unchecked), part(given_a, "added", added), [U32.show(checked_count(es, 0)) ++ " of " ++ Nat.show(List.length(&2, Entry, es)) ++ " complete", U32.show((U32.from_nat(List.length(&2, Entry, es)) - checked_count(es, 0) : U32)) ++ " remaining"]]), " · ")

# S4.398 (spec twin, entry) the plain block of a run: the header, one line per item, the summary
def plain(d: Done, +id: String, given_c: Bool, given_u: Bool, given_a: Bool) -> String:
  match d:
    case AccBad{f}:
      ""
    case AccOk{text, changed, +es, checked, unchecked, added}:
      String.concat([id, " acceptance criteria (", Nat.show(List.length(&2, Entry, es)), Bool.pick(String, Nat.is_eq(List.length(&2, Entry, es), 1n), " item)", " items)"), "\n", item_block(es), summary(es, checked, unchecked, added, given_c, given_u, given_a), "\n"])

# S4.398 (spec twin) the numbers of a list as a JSON array body
def numbers_json(xs: List<&2, U32>) -> String:
  "[" ++ index_list(xs) ++ "]"

# S4.398 (spec twin, entry) the `acceptance_criteria` member the JSON element of a run gains
def json(d: Done) -> String:
  match d:
    case AccBad{f}:
      ""
    case AccOk{text, changed, +es, checked, unchecked, added}:
      String.concat([",\"acceptance_criteria\":{\"items\":[", String.join(entry_objects(es), ","), "],\"checked_count\":", U32.show(checked_count(es, 0)), ",\"total\":", Nat.show(List.length(&2, Entry, es)), ",\"remaining\":", U32.show((U32.from_nat(List.length(&2, Entry, es)) - checked_count(es, 0) : U32)), ",\"checked\":", numbers_json(checked), ",\"unchecked\":", numbers_json(unchecked), ",\"added\":", numbers_json(added), "}"])
