# core/show — `show`: one or more issues in full (S1.55, S5.30, S5.31, S5.143–S5.155).
# `show` reads the file's records AS THEY ARE (Store.load, not Store.model:
# S2.38, S2.39), resolves each id left to right and stops at the first
# refusal, and prints each issue's header, metadata, bodies, dependencies,
# dependents and comments. Not here yet: the 100-column wrapping of bodies
# (S5.115), `Rollup:`, and the `Deferred until:` countdown when no pinned
# instant is given (the port has no clock effect yet). Nothing here consults
# the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./render.bend as Render
import ./resolve.bend as Resolve
import ./acceptance.bend as Acceptance

# S5.31 (data) a record on the other end of an edge: its id, title, status and priority, the edge's type, and
# when the record was created (the second sort key)
type Related is Data:
  Related{id: String, title: String, status: String, priority: String, kind: String, created: Time.Instant}

# S5.31 (spec twin) priority as a number; anything unreadable sorts last
def rank(digits: String) -> U32:
  Maybe.default(&2, U32, U32.read(digits), 255)

# S5.31 (spec twin) the order of both lists: priority ascending, then `created_at` descending, then id ascending
def related_le(x: Related, y: Related) -> Bool:
  match x y:
    case Related{xi, xt, xs, +xp, xk, +xc} Related{yi, yt, ys, +yp, yk, +yc}:
      ((rank(xp) < rank(yp) : U32) || (U32.is_eq(rank(xp), rank(yp)) && (Bool.not(Time.le(xc, yc)) || (Time.eq(xc, yc) && String.is_le(xi, yi)))))

# S5.31 (spec twin) the stored record with this id
def lookup(issues: List<&2, Model.Issue>, +id: String) -> Maybe<&2, Model.Issue>:
  match issues:
    case Nil{}:
      None{}
    case Con{+i, rest}:
      Bool.pick(Maybe<&2, Model.Issue>, String.eq(Model.id_of(i), id), Some{i}, lookup(rest, id))

# S5.31 (spec twin) an edge's other end as a Related; an end that is not stored contributes nothing
def related_put(found: Maybe<&2, Model.Issue>, kind: String, rest: List<&2, Related>) -> List<&2, Related>:
  match found:
    case None{}:
      rest
    case Some{+t}:
      Related{Model.id_of(t), Model.title_of(t), Model.status_of(t), Model.priority_of(t), kind, Model.created_of(t)} <> rest

# S5.31 (spec twin) the issue's own edges, each with the record it points at
def dependencies(edges: List<&2, Model.Dependency>, +all: List<&2, Model.Issue>) -> List<&2, Related>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      related_put(lookup(all, Model.target_of(e)), Model.dep_type_of(e), dependencies(rest, all))

# S5.31 (spec twin) keep the pointing record when the edge points at the issue
def pointing_put(from: Model.Issue, kind: String, hit: Bool, later: List<&2, Related>) -> List<&2, Related>:
  match hit:
    case True{}:
      related_put(Some{from}, kind, later)
    case False{}:
      later

# S5.31 (spec twin) the edges of one other record that point at `id`, each as that record
def pointing(edges: List<&2, Model.Dependency>, +from: Model.Issue, +id: String, rest: List<&2, Related>) -> List<&2, Related>:
  match edges:
    case Nil{}:
      rest
    case Con{+e, more}:
      pointing_put(from, Model.dep_type_of(e), String.eq(Model.target_of(e), id), pointing(more, from, id, rest))

# S5.31 (spec twin) every record of the store with an edge that points at `id`
def dependents(all: List<&2, Model.Issue>, +id: String) -> List<&2, Related>:
  match all:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      pointing(Model.deps_of(i), i, id, dependents(rest, id))

# S5.31 (spec twin) `parent`: the target of the LAST `parent-child` edge of the issue's own array; "" when there is none
def parent_of(edges: List<&2, Model.Dependency>, sofar: String) -> String:
  match edges:
    case Nil{}:
      sofar
    case Con{+e, rest}:
      parent_of(rest, Bool.pick(String, String.eq(Model.dep_type_of(e), "parent-child"), Model.target_of(e), sofar))

# ---------------------------------------------------------------- plain text (S5.143–S5.154)

# S5.112 (spec twin) route one code point of a body: tab and line feed stay; any other control character is made visible
def body_char(+c: U32, acc: String, keep: Bool, cr: Bool, ctl: Bool) -> String:
  match keep cr ctl:
    case True{} _ _:
      SCon{Chr{c}, acc}
    case False{} True{} _:
      SCon{Chr{92}, SCon{Chr{114}, acc}}
    case False{} False{} True{}:
      Render.escaped_hex(c, acc)
    case False{} False{} False{}:
      SCon{Chr{c}, acc}

# S5.112 (spec twin) a free-text body: `\n` and `\t` are preserved, every other control character is escaped
def body(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      body_char(c, body(rest), (U32.is_eq(c, 9) || U32.is_eq(c, 10)), U32.is_eq(c, 13), ((c < 32 : U32) || ((c >= 127 : U32) && (c <= 159 : U32))))

# S5.143 (spec twin) ASCII upper case of one code point
def upper_char(+c: U32, low: Bool) -> U32:
  match low:
    case True{}:
      (c - 32 : U32)
    case False{}:
      c

# S5.143 (spec twin) the status name in upper case: `IN_PROGRESS`
def shouted(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{upper_char(c, ((c >= 97 : U32) && (c <= 122 : U32)))}, shouted(rest)}

# S5.144 (spec twin) the owner line's value: the stored owner, else `USER`, else `unknown`
def owner_text(owner: Maybe<&2, String>, user: String) -> String:
  match owner user:
    case Some{SCon{h, t}} _:
      SCon{h, t}
    case _ SCon{h, t}:
      SCon{h, t}
    case _ SNil{}:
      "unknown"

# S5.146 (spec twin) a metadata line for a present, non-empty text
def meta_text(label: String, value: Maybe<&2, String>) -> String:
  match value:
    case Some{SCon{h, t}}:
      label ++ Render.inline(SCon{h, t}) ++ "\n"
    case other:
      ""

# S5.146 (spec twin) a metadata line for a present date
def meta_date(label: String, value: Maybe<&2, Time.Instant>, suffix: String) -> String:
  match value:
    case None{}:
      ""
    case Some{at}:
      label ++ Render.date(at) ++ suffix ++ "\n"

# S5.146 (spec twin) `Labels: a, b`, in the record's own order; nothing when there are none
def labels_line(labels: List<&2, String>) -> String:
  match labels:
    case Nil{}:
      ""
    case Con{l, rest}:
      "Labels: " ++ Render.inline(String.join(l <> rest, ", ")) ++ "\n"

# S5.149 (spec twin) `{h}h {m}m`, `{h}h` or `{m}m`; nothing for zero
def estimate_text(+h: U32, +m: U32) -> String:
  Bool.pick(String, (U32.is_eq(h, 0) && U32.is_eq(m, 0)), "", Bool.pick(String, U32.is_eq(m, 0), "Estimate: " ++ U32.show(h) ++ "h\n", Bool.pick(String, U32.is_eq(h, 0), "Estimate: " ++ U32.show(m) ++ "m\n", "Estimate: " ++ U32.show(h) ++ "h " ++ U32.show(m) ++ "m\n")))

# S5.149 (spec twin) minutes as hours and minutes
def estimate_minutes(+m: U32) -> String:
  estimate_text((m / 60 : U32), (m % 60 : U32))

# S5.149 (spec twin) the estimate line from the stored minutes
def estimate_line(minutes: Maybe<&2, String>) -> String:
  match minutes:
    case None{}:
      ""
    case Some{digits}:
      estimate_minutes(Maybe.default(&2, U32, U32.read(digits), 0))

# S5.147 (spec twin) `Closed: {date} ({reason})`; the literal `closed` stands in for a missing reason
def closed_line(at: Maybe<&2, Time.Instant>, reason: Maybe<&2, String>) -> String:
  match at reason:
    case None{} _:
      ""
    case Some{when} Some{SCon{h, t}}:
      "Closed: " ++ Render.date(when) ++ " (" ++ Render.inline(SCon{h, t}) ++ ")\n"
    case Some{when} other:
      "Closed: " ++ Render.date(when) ++ " (closed)\n"

# S5.150 (spec twin) a body section: one blank line, the heading line when it has one, the body
def section(heading: String, value: Maybe<&2, String>) -> String:
  match value:
    case Some{SCon{h, t}}:
      "\n" ++ heading ++ body(SCon{h, t}) ++ "\n"
    case other:
      ""

# S5.151 S5.152 (spec twin) one edge line: two spaces, the arrow, `{id} ({type}) - {title}`
def edge_lines(items: List<&2, Related>, +arrow: String) -> List<&2, String>:
  match items:
    case Nil{}:
      Nil{}
    case Con{Related{id, title, status, priority, kind, created}, rest}:
      String.concat(["  ", arrow, " ", Render.inline(id), " (", Render.inline(kind), ") - ", Render.inline(title), "\n"]) <> edge_lines(rest, arrow)

# S5.151 S5.152 (spec twin) an edge section: nothing when empty; else a blank line, the heading, the lines
def edge_section(heading: String, items: List<&2, Related>, arrow: String) -> String:
  match items:
    case Nil{}:
      ""
    case Con{r, rest}:
      "\n" ++ heading ++ "\n" ++ String.concat(edge_lines(r <> rest, arrow))

# S5.113 (spec twin) `2026-01-01T12:30:00Z` as `2026-01-01 12:30 UTC`: the date, a space, hours and minutes, the suffix
def minute_of(+full: String) -> String:
  String.take(full, 10n) ++ " " ++ String.take(String.drop(full, 11n), 5n) ++ " UTC"

# S5.113 S5.153 (spec twin) a comment's instant as `%Y-%m-%d %H:%M UTC`
def minute_text(at: Time.Instant) -> String:
  minute_of(Time.print(at, "Z"))

# S5.153 (spec twin) one comment line: `  [{when}] {author}: {body}`
def comment_lines(items: List<&2, Model.Comment>) -> List<&2, String>:
  match items:
    case Nil{}:
      Nil{}
    case Con{Model.Comment{id, issue_id, author, text, created_at}, rest}:
      String.concat(["  [", minute_text(created_at), "] ", Render.inline(author), ": ", body(text), "\n"]) <> comment_lines(rest)

# S5.153 (spec twin) the comments section: nothing when empty
def comment_section(items: List<&2, Model.Comment>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{c, rest}:
      "\nComments:\n" ++ String.concat(comment_lines(c <> rest))

# S4.113 DISC-001 (spec twin) the instant from its epoch seconds and nanoseconds; none when either is missing or
# not a number. Day 719468 of the instant calendar (days since 0000-03-01) is 1970-01-01
def pinned_pick(secs: Maybe<&2, U32>, nanos: Maybe<&2, U32>) -> Maybe<&2, Time.Instant>:
  match secs nanos:
    case Some{+s} Some{n}:
      Some{Time.Instant{((s / 86400 : U32) + 719468 : U32), (s % 86400 : U32), n}}
    case _ _:
      None{}

# S4.113 DISC-001 (spec twin) one to nine fraction digits as nanoseconds, padded on the right; more, or none, is refused
def nanos_of(+frac: String) -> Maybe<&2, U32>:
  Bool.pick(Maybe<&2, U32>, (Nat.is_lt(String.length(frac), 10n) && Bool.not(String.is_empty(frac))), U32.read(frac ++ String.repeat("0", Nat.sub(9n, String.length(frac)))), None{})

# S4.113 DISC-001 (spec twin) `<seconds>` or `<seconds>.<fraction>`, split at the point
def pinned_parts(parts: List<&2, String>) -> Maybe<&2, Time.Instant>:
  match parts:
    case Con{s, Nil{}}:
      pinned_pick(U32.read(s), Some{0})
    case Con{s, Con{f, Nil{}}}:
      pinned_pick(U32.read(s), nanos_of(f))
    case _:
      None{}

# S4.113 DISC-001 (spec twin) the instant of `BEADS_BEND_NOW` (epoch seconds, optionally with a fraction), or of
# the shell's wall-clock reading `<seconds>.<nine digits>` when the variable is unset
def pinned(digits: String) -> Maybe<&2, Time.Instant>:
  pinned_parts(String.split(digits, Chr{46}))

# S5.148 (spec twin) the words of the countdown for a gate that is still ahead: under a day; an exact number of days; over a number of days
def countdown_words(+days: U32, under: Bool, exact: Bool) -> String:
  match under exact:
    case True{} _:
      " (gate opens in under a day)"
    case False{} True{}:
      Bool.pick(String, U32.is_eq(days, 1), " (gate opens in 1 day)", " (gate opens in " ++ U32.show(days) ++ " days)")
    case False{} False{}:
      Bool.pick(String, U32.is_eq(days, 1), " (gate opens in over 1 day)", " (gate opens in over " ++ U32.show(days) ++ " days)")

# S5.148 (spec twin) the countdown from the seconds that remain
def countdown_secs(+left: U32) -> String:
  countdown_words((left / 86400 : U32), (left < 86400 : U32), U32.is_eq((left % 86400 : U32), 0))

# S5.148 (spec twin) the suffix of `Deferred until:`: empty once the gate has passed, and empty while the port has
# no instant to compare with
def countdown(until: Maybe<&2, Time.Instant>, now: Maybe<&2, Time.Instant>) -> String:
  match until now:
    case Some{Time.Instant{+ud, +us, un}} Some{Time.Instant{+nd, +ns, nn}}:
      Bool.pick(String, Time.le(Time.Instant{ud, us, 0}, Time.Instant{nd, ns, 0}), "", countdown_secs(((((ud - nd : U32) * 86400 : U32) + us : U32) - ns : U32)))
    case _ _:
      ""

# S5.143–S5.153 (spec twin) one issue in plain text: the header, the owner line, the dates, the optional metadata
# in S5.146's order, the bodies, the edges, the comments
def plain_one(+i: Model.Issue, +all: List<&2, Model.Issue>, user: String, now: Maybe<&2, Time.Instant>) -> String:
  String.concat([Render.icon(Model.status_of(i)), " ", Render.inline(Model.id_of(i)), " · ", Render.inline(Model.title_of(i)), "   [● P", Model.priority_of(i), " · ", shouted(Render.inline(Model.status_of(i))), "]\nOwner: ", Render.inline(owner_text(Model.owner_of(i), user)), " · Type: ", Render.inline(Model.type_of(i)), "\nCreated: ", Render.date(Model.created_of(i)), " · Updated: ", Render.date(Model.updated_of(i)), "\n", meta_text("Assignee: ", Model.assignee_of(i)), labels_line(Model.labels_of(i)), meta_text("Ref: ", Model.external_ref_of(i)), meta_date("Due: ", Model.due_of(i), ""), meta_date("Deferred until: ", Model.defer_of(i), countdown(Model.defer_of(i), now)), estimate_line(Model.estimate_of(i)), closed_line(Model.closed_of(i), Model.close_reason_of(i)), section("", Model.description_of(i)), section("Design:\n", Model.design_of(i)), section("Prerequisites:\n", Model.prerequisites_of(i)), section("Acceptance Criteria:\n", Model.acceptance_of(i)), section("Notes:\n", Model.notes_of(i)), edge_section("Dependencies:", List.sort(~Related, ~related_le, dependencies(Model.deps_of(i), all)), "->"), edge_section("Dependents:", List.sort(~Related, ~related_le, dependents(all, Model.id_of(i))), "<-"), comment_section(Model.comments_of(i))])

# ---------------------------------------------------------------- JSON (S5.30, S5.31)

# S5.31 (spec twin) the five members of one related record, each object preceded by `,` except the first
def related_objects(items: List<&2, Related>, first: Bool) -> List<&2, String>:
  match items first:
    case Nil{} _:
      Nil{}
    case Con{Related{id, title, status, priority, kind, created}, rest} lead:
      String.concat([Bool.pick(String, lead, "", ","), "{\"id\":", Failure.quoted(id), ",\"title\":", Failure.quoted(title), ",\"status\":", Failure.quoted(status), ",\"priority\":", priority, ",\"dependency_type\":", Failure.quoted(kind), "}"]) <> related_objects(rest, False{})

# S5.30 (spec twin) a member that is an array of related records; omitted when empty
def related_member(name: String, items: List<&2, Related>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{r, rest}:
      ",\"" ++ name ++ "\":[" ++ String.concat(related_objects(r <> rest, True{})) ++ "]"

# S5.30 (spec twin) a member that is present only when its text is not empty, preceded by `,`
def after_comma(text: String) -> String:
  match text:
    case SNil{}:
      ""
    case SCon{h, t}:
      SCon{Chr{44}, SCon{h, t}}

# S5.30 (spec twin) `parent`, when there is one
def parent_member(id: String) -> String:
  match id:
    case SNil{}:
      ""
    case SCon{h, t}:
      ",\"parent\":" ++ Failure.quoted(SCon{h, t})

# S5.30 S4.398 (spec twin) one element of `show --json`: the record's own members as the file spells them (labels kept,
# its own edge and comment arrays left out), then `dependencies`, `dependents`, `comments`, `parent`, each omitted when
# empty, and last `acceptance_items` when the criteria hold a checklist item
def json_one(+i: Model.Issue, +all: List<&2, Model.Issue>) -> String:
  String.concat(["{", Model.members_raw(Model.without_edges(i)), related_member("dependencies", List.sort(~Related, ~related_le, dependencies(Model.deps_of(i), all))), related_member("dependents", List.sort(~Related, ~related_le, dependents(all, Model.id_of(i)))), after_comma(Model.o_comments(Model.comments_of(i))), parent_member(parent_of(Model.deps_of(i), "")), Acceptance.items_member(Model.acceptance_of(i)), "}"])

# ---------------------------------------------------------------- the command

# S1.55 S4.48 (data) what `show` answers: the text for stdout, or the refusal that ended the run
type Shown is Data:
  ShowBad{failure: Failure.Failure}
  ShowOk{out: String}

# S9 (spec twin) `show` with no id and no last-touched issue
def no_ids() -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: ids: no issue IDs provided and no last-touched issue", None{}, True{}, [Failure.CtxMember{"field", Failure.CStr{"ids"}}, Failure.CtxMember{"reason", Failure.CStr{"no issue IDs provided and no last-touched issue"}}], 4}

# S3.1 (spec twin) every stored id, in file order
def ids_of(issues: List<&2, Model.Issue>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{i, rest}:
      Model.id_of(i) <> ids_of(rest)

# S5.30 S5.154 (spec twin) one resolved issue rendered: plain blocks are separated by ONE blank line, JSON elements by `,`
def shown_one(found: Maybe<&2, Model.Issue>, +all: List<&2, Model.Issue>, user: String, now: Maybe<&2, Time.Instant>, json: Bool, first: Bool) -> String:
  match found json:
    case None{} _:
      ""
    case Some{i} True{}:
      Bool.pick(String, first, "", ",") ++ json_one(i, all)
    case Some{i} False{}:
      Bool.pick(String, first, "", "\n") ++ plain_one(i, all, user, now)

# S4.48 (data) the run so far: the first refusal (sticky), or the rendered issues (REVERSED) and whether none was rendered yet
type Acc is Data:
  AccBad{failure: Failure.Failure}
  AccOk{done: List<&2, String>, first: Bool}

# S4.48 (spec twin) fold one resolved id in: the FIRST refusal ends the run
def show_step(acc: Acc, found: Resolve.Found, +all: List<&2, Model.Issue>, user: String, now: Maybe<&2, Time.Instant>, json: Bool) -> Acc:
  match acc found:
    case AccBad{f} _:
      AccBad{f}
    case AccOk{done, first} Resolve.FoundBad{f}:
      AccBad{f}
    case AccOk{done, first} Resolve.FoundOk{id}:
      AccOk{shown_one(lookup(all, id), all, user, now, json, first) <> done, False{}}

# S4.48 S5.154 (spec twin) the ids left to right
def show_go(inputs: List<&2, String>, +all: List<&2, Model.Issue>, +user: String, +now: Maybe<&2, Time.Instant>, +prefix: String, +json: Bool, acc: Acc) -> Acc:
  match inputs:
    case Nil{}:
      acc
    case Con{input, rest}:
      show_go(rest, all, user, now, prefix, json, show_step(acc, Resolve.resolve(ids_of(all), input, prefix), all, user, now, json))

# S5.20 S5.30 S5.155 (spec twin) a refusal prints nothing of the issues; JSON is one array and one newline
def show_done(acc: Acc, json: Bool) -> Shown:
  match acc json:
    case AccBad{f} _:
      ShowBad{f}
    case AccOk{done, first} True{}:
      ShowOk{"[" ++ String.concat(List.reverse(&2, String, done)) ++ "]\n"}
    case AccOk{done, first} False{}:
      ShowOk{String.concat(List.reverse(&2, String, done))}

# S1.55 (spec twin) the ids to show: the positionals, or, when there are none, the one id in `.beads/last-touched`
def wanted(words: List<&2, String>, touched: String) -> List<&2, String>:
  match words touched:
    case Con{w, rest} _:
      w <> rest
    case Nil{} SCon{h, t}:
      SCon{h, t} <> Nil{}
    case Nil{} SNil{}:
      Nil{}

# S1.55 S9 (spec twin) no id at all is refused before anything is resolved
def show_ids(ids: List<&2, String>, +all: List<&2, Model.Issue>, user: String, now: Maybe<&2, Time.Instant>, prefix: String, +json: Bool) -> Shown:
  match ids:
    case Nil{}:
      ShowBad{no_ids()}
    case Con{id, rest}:
      show_done(show_go(id <> rest, all, user, now, prefix, json, AccOk{Nil{}, True{}}), json)

# S1.55 S5.30 S5.143–S5.155 (spec twin) `show`: `all` is the file's records as they are; `touched` is the trimmed text of
# `.beads/last-touched`; `user` is `USER`; `now_digits` is the pinned instant's epoch seconds ("" when there is none)
def run(words: List<&2, String>, all: List<&2, Model.Issue>, touched: String, user: String, now_digits: String, prefix: String, json: Bool) -> Shown:
  show_ids(wanted(words, touched), all, user, pinned(now_digits), prefix, json)

