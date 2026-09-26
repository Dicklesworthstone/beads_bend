# core/render — what `list` and `count` print (S5.20, S5.32, S5.33, S5.52, S5.110–S5.125, S5.161–S5.166).
# Plain text and compact JSON, both as one String ended by its newline. Every
# untrusted one-line field passes the inline sanitizer of S5.112. Pieces are
# collected in lists and concatenated once. Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./query.bend as Query
import ./work.bend as Work
import ./blocked.bend as Blocked
import ./resolve.bend as Resolve

# S5.110 (spec twin) the glyph of a status; a status that is not built in prints `?`
def icon(+status: String) -> String:
  Bool.pick(String, String.eq(status, "open"), "○", Bool.pick(String, String.eq(status, "in_progress"), "◐", Bool.pick(String, String.eq(status, "blocked"), "●", Bool.pick(String, (String.eq(status, "deferred") || String.eq(status, "draft")), "❄", Bool.pick(String, String.eq(status, "closed"), "✓", Bool.pick(String, String.eq(status, "tombstone"), "✗", Bool.pick(String, String.eq(status, "pinned"), "📌", "?")))))))

# S5.112 (spec twin) one hexadecimal digit, lower case
def hex_char(+n: U32) -> U32:
  Bool.pick(U32, (n < 10 : U32), (n + 48 : U32), (n + 87 : U32))

# S5.112 (spec twin) a control character below U+0100 as `\u{h}` or `\u{hh}`: no leading zero
def escaped_hex(+c: U32, +acc: String) -> String:
  Bool.pick(String, (c < 16 : U32), SCon{Chr{92}, SCon{Chr{117}, SCon{Chr{123}, SCon{Chr{hex_char(c)}, SCon{Chr{125}, acc}}}}}, SCon{Chr{92}, SCon{Chr{117}, SCon{Chr{123}, SCon{Chr{hex_char((c / 16 : U32))}, SCon{Chr{hex_char((c % 16 : U32))}, SCon{Chr{125}, acc}}}}}})

# S5.112 (spec twin) route one code point: tab, line feed and carriage return have short forms; any other
# control character (U+0000–U+001F, U+007F–U+009F) is written in hexadecimal; everything else is itself
def inline_char(+c: U32, acc: String, tab: Bool, lf: Bool, cr: Bool, ctl: Bool) -> String:
  match tab lf cr ctl:
    case True{} _ _ _:
      SCon{Chr{92}, SCon{Chr{116}, acc}}
    case False{} True{} _ _:
      SCon{Chr{92}, SCon{Chr{110}, acc}}
    case False{} False{} True{} _:
      SCon{Chr{92}, SCon{Chr{114}, acc}}
    case False{} False{} False{} True{}:
      escaped_hex(c, acc)
    case False{} False{} False{} False{}:
      SCon{Chr{c}, acc}

# S5.112 (spec twin) a one-line field with every control character made visible
def inline(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      inline_char(c, inline(rest), U32.is_eq(c, 9), U32.is_eq(c, 10), U32.is_eq(c, 13), ((c < 32 : U32) || ((c >= 127 : U32) && (c <= 159 : U32))))

# S5.113 (spec twin) an instant as plain text prints its UTC date only: `2026-01-01`
def date(at: Time.Instant) -> String:
  String.take(Time.print(at, "Z"), 10n)

# S5.116 (spec twin) the one-line summary: `{icon} {id} [● P{n}] [{type}] - {title}`
def summary(+i: Model.Issue) -> String:
  String.concat([icon(Model.status_of(i)), " ", inline(Model.id_of(i)), " [● P", Model.priority_of(i), "] [", inline(Model.type_of(i)), "] - ", inline(Model.title_of(i)), "\n"])

# S5.117 (spec twin) a detail line for a present, non-empty text
def detail_text(label: String, value: Maybe<&2, String>) -> String:
  match value:
    case None{}:
      ""
    case Some{SNil{}}:
      ""
    case Some{SCon{h, t}}:
      "  " ++ label ++ inline(SCon{h, t}) ++ "\n"

# S5.117 (spec twin) a detail line for a present date
def detail_date(label: String, value: Maybe<&2, Time.Instant>) -> String:
  match value:
    case None{}:
      ""
    case Some{at}:
      "  " ++ label ++ date(at) ++ "\n"

# S5.117 S5.122 (spec twin) the block of `list --long`: the summary, then `Status`, `Priority`, `Type`, then
# `Assignee`, `Owner`, `Due`, `Deferred Until` when present, then `Created` and `Updated`; each detail line
# indented by two spaces. No `Labels` line is printed (golden list_long: the labelled issue has none)
def long_block(+i: Model.Issue) -> String:
  String.concat([summary(i), "  Status: ", inline(Model.status_of(i)), "\n  Priority: P", Model.priority_of(i), "\n  Type: ", inline(Model.type_of(i)), "\n", detail_text("Assignee: ", Model.assignee_of(i)), detail_text("Owner: ", Model.owner_of(i)), detail_date("Due: ", Model.due_of(i)), detail_date("Deferred Until: ", Model.defer_of(i)), "  Created: ", date(Model.created_of(i)), "\n  Updated: ", date(Model.updated_of(i)), "\n"])

# S5.128 (spec twin) one optional detail of a `--pretty` block, without indent: none when absent or empty
def item_text(label: String, value: Maybe<&2, String>) -> List<&2, String>:
  match value:
    case None{}:
      Nil{}
    case Some{SNil{}}:
      Nil{}
    case Some{SCon{h, t}}:
      (label ++ inline(SCon{h, t})) <> Nil{}

# S5.128 (spec twin) one optional date detail of a `--pretty` block
def item_date(label: String, value: Maybe<&2, Time.Instant>) -> List<&2, String>:
  match value:
    case None{}:
      Nil{}
    case Some{at}:
      (label ++ date(at)) <> Nil{}

# S5.128 (spec twin) the `Created`/`Updated` pair, which `--pretty` shows only together with `--long`
def item_stamps(+i: Model.Issue, long: Bool) -> List<&2, String>:
  match long:
    case True{}:
      ("Created: " ++ date(Model.created_of(i))) <> ("Updated: " ++ date(Model.updated_of(i))) <> Nil{}
    case False{}:
      Nil{}

# S5.128 (spec twin) the detail lines of a block in the order of S5.117, as items
def pretty_items(+i: Model.Issue, long: Bool) -> List<&2, String>:
  List.concat(&2, String, [("Status: " ++ inline(Model.status_of(i))) <> ("Priority: P" ++ Model.priority_of(i)) <> ("Type: " ++ inline(Model.type_of(i))) <> Nil{}, item_text("Assignee: ", Model.assignee_of(i)), item_text("Owner: ", Model.owner_of(i)), item_date("Due: ", Model.due_of(i)), item_date("Deferred Until: ", Model.defer_of(i)), item_stamps(i, long)])

# S5.128 (spec twin) the connectors: `├── ` before every detail but the last, `└── ` before the last
def connected(items: List<&2, String>) -> List<&2, String>:
  match items:
    case Nil{}:
      Nil{}
    case Con{x, Nil{}}:
      ("└── " ++ x ++ "\n") <> Nil{}
    case Con{x, rest}:
      ("├── " ++ x ++ "\n") <> connected(rest)

# S5.128 (spec twin) one `--pretty` block: the summary line unchanged, then the connected details
def pretty_block(+i: Model.Issue, long: Bool) -> String:
  summary(i) ++ String.concat(connected(pretty_items(i, long)))

# S5.128 S5.122 (spec twin) one `--pretty` block per issue with one blank line between blocks, none at either end
def pretty_blocks(issues: List<&2, Model.Issue>, +long: Bool) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{i, Nil{}}:
      pretty_block(i, long) <> Nil{}
    case Con{i, rest}:
      pretty_block(i, long) <> "\n" <> pretty_blocks(rest, long)

# S5.120 (spec twin) one summary line per issue, nothing before, between or after
def lines(issues: List<&2, Model.Issue>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{i, rest}:
      summary(i) <> lines(rest)

# S5.122 (spec twin) one block per issue with ONE blank line between consecutive blocks, none at either end
def blocks(issues: List<&2, Model.Issue>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{i, Nil{}}:
      long_block(i) <> Nil{}
    case Con{i, rest}:
      long_block(i) <> "\n" <> blocks(rest)

# ---------------------------------------------------------------- `list --tree` (S5.127)

# S5.127 (spec twin) every code point an ASCII digit
def all_digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      (((c >= 48 : U32) && (c <= 57 : U32)) && all_digits(rest))

# S5.127 (spec twin) a non-empty run of ASCII digits
def is_number(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{h, t}:
      all_digits(SCon{h, t})

# S5.127 (spec twin) the parent half of a cut at the last `.`, when the other half is a child number
def dotted_pick(c: Resolve.Cut) -> String:
  match c:
    case Resolve.Cut{+left, +right, True{}}:
      Bool.pick(String, (String.is_empty(left) || Bool.not(is_number(right))), "", left)
    case Resolve.Cut{left, right, False{}}:
      ""

# S5.127 (spec twin) the id a dotted child id hangs from: `proj-abk.10.1` → `proj-abk.10`; "" for an id that is not
# a child id (its last `.` part is not a number)
def dotted_parent(+id: String) -> String:
  dotted_pick(Resolve.cut_last(id, 46))

# S5.127 (spec twin) is this id among the listed ones
def listed(ids: List<&2, String>, +id: String) -> Bool:
  match ids:
    case Nil{}:
      False{}
    case Con{+x, rest}:
      (String.eq(x, id) || listed(rest, id))

# S5.127 (spec twin) the nearest listed ancestor of an id by its dotted parents; "" when none is listed. One step per
# code point of the id bounds the walk: every step drops a `.` part
def ancestor(fuel: Nat, +ids: List<&2, String>, +id: String) -> String:
  match fuel:
    case Zero{}:
      ""
    case Succ{f}:
      Bool.pick(String, String.is_empty(dotted_parent(id)), "", Bool.pick(String, listed(ids, dotted_parent(id)), dotted_parent(id), ancestor(f, ids, dotted_parent(id))))

# S5.127 (spec twin) the listed node an issue hangs under
def hangs_under(+ids: List<&2, String>, +i: Model.Issue) -> String:
  ancestor((String.length(Model.id_of(i)) + 1n : Nat), ids, Model.id_of(i))

# S5.127 (data) one child under a node: the issue, and its child number when it is a DIRECT dotted child (the order
# key), none when it was adopted past an unlisted parent
type Kid is Data:
  Kid{issue: Model.Issue, number: Maybe<&2, U32>}

# S5.127 (spec twin) the child number of a direct dotted child, from its last `.` part
def kid_number(+i: Model.Issue, +node: String) -> Maybe<&2, U32>:
  Bool.pick(Maybe<&2, U32>, String.eq(dotted_parent(Model.id_of(i)), node), U32.read(Resolve.remainder_of(Resolve.cut_last(Model.id_of(i), 46))), None{})

# S5.127 (spec twin) keep a kid when it hangs under the node
def kid_put(k: Kid, keep: Bool, rest: List<&2, Kid>) -> List<&2, Kid>:
  match keep:
    case True{}:
      k <> rest
    case False{}:
      rest

# S5.127 (spec twin) the listed issues that hang under `node` ("" for the roots), in list order
def kids_of(issues: List<&2, Model.Issue>, +ids: List<&2, String>, +node: String) -> List<&2, Kid>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      kid_put(Kid{i, kid_number(i, node)}, String.eq(hangs_under(ids, i), node), kids_of(rest, ids, node))

# S5.127 (spec twin) the order of the kids of a node: direct children first, by child number (`.9` before `.10`,
# whatever `--sort` says), then the adopted ones in list order (`proj-abk.10.1` then `proj-abk.3.1`)
def kid_le(x: Kid, y: Kid) -> Bool:
  match x y:
    case Kid{a, Some{n}} Kid{b, Some{m}}:
      (n <= m : U32)
    case Kid{a, Some{n}} Kid{b, None{}}:
      True{}
    case Kid{a, None{}} Kid{b, Some{m}}:
      False{}
    case Kid{a, None{}} Kid{b, None{}}:
      True{}

# S5.127 (data) one pending line of the tree: the issue, the prefix its line starts with, the prefix its own kids get
type Row is Data:
  Row{issue: Model.Issue, lead: String, below: String}

# S5.127 (spec twin) the rows of a node's kids: `├── ` and `│   ` for all but the last, `└── ` and `    ` for the last
def kid_rows(kids: List<&2, Kid>, +prefix: String) -> List<&2, Row>:
  match kids:
    case Nil{}:
      Nil{}
    case Con{Kid{i, n}, Nil{}}:
      Row{i, prefix ++ "└── ", prefix ++ "    "} <> Nil{}
    case Con{Kid{i, n}, rest}:
      Row{i, prefix ++ "├── ", prefix ++ "│   "} <> kid_rows(rest, prefix)

# S5.127 (spec twin) the roots' rows: no connector at all
def root_rows(kids: List<&2, Kid>) -> List<&2, Row>:
  match kids:
    case Nil{}:
      Nil{}
    case Con{Kid{i, n}, rest}:
      Row{i, "", ""} <> root_rows(rest)

# S5.127 (spec twin) the tree in pre-order: pop a row, print it, push its kids' rows in front. Every listed issue is
# printed once (it hangs under exactly one node), so one unit of fuel per issue suffices
def tree_go(fuel: Nat, stack: List<&2, Row>, +issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> List<&2, String>:
  match fuel stack:
    case Zero{} _:
      Nil{}
    case Succ{f} Nil{}:
      Nil{}
    case Succ{f} Con{Row{+i, lead, +below}, rest}:
      (lead ++ summary(i)) <> tree_go(f, List.append(&2, Row, kid_rows(List.sort(~Kid, ~kid_le, kids_of(issues, ids, Model.id_of(i))), below), rest), issues, ids)

# S5.127 (spec twin) `list --tree` over the listed page: roots in list order, each child under its nearest listed
# ancestor by dotted id (a `parent-child` edge between undotted ids does not nest: `list_tree`)
def tree_lines(+issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> List<&2, String>:
  tree_go((List.length(&2, Model.Issue, issues) + 1n : Nat), root_rows(kids_of(issues, ids, "")), issues, ids)

# S5.127 (spec twin) the ids of the listed page
def ids_of(issues: List<&2, Model.Issue>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      Model.id_of(i) <> ids_of(rest)

# S5.120 S5.122 (spec twin) the listing without `--tree` and `--pretty`: blocks under `--long`, summary lines otherwise
def list_flat(issues: List<&2, Model.Issue>, long: Bool) -> String:
  match long:
    case True{}:
      String.concat(blocks(issues))
    case False{}:
      String.concat(lines(issues))

# S5.128 (spec twin) the listing without `--tree`: `--pretty` draws the details with connectors, and with `--long`
# adds the `Created`/`Updated` pair
def list_drawn(issues: List<&2, Model.Issue>, long: Bool, pretty: Bool) -> String:
  match pretty:
    case True{}:
      String.concat(pretty_blocks(issues, long))
    case False{}:
      list_flat(issues, long)

# S5.120–S5.122 S5.127 S5.128 (spec twin) the plain listing; an empty result prints nothing at all (S5.121);
# `--tree` wins over `--long` and `--pretty` and prints summary lines only (`list_tree_long`)
def list_plain(+issues: List<&2, Model.Issue>, long: Bool, pretty: Bool, tree: Bool) -> String:
  match tree:
    case True{}:
      String.concat(tree_lines(issues, ids_of(issues)))
    case False{}:
      list_drawn(issues, long, pretty)

# S5.124 (spec twin) the note a truncating limit writes to stderr before the listing: with the total when the
# filters ran outside the query (`exact`), without it otherwise; nothing when nothing was cut
def truncation_note(cut: Bool, exact: Bool, shown: Nat, total: Nat) -> String:
  match cut exact:
    case False{} _:
      ""
    case True{} True{}:
      "[note] Showing " ++ Nat.show(shown) ++ " of " ++ Nat.show(total) ++ " issues. Use --limit 0 for all results.\n"
    case True{} False{}:
      "[note] Output truncated to " ++ Nat.show(shown) ++ " issues. Use --limit 0 for all results.\n"

# S5.33 (spec twin) one element of `list --json`: `dependency_count` is the number of the issue's own edges,
# `dependent_count` the number of edges in the whole store (`all`) that point at it
def element(+i: Model.Issue, all: List<&2, Model.Issue>) -> String:
  Model.listed(i, U32.from_nat(List.length(&2, Model.Dependency, Model.deps_of(i))), Query.dependents(all, Model.id_of(i), 0))

# S5.33 (spec twin) the elements of `list --json`, each preceded by `,` except the first
def elements(issues: List<&2, Model.Issue>, +all: List<&2, Model.Issue>, first: Bool) -> List<&2, String>:
  match issues first:
    case Nil{} _:
      Nil{}
    case Con{i, rest} True{}:
      element(i, all) <> elements(rest, all, False{})
    case Con{i, rest} False{}:
      "," <> element(i, all) <> elements(rest, all, False{})

# S5.20 S5.32 (spec twin) the envelope of `list --json`: five members, always present, in this order, compact, one newline
def list_json(issues: List<&2, Model.Issue>, all: List<&2, Model.Issue>, total: Nat, limit: Nat, offset: Nat, more: Bool) -> String:
  String.concat(["{\"issues\":[", String.concat(elements(issues, all, True{})), "],\"total\":", Nat.show(total), ",\"limit\":", Nat.show(limit), ",\"offset\":", Nat.show(offset), ",\"has_more\":", Failure.bool_text(more), "}\n"])

# S5.162 (spec twin) one line per group: `{group}: {count}`, no indentation
def group_lines(groups: List<&2, Query.Group>) -> List<&2, String>:
  match groups:
    case Nil{}:
      Nil{}
    case Con{Query.Group{key, count}, rest}:
      (inline(key) ++ ": " ++ U32.show(count) ++ "\n") <> group_lines(rest)

# S5.52 (spec twin) the groups as JSON objects, each preceded by `,` except the first
def group_objects(groups: List<&2, Query.Group>, first: Bool) -> List<&2, String>:
  match groups first:
    case Nil{} _:
      Nil{}
    case Con{Query.Group{key, count}, rest} True{}:
      ("{\"group\":" ++ Failure.quoted(key) ++ ",\"count\":" ++ U32.show(count) ++ "}") <> group_objects(rest, False{})
    case Con{Query.Group{key, count}, rest} False{}:
      (",{\"group\":" ++ Failure.quoted(key) ++ ",\"count\":" ++ U32.show(count) ++ "}") <> group_objects(rest, False{})

# S5.52 S5.161 S5.162 (spec twin) what `count` prints: the bare total, or `Total:` and the groups; as JSON
# `{"count":n}` or `{"total":n,"groups":[…]}`
def count_text(total: Nat, groups: List<&2, Query.Group>, by_group: Bool, json: Bool) -> String:
  match by_group json:
    case False{} False{}:
      Nat.show(total) ++ "\n"
    case False{} True{}:
      "{\"count\":" ++ Nat.show(total) ++ "}\n"
    case True{} False{}:
      "Total: " ++ Nat.show(total) ++ "\n" ++ String.concat(group_lines(groups))
    case True{} True{}:
      "{\"total\":" ++ Nat.show(total) ++ ",\"groups\":[" ++ String.concat(group_objects(groups, True{})) ++ "]}\n"

# S4.141 (spec twin) the line that follows a cut page of search results, on STDOUT
def more_note(more: Bool, shown: Nat, offset: Nat, limit: Nat) -> String:
  match more:
    case False{}:
      ""
    case True{}:
      "note: showing " ++ Nat.show(shown) ++ " search result(s) from offset " ++ Nat.show(offset) ++ "; more matches exist. Use --limit 0 for all results (current limit: " ++ Nat.show(limit) ++ ")\n"

# S4.142 S5.159 (spec twin) the line that tells of closed matches the default exclusion hid, on STDOUT
def hidden_note(+hidden: Nat) -> String:
  Bool.pick(String, Nat.is_eq(hidden, 0n), "", "note: " ++ Nat.show(hidden) ++ " closed match(es) hidden; rerun with --all to include them\n")

# S5.156–S5.159 (spec twin) plain `search`: the header (`Showing` when the page was cut, `Found` otherwise) with the
# number of rows shown and the query between single quotes, the rows, then the notes: the hidden-closed note first,
# then the more-matches note (`search_limit`)
def search_plain(+page: List<&2, Model.Issue>, query: String, +more: Bool, offset: Nat, limit: Nat, hidden: Nat) -> String:
  String.concat([Bool.pick(String, more, "Showing ", "Found "), Nat.show(List.length(&2, Model.Issue, page)), " issue(s) matching '", inline(query), "'\n", String.concat(lines(page)), hidden_note(hidden), more_note(more, List.length(&2, Model.Issue, page), offset, limit)])

# S5.34 (spec twin) the envelope of `search --json`: no `total`, and `hidden_closed_count` in its place
def search_json(page: List<&2, Model.Issue>, all: List<&2, Model.Issue>, hidden: Nat, limit: Nat, offset: Nat, more: Bool) -> String:
  String.concat(["{\"issues\":[", String.concat(elements(page, all, True{})), "],\"hidden_closed_count\":", Nat.show(hidden), ",\"limit\":", Nat.show(limit), ",\"offset\":", Nat.show(offset), ",\"has_more\":", Failure.bool_text(more), "}\n"])

# ---------------------------------------------------------------- CSV (`list`/`search --format csv`, round 17)

# S1.61 (data) the columns `--format csv` prints when `--fields` is absent or `""`
def csv_default() -> List<&2, String>:
  ["id", "title", "status", "priority", "issue_type", "assignee", "created_at", "updated_at"]

# S1.61 (data) the fifteen column names `--fields` knows under CSV; any other name is dropped (`labels`, `foo`)
def csv_known() -> List<&2, String>:
  ["id", "title", "description", "notes", "status", "priority", "issue_type", "assignee", "owner", "created_at", "updated_at", "closed_at", "due_at", "defer_until", "external_ref"]

# S1.61 (spec twin) a name in front of the rest when it is kept
def csv_put(n: String, keep: Bool, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      n <> rest
    case False{}:
      rest

# S1.61 (spec twin) the known names among the given ones, in the given order, repeats kept
def csv_kept(names: List<&2, String>) -> List<&2, String>:
  match names:
    case Nil{}:
      Nil{}
    case Con{+n, rest}:
      csv_put(n, Model.listed_word(csv_known(), n), csv_kept(rest))

# S1.61 (spec twin) the columns: `--fields` split at commas, each piece trimmed, empty pieces skipped, unknown names
# dropped (`--fields ,` prints an empty header and an empty line per row); absent or `""` is the default eight
def csv_columns(given: Maybe<&2, String>) -> List<&2, String>:
  match given:
    case None{}:
      csv_default()
    case Some{+v}:
      Bool.pick(List<&2, String>, String.is_empty(v), csv_default(), csv_kept(Query.comma_split([v])))

# S1.61 (spec twin) does a value start a spreadsheet formula: `=`, `+`, `-`, `@`, a tab, a carriage return or a newline
def csv_formula(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, rest}:
      (U32.is_eq(c, 61) || U32.is_eq(c, 43) || U32.is_eq(c, 45) || U32.is_eq(c, 64) || U32.is_eq(c, 9) || U32.is_eq(c, 13) || U32.is_eq(c, 10))

# S1.61 (spec twin) does a value hold a comma, a double quote, a newline or a carriage return
def csv_special(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, rest}:
      (U32.is_eq(c, 44) || U32.is_eq(c, 34) || U32.is_eq(c, 10) || U32.is_eq(c, 13) || csv_special(rest))

# S1.61 (spec twin) one character in front of the rest, twice when it is a double quote
def csv_char(c: U32, quote: Bool, rest: String) -> String:
  match quote:
    case True{}:
      SCon{Chr{34}, SCon{Chr{34}, rest}}
    case False{}:
      SCon{Chr{c}, rest}

# S1.61 (spec twin) a value with every double quote doubled
def csv_doubled(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, rest}:
      csv_char(c, U32.is_eq(c, 34), csv_doubled(rest))

# S1.61 (spec twin) one cell: a formula start gets a `'` before it and is always quoted; otherwise a value with a
# comma, a quote or a line break is quoted; quotes inside are doubled
def csv_cell(+s: String) -> String:
  Bool.pick(String, csv_formula(s), "\"'" ++ csv_doubled(s) ++ "\"", Bool.pick(String, csv_special(s), "\"" ++ csv_doubled(s) ++ "\"", s))

# S1.61 (spec twin) an optional text, empty when absent
def csv_text(m: Maybe<&2, String>) -> String:
  Maybe.default(&2, String, m, "")

# S1.61 (spec twin) an optional instant with `+00:00`, empty when absent
def csv_time(m: Maybe<&2, Time.Instant>) -> String:
  match m:
    case None{}:
      ""
    case Some{t}:
      Time.print(t, "+00:00")

# S1.61 (spec twin) one issue's value of one column
def csv_value(+name: String, +i: Model.Issue) -> String:
  Bool.pick(String, String.eq(name, "id"), Model.id_of(i), Bool.pick(String, String.eq(name, "title"), Model.title_of(i), Bool.pick(String, String.eq(name, "description"), csv_text(Model.description_of(i)), Bool.pick(String, String.eq(name, "notes"), csv_text(Model.notes_of(i)), Bool.pick(String, String.eq(name, "status"), Model.status_of(i), Bool.pick(String, String.eq(name, "priority"), Model.priority_of(i), Bool.pick(String, String.eq(name, "issue_type"), Model.type_of(i), Bool.pick(String, String.eq(name, "assignee"), csv_text(Model.assignee_of(i)), Bool.pick(String, String.eq(name, "owner"), csv_text(Model.owner_of(i)), Bool.pick(String, String.eq(name, "created_at"), Time.print(Model.created_of(i), "+00:00"), Bool.pick(String, String.eq(name, "updated_at"), Time.print(Model.updated_of(i), "+00:00"), Bool.pick(String, String.eq(name, "closed_at"), csv_time(Model.closed_of(i)), Bool.pick(String, String.eq(name, "due_at"), csv_time(Model.due_of(i)), Bool.pick(String, String.eq(name, "defer_until"), csv_time(Model.defer_of(i)), csv_text(Model.external_ref_of(i))))))))))))))))

# S1.61 (spec twin) one row's cells
def csv_cells(names: List<&2, String>, +i: Model.Issue) -> List<&2, String>:
  match names:
    case Nil{}:
      Nil{}
    case Con{+n, rest}:
      csv_cell(csv_value(n, i)) <> csv_cells(rest, i)

# S1.61 (spec twin) the rows, one line each
def csv_rows(issues: List<&2, Model.Issue>, +names: List<&2, String>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      (String.join(csv_cells(names, i), ",") ++ "\n") <> csv_rows(rest, names)

# S1.61 (spec twin) `list`/`search --format csv`: the header of column names, then one line per row of the page
def csv_text_of(+page: List<&2, Model.Issue>, +names: List<&2, String>) -> String:
  String.join(names, ",") ++ "\n" ++ String.concat(csv_rows(page, names))

# ---------------------------------------------------------------- ready (S5.36, S5.130–S5.136)

# S5.131 (spec twin) the rows of `ready`: `{index}. [● P{n}] [{type}] {id}: {title}`, numbered from 1
def ready_lines(issues: List<&2, Model.Issue>, +index: U32) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      String.concat([U32.show(index), ". [● P", Model.priority_of(i), "] [", inline(Model.type_of(i)), "] ", inline(Model.id_of(i)), ": ", inline(Model.title_of(i)), "\n"]) <> ready_lines(rest, (index + 1 : U32))

# S4.178 S5.133 (spec twin) the one line an empty `ready` prints: nothing active; a filter was asked for; or nothing is actionable
def ready_empty(any_active: Bool, filtered: Bool) -> String:
  match any_active filtered:
    case False{} _:
      "✨ All work complete — no issues to work on\n"
    case True{} True{}:
      "✨ No ready issues match the requested filters or configured ready status group\n"
    case True{} False{}:
      "✨ No ready issues — remaining work is not currently actionable\n"

# S5.130–S5.133 (spec twin) plain `ready`: the header with the number of rows SHOWN, one blank line, the rows
def ready_plain(+page: List<&2, Model.Issue>, any_active: Bool, filtered: Bool) -> String:
  match page:
    case Nil{}:
      ready_empty(any_active, filtered)
    case Con{i, rest}:
      String.concat(["📋 Ready work (", Nat.show(List.length(&2, Model.Issue, page)), Bool.pick(String, Nat.is_eq(List.length(&2, Model.Issue, page), 1n), " issue", " issues"), " with no blockers):\n\n", String.concat(ready_lines(page, 1))])

# S4.177 S5.134 (spec twin) the note a truncating limit writes to stderr
def ready_note(+shown: Nat, +total: Nat) -> String:
  Bool.pick(String, Nat.is_lt(shown, total), "[note] Showing " ++ Nat.show(shown) ++ " of " ++ Nat.show(total) ++ " ready issues. Use --limit 0 for all results.\n", "")

# S5.36 (spec twin) one element of `ready --json`: sixteen members in this order, `labels` always present
def ready_object(+i: Model.Issue) -> String:
  "{" ++ Model.joined([Model.o_str("acceptance_criteria", Model.acceptance_of(i)), Model.o_str("prerequisites", Model.prerequisites_of(i)), Model.o_str("assignee", Model.assignee_of(i)), Model.m_time("created_at", Model.created_of(i)), Model.o_str("created_by", Model.created_by_of(i)), Model.o_str("description", Model.description_of(i)), Model.o_int("estimated_minutes", Model.estimate_of(i)), Model.m_str("id", Model.id_of(i)), Model.m_str("issue_type", Model.type_of(i)), "\"labels\":[" ++ Model.strings_text(Model.labels_of(i)) ++ "]", Model.o_str("notes", Model.notes_of(i)), Model.o_str("owner", Model.owner_of(i)), Model.m_int("priority", Model.priority_of(i)), Model.m_str("status", Model.status_of(i)), Model.m_str("title", Model.title_of(i)), Model.m_time("updated_at", Model.updated_of(i))]) ++ "}"

# S5.36 (spec twin) the elements of `ready --json`, each preceded by `,` except the first
def ready_objects(issues: List<&2, Model.Issue>, first: Bool) -> List<&2, String>:
  match issues first:
    case Nil{} _:
      Nil{}
    case Con{i, rest} True{}:
      ready_object(i) <> ready_objects(rest, False{})
    case Con{i, rest} False{}:
      "," <> ready_object(i) <> ready_objects(rest, False{})

# S5.36 (spec twin) `ready --json`: a bare array, `[]` when nothing is ready
def ready_json(page: List<&2, Model.Issue>) -> String:
  "[" ++ String.concat(ready_objects(page, True{})) ++ "]\n"

# ---------------------------------------------------------------- blocked (S5.35, S5.137–S5.142)

# S5.139–S5.141 (spec twin) the two lines of one blocked issue; `dependencies` is never singular
def blocked_line(+issue: Model.Issue, +blockers: List<&2, String>) -> String:
  String.concat(["[● P", Model.priority_of(issue), "] ", inline(Model.id_of(issue)), ": ", inline(Model.title_of(issue)), "\n  Blocked by ", Nat.show(List.length(&2, String, blockers)), " open dependencies: [", inline(String.join(blockers, ", ")), "]\n"])

# S5.254 (spec twin) one blocker bullet of `blocked --detailed`: `    • {id}: {title} [P{n}] [{status}]`, and
# `    • {id}:blocked (not found)` for a blocker with no stored record (an `external:` target)
def blocker_bullet(found: Maybe<&2, Model.Issue>, id: String) -> String:
  match found:
    case None{}:
      "    • " ++ inline(id) ++ ":blocked (not found)\n"
    case Some{+i}:
      String.concat(["    • ", inline(id), ": ", inline(Model.title_of(i)), " [P", Model.priority_of(i), "] [", inline(Model.status_of(i)), "]\n"])

# S5.254 (spec twin) the blocker bullets, in the order of the issue's blockers
def blocker_bullets(ids: List<&2, String>, +all: List<&2, Model.Issue>) -> List<&2, String>:
  match ids:
    case Nil{}:
      Nil{}
    case Con{+x, rest}:
      blocker_bullet(Blocked.lookup(all, x), x) <> blocker_bullets(rest, all)

# S5.254 (spec twin) one blocked issue under `--detailed`: its line, `  Blocked by:`, then one bullet per blocker
def blocked_detail(+issue: Model.Issue, blockers: List<&2, String>, +all: List<&2, Model.Issue>) -> String:
  String.concat(["[● P", Model.priority_of(issue), "] ", inline(Model.id_of(issue)), ": ", inline(Model.title_of(issue)), "\n  Blocked by:\n", String.concat(blocker_bullets(blockers, all))])

# S5.139 S5.254 (spec twin) one blocked issue, in the summary form or the detailed one
def blocked_row(detailed: Bool, +issue: Model.Issue, +blockers: List<&2, String>, +all: List<&2, Model.Issue>) -> String:
  match detailed:
    case True{}:
      blocked_detail(issue, blockers, all)
    case False{}:
      blocked_line(issue, blockers)

# S5.139 (spec twin) every blocked issue, in the command's order
def blocked_lines(rows: List<&2, Work.Row>, +detailed: Bool, +all: List<&2, Model.Issue>) -> List<&2, String>:
  match rows:
    case Nil{}:
      Nil{}
    case Con{Work.Row{issue, blockers}, rest}:
      blocked_row(detailed, issue, blockers, all) <> blocked_lines(rest, detailed, all)

# S5.137 S5.138 S5.142 S5.254 (spec twin) plain `blocked`: a blank line, the header with the TOTAL before any
# limit, a blank line, the rows; `detailed` and the records `all` serve `--detailed`
def blocked_plain(page: List<&2, Work.Row>, total: Nat, detailed: Bool, all: List<&2, Model.Issue>) -> String:
  match page:
    case Nil{}:
      "✨ No blocked issues\n"
    case Con{r, rest}:
      "\n🚫 Blocked issues (" ++ Nat.show(total) ++ "):\n\n" ++ String.concat(blocked_lines(r <> rest, detailed, all))

# S4.170 (spec twin) the note a truncating limit writes to stderr
def blocked_note(+shown: Nat, +total: Nat) -> String:
  Bool.pick(String, Nat.is_lt(shown, total), "[note] Showing " ++ Nat.show(shown) ++ " of " ++ Nat.show(total) ++ " blocked issues. Use --limit 0 for all results.\n", "")

# S5.35 (spec twin) one element of `blocked --json`: eleven members in this order, `created_by` and `description` omitted when not set
def blocked_object(r: Work.Row) -> String:
  match r:
    case Work.Row{+i, +blockers}:
      "{" ++ Model.joined(["\"blocked_by\":[" ++ Model.strings_text(blockers) ++ "]", "\"blocked_by_count\":" ++ Nat.show(List.length(&2, String, blockers)), Model.m_time("created_at", Model.created_of(i)), Model.o_str("created_by", Model.created_by_of(i)), Model.o_str("description", Model.description_of(i)), Model.m_str("id", Model.id_of(i)), Model.m_str("issue_type", Model.type_of(i)), Model.m_int("priority", Model.priority_of(i)), Model.m_str("status", Model.status_of(i)), Model.m_str("title", Model.title_of(i)), Model.m_time("updated_at", Model.updated_of(i))]) ++ "}"

# S5.35 (spec twin) the elements of `blocked --json`, each preceded by `,` except the first
def blocked_objects(rows: List<&2, Work.Row>, first: Bool) -> List<&2, String>:
  match rows first:
    case Nil{} _:
      Nil{}
    case Con{r, rest} True{}:
      blocked_object(r) <> blocked_objects(rest, False{})
    case Con{r, rest} False{}:
      "," <> blocked_object(r) <> blocked_objects(rest, False{})

# S4.170 S5.35 (spec twin) the envelope of `blocked --json`; `offset` is always 0
def blocked_json(page: List<&2, Work.Row>, total: Nat, limit: Nat, more: Bool) -> String:
  String.concat(["{\"issues\":[", String.concat(blocked_objects(page, True{})), "],\"total\":", Nat.show(total), ",\"limit\":", Nat.show(limit), ",\"offset\":0,\"has_more\":", Failure.bool_text(more), "}\n"])

# ---------------------------------------------------------------- stats (S5.53, S5.167–S5.171)

# S5.169 (spec twin) a summary row that is printed only when its figure is above zero
def row_if(label: String, +n: U32) -> String:
  Bool.pick(String, U32.is_eq(n, 0), "", label ++ U32.show(n) ++ "\n")

# S5.170 (spec twin) the `Deleted:` row of the `Extended:` block: the count with ` (tombstones)` after it
# (`scn_stats_tombstone`), nothing without tombstones
def deleted_row(+n: U32) -> String:
  Bool.pick(String, U32.is_eq(n, 0), "", "  Deleted:                " ++ U32.show(n) ++ " (tombstones)\n")

# S5.170 (spec twin) the `Extended:` block: only when a lead time exists or tombstones exist
def extended(lead: String, +tombstones: U32) -> String:
  match lead:
    case SNil{}:
      Bool.pick(String, U32.is_eq(tombstones, 0), "", "\nExtended:\n" ++ deleted_row(tombstones))
    case SCon{h, t}:
      "\nExtended:\n  Avg Lead Time:          " ++ SCon{h, t} ++ "\n" ++ deleted_row(tombstones)

# ---------------------------------------------------------------- the `stats` breakdowns (S5.53, S5.172)

# S5.172 (spec twin) a dimension's name: 1 priority, 2 type, 3 assignee, 4 label (Query.group_keys' numbers)
def dimension_name(+d: U32) -> String:
  Bool.pick(String, U32.is_eq(d, 1), "priority", Bool.pick(String, U32.is_eq(d, 2), "type", Bool.pick(String, U32.is_eq(d, 3), "assignee", "label")))

# S5.172 (spec twin) one row of a breakdown: `  {key}: {count}`
def break_rows(groups: List<&2, Query.Group>) -> List<&2, String>:
  match groups:
    case Nil{}:
      Nil{}
    case Con{Query.Group{key, count}, rest}:
      ("  " ++ inline(key) ++ ": " ++ U32.show(count) ++ "\n") <> break_rows(rest)

# S5.53 (spec twin) one count of a breakdown as JSON: `{"key":…,"count":…}`, `,` before all but the first
def break_objects(groups: List<&2, Query.Group>, first: Bool) -> List<&2, String>:
  match groups:
    case Nil{}:
      Nil{}
    case Con{Query.Group{key, count}, rest}:
      (Bool.pick(String, first, "", ",") ++ "{\"key\":" ++ Failure.quoted(key) ++ ",\"count\":" ++ U32.show(count) ++ "}") <> break_objects(rest, False{})

# S5.172 (spec twin) the plain blocks: for each dimension a blank line, `By {dimension}:`, then its rows (an empty
# store keeps the heading with no rows, `empty_stats_by_type_label`); the groups are those of `count --by` (S4.148,
# S4.149) over the records that are not tombstones (`scn_stats_tombstone`)
def breaks_plain(dims: List<&2, U32>, +live: List<&2, Model.Issue>) -> String:
  match dims:
    case Nil{}:
      ""
    case Con{+d, rest}:
      "\nBy " ++ dimension_name(d) ++ ":\n" ++ String.concat(break_rows(Query.grouped(live, d, Nil{}))) ++ breaks_plain(rest, live)

# S5.53 (spec twin) the `breakdowns` array's elements, in the fixed dimension order
def breaks_objects(dims: List<&2, U32>, +live: List<&2, Model.Issue>, first: Bool) -> List<&2, String>:
  match dims:
    case Nil{}:
      Nil{}
    case Con{+d, rest}:
      (Bool.pick(String, first, "", ",") ++ "{\"dimension\":\"" ++ dimension_name(d) ++ "\",\"counts\":[" ++ String.concat(break_objects(Query.grouped(live, d, Nil{}), True{})) ++ "]}") <> breaks_objects(rest, live, False{})

# S5.53 (spec twin) the `breakdowns` member after `summary`, absent without a `--by-*` flag
def breaks_json(dims: List<&2, U32>, +live: List<&2, Model.Issue>) -> String:
  match dims:
    case Nil{}:
      ""
    case Con{d, rest}:
      ",\"breakdowns\":[" ++ String.concat(breaks_objects(d <> rest, live, True{})) ++ "]"

# S5.167–S5.171 (spec twin) plain `stats`; every value starts at column 27; `lead` is the lead-time text with its unit, "" when there is none
def stats_plain(f: Work.Figures, lead: String, breaks: String) -> String:
  match f:
    case Work.Figures{total, open, in_progress, closed, blocked, deferred, draft, ready, +tombstone, pinned, epics, lead_sum, lead_count}:
      String.concat(["📊 Issue Database Status\n\nSummary:\n  Total Issues:           ", U32.show(total), "\n  Open:                   ", U32.show(open), "\n  In Progress:            ", U32.show(in_progress), "\n  Blocked:                ", U32.show(blocked), "\n  Closed:                 ", U32.show(closed), "\n  Ready to Work:          ", U32.show(ready), "\n", row_if("  Deferred:               ", deferred), row_if("  Tombstones:             ", tombstone), row_if("  Pinned:                 ", pinned), row_if("  Epics ready to close:   ", epics), extended(lead, tombstone), breaks, "\nFor more details, use 'br list' to see individual issues.\n"])

# S5.53 S5.54 (spec twin) `average_lead_time_hours`, when it exists
def lead_member(lead: String) -> String:
  match lead:
    case SNil{}:
      ""
    case SCon{h, t}:
      ",\"average_lead_time_hours\":" ++ SCon{h, t}

# S5.53 (spec twin) `stats --json`: eleven integers in this order, then the average lead time when it exists
def stats_json(f: Work.Figures, lead: String, breaks: String) -> String:
  match f:
    case Work.Figures{total, open, in_progress, closed, blocked, deferred, draft, ready, tombstone, pinned, epics, lead_sum, lead_count}:
      String.concat(["{\"summary\":{\"total_issues\":", U32.show(total), ",\"open_issues\":", U32.show(open), ",\"in_progress_issues\":", U32.show(in_progress), ",\"closed_issues\":", U32.show(closed), ",\"blocked_issues\":", U32.show(blocked), ",\"deferred_issues\":", U32.show(deferred), ",\"draft_issues\":", U32.show(draft), ",\"ready_issues\":", U32.show(ready), ",\"tombstone_issues\":", U32.show(tombstone), ",\"pinned_issues\":", U32.show(pinned), ",\"epics_eligible_for_closure\":", U32.show(epics), lead_member(lead), "}", breaks, "}\n"])
