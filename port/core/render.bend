# core/render — what `list` and `count` print (S5.20, S5.32, S5.33, S5.52, S5.110–S5.125, S5.161–S5.166).
# Plain text and compact JSON, both as one String ended by its newline. Every
# untrusted one-line field passes the inline sanitizer of S5.112. Pieces are
# collected in lists and concatenated once. Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./query.bend as Query

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

# S5.120–S5.122 (spec twin) the plain listing; an empty result prints nothing at all (S5.121)
def list_plain(issues: List<&2, Model.Issue>, long: Bool) -> String:
  match long:
    case True{}:
      String.concat(blocks(issues))
    case False{}:
      String.concat(lines(issues))

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
# number of rows shown and the query between single quotes, the rows, then the notes
def search_plain(+page: List<&2, Model.Issue>, query: String, +more: Bool, offset: Nat, limit: Nat, hidden: Nat) -> String:
  String.concat([Bool.pick(String, more, "Showing ", "Found "), Nat.show(List.length(&2, Model.Issue, page)), " issue(s) matching '", inline(query), "'\n", String.concat(lines(page)), more_note(more, List.length(&2, Model.Issue, page), offset, limit), hidden_note(hidden)])

# S5.34 (spec twin) the envelope of `search --json`: no `total`, and `hidden_closed_count` in its place
def search_json(page: List<&2, Model.Issue>, all: List<&2, Model.Issue>, hidden: Nat, limit: Nat, offset: Nat, more: Bool) -> String:
  String.concat(["{\"issues\":[", String.concat(elements(page, all, True{})), "],\"hidden_closed_count\":", Nat.show(hidden), ",\"limit\":", Nat.show(limit), ",\"offset\":", Nat.show(offset), ",\"has_more\":", Failure.bool_text(more), "}\n"])
