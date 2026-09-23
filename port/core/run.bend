# core/run — the pure program: Inputs -> Outcome (docs/PROPOSED_ARCHITECTURE.md).
# The shell gathers the inputs with one effect each, calls `outcome` once and
# performs what it answers. Nothing here mentions IO or consults the original.
import Base
import ./failure.bend as Failure
import ./bytes.bend as Bytes
import ./store.bend as Store
import ./cli.bend as Cli
import ./help.bend as Help
import ./model.bend as Model
import ./query.bend as Query
import ./render.bend as Render
import ./resolve.bend as Resolve
import ./show.bend as Show
import ./work.bend as Work
import ./views.bend as Views
import ./time.bend as Time
import ./create.bend as Create
import ./update.bend as Update
import ./status.bend as Status
import ./when.bend as When
import ./blocked.bend as Blocked
import ./edges.bend as Edges
import ./labels.bend as Labels
import ./remove.bend as Remove
import ./prefix.bend as Prefix

# S8.5 (data) one environment variable as the shell read it: its name and its value ("" when it is not set)
type Var is Data:
  Var{name: String, value: String}

# S8.1 S8.12 S8.13 (data) what the shell gathered: argv, whether a `.beads` workspace was found, the
# working directory, and the BYTES of `.beads/issues.jsonl` (empty when there is no workspace)
type Inputs is Data:
  Inputs{argv: List<&2, String>, workspace: Bool, cwd: String, store: List<&2, U32>, touched: List<&2, U32>, env: List<&2, Var>}

# S8.13 (data) `touched` above is the BYTES of `.beads/last-touched` (empty when the file is absent, S1.55);
# `env` is one Var per name of `env_names`, in that order

# S1.57–S1.67 S8.5 (data) the environment variables the core reads, in the order the shell reads them:
# the actor ladders (S1.64, S1.65), the output format (S1.61), the pinned instant of DISC-001, and the workspace
# override of S2.4
def env_names() -> List<&2, String>:
  ["USER", "BD_ACTOR", "BEADS_ACTOR", "LOGNAME", "USERNAME", "BR_OUTPUT_FORMAT", "TOON_DEFAULT_FORMAT", "BEADS_BEND_NOW", "BEADS_DIR", "BEADS_RUST_SPEC"]

# S8.5 (spec twin) the value of a variable; one that is not set, or was not read, is the empty string
def env_of(env: List<&2, Var>, +name: String) -> String:
  match env:
    case Nil{}:
      ""
    case Con{Var{n, v}, rest}:
      Bool.pick(String, String.eq(n, name), v, env_of(rest, name))

# S4.190 (spec twin) the kill-switch of the fast twins: `BEADS_RUST_SPEC=1` runs every spec twin instead
def spec_of(+env: List<&2, Var>) -> Bool:
  String.eq(env_of(env, "BEADS_RUST_SPEC"), "1")

# S4.113 DISC-001 DISC-009 (spec twin) the instant a command runs at, as text: `BEADS_BEND_NOW` when it is set (the
# one test seam), otherwise the wall-clock reading the shell passes as `BEADS_BEND_WALL`. The core never reads a
# clock; it only chooses between two values it was given
def now_of(+env: List<&2, Var>) -> String:
  Bool.pick(String, String.is_empty(env_of(env, "BEADS_BEND_NOW")), env_of(env, "BEADS_BEND_WALL"), env_of(env, "BEADS_BEND_NOW"))

# S5.1 S5.17 S8.30 (data) one file the shell must change, by its path relative to the workspace: the whole new
# text of the file, or no text at all, which means "remove the file" (`delete` and `.beads/last-touched`, S4.210)
type Write is Data:
  Write{path: String, text: Maybe<&2, String>}

# S8.30 S8.34 S8.36 (data) what the shell must do, in this order: change the files (the store before the sidecar,
# S5.18), write the bytes for stdout, write the bytes for stderr, leave with the exit code
type Outcome is Data:
  Outcome{out: String, err: String, code: U32, writes: List<&2, Write>}

# S9.1 S9.2 (spec twin) a failure as an outcome: JSON mode writes the envelope to
# STDOUT and nothing to stderr; plain mode writes `Error:` / `Hint:` to STDERR
def failed(+f: Failure.Failure, json: Bool) -> Outcome:
  match json:
    case True{}:
      Outcome{Failure.json_text(f), "", Failure.exit_of(f), Nil{}}
    case False{}:
      Outcome{"", Failure.plain_text(f), Failure.exit_of(f), Nil{}}

# S9.6 (spec twin) a surface of the contract the port does not implement yet. Exit 1 is the
# contract's internal-error code; the message is the port's own, so every such case FAILS
# its golden, which is the truthful state of an unported command.
def unported() -> Failure.Failure:
  Failure.Failure{"INTERNAL_ERROR", "beads_bend: this command is not ported yet", None{}, False{}, Nil{}, 1}

# S2.24 S9 (spec twin) a file that is not UTF-8 refuses the load. The original's exact words for this
# refusal are not captured yet (OQ register): the code and exit follow the other load refusals.
def not_utf8() -> Failure.Failure:
  Failure.Failure{"CONFIG_ERROR", "Configuration error: .beads/issues.jsonl is not valid UTF-8", None{}, False{}, Nil{}, 7}

# S1.1 S1.6 (data) an accepted command line: the words that name the command, its option occurrences in argv
# order, its positionals, and the output mode (JSON beats Quiet, S1.6)
type Call is Data:
  Call{path: String, opts: List<&2, Cli.Occ>, words: List<&2, String>, json: Bool, quiet: Bool, touched: List<&2, U32>, env: List<&2, Var>, cwd: String}

# S1.6 (spec twin) the output mode of a call: is it JSON
def wants_json(c: Call) -> Bool:
  match c:
    case Call{path, opts, words, json, quiet, touched, env, cwd}:
      json

# S5.23 S5.106 (spec twin) what a successful read prints: nothing at all under Quiet
def printed(out: String, note: String, quiet: Bool) -> Outcome:
  match quiet:
    case True{}:
      Outcome{"", "", 0, Nil{}}
    case False{}:
      Outcome{out, note, 0, Nil{}}

# S4.133 S5.124 (spec twin) did a filter that runs outside the query take part: only then does the truncation note know the total
def outside_query(+opts: List<&2, Cli.Occ>) -> Bool:
  (Cli.given(opts, "id") || Cli.given(opts, "priority-min") || Cli.given(opts, "priority-max") || Cli.given(opts, "desc-contains") || Cli.given(opts, "notes-contains") || Cli.given(opts, "deferred") || Cli.given(opts, "overdue"))

# S4.114 S4.119 S4.120 S5.32 S5.120–S5.125 (spec twin) `list` once its rows are ordered: cut the page, then print it
# as JSON (the envelope), or as plain lines with the truncation note on stderr
def list_page(+rows: List<&2, Model.Issue>, +all: List<&2, Model.Issue>, +opts: List<&2, Cli.Occ>, +limit: Nat, +offset: Nat, json: Bool, quiet: Bool) -> Outcome:
  match json:
    case True{}:
      printed(Render.list_json(Query.page(rows, offset, limit), all, List.length(&2, Model.Issue, rows), limit, offset, Query.has_more(List.length(&2, Model.Issue, rows), offset, limit)), "", quiet)
    case False{}:
      printed(Render.list_plain(Query.page(rows, offset, limit), Cli.given(opts, "long"), Cli.given(opts, "pretty"), Cli.given(opts, "tree")), Render.truncation_note(Query.has_more(List.length(&2, Model.Issue, rows), offset, limit), outside_query(opts), List.length(&2, Model.Issue, Query.page(rows, offset, limit)), List.length(&2, Model.Issue, rows)), quiet)

# S4.118 (spec twin) `list` once its filter is built: the sort key is judged next (9 is a key nobody knows)
def list_sorted(+key: U32, f: Query.Filter, +opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, json: Bool, quiet: Bool, bad: Bool, now: Maybe<&2, Time.Instant>) -> Outcome:
  match bad:
    case True{}:
      failed(Query.bad_sort(Maybe.default(&2, String, Cli.value(opts, "sort"), "")), json)
    case False{}:
      list_page(Query.ordered(Work.overdue_only(Cli.given(opts, "overdue"), now, Query.kept(issues, f)), key, Cli.given(opts, "reverse")), issues, opts, Query.count_of(Cli.value(opts, "limit")), Query.count_of(Cli.value(opts, "offset")), json, quiet)

# S4.105 S4.107 S4.108 (spec twin) `list` once its options were judged
def list_built(b: Query.Built, +opts: List<&2, Cli.Occ>, issues: List<&2, Model.Issue>, json: Bool, quiet: Bool, now: Maybe<&2, Time.Instant>) -> Outcome:
  match b:
    case Query.BuildBad{f}:
      failed(f, json)
    case Query.BuildOk{f}:
      list_sorted(Query.sort_key(Cli.value(opts, "sort")), f, opts, issues, json, quiet, U32.is_eq(Query.sort_key(Cli.value(opts, "sort")), 9), now)

# S4.147 (spec twin) the grouping selectors that were given, in the fixed order of the refusal
def selectors(+opts: List<&2, Cli.Occ>) -> List<&2, String>:
  List.concat(&2, String, [Bool.pick(List<&2, String>, Cli.given(opts, "by"), ["--by"], []), Bool.pick(List<&2, String>, Cli.given(opts, "by-status"), ["--by-status"], []), Bool.pick(List<&2, String>, Cli.given(opts, "by-priority"), ["--by-priority"], []), Bool.pick(List<&2, String>, Cli.given(opts, "by-type"), ["--by-type"], []), Bool.pick(List<&2, String>, Cli.given(opts, "by-assignee"), ["--by-assignee"], []), Bool.pick(List<&2, String>, Cli.given(opts, "by-label"), ["--by-label"], [])])

# S4.147 (spec twin) the refusal of more than one grouping selector
def many_selectors(given: List<&2, String>) -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: by: only one count grouping selector can be specified; got " ++ String.join(given, ", "), None{}, True{}, Nil{}, 4}

# S4.147 S4.148 (spec twin) the field from `--by <field>` or from the alias flag; label when nothing else says
def group_field_pick(+by: String, status: Bool, priority: Bool, kind: Bool, assignee: Bool) -> U32:
  match status priority kind assignee:
    case True{} _ _ _:
      0
    case False{} True{} _ _:
      1
    case False{} False{} True{} _:
      2
    case False{} False{} False{} True{}:
      3
    case False{} False{} False{} False{}:
      Bool.pick(U32, String.eq(by, "status"), 0, Bool.pick(U32, String.eq(by, "priority"), 1, Bool.pick(U32, String.eq(by, "type"), 2, Bool.pick(U32, String.eq(by, "assignee"), 3, 4))))

# S4.147 S4.148 (spec twin) the field a count groups by: 0 status, 1 priority, 2 type, 3 assignee, 4 label
def group_field(+opts: List<&2, Cli.Occ>) -> U32:
  group_field_pick(Maybe.default(&2, String, Cli.value(opts, "by"), ""), Cli.given(opts, "by-status"), Cli.given(opts, "by-priority"), Cli.given(opts, "by-type"), Cli.given(opts, "by-assignee"))

# S4.150 S5.52 S5.161 S5.162 (spec twin) `count` once its issues are chosen: the total is the number of issues,
# whatever the groups add up to
def count_kept(+rows: List<&2, Model.Issue>, by: U32, by_group: Bool, json: Bool, quiet: Bool) -> Outcome:
  printed(Render.count_text(List.length(&2, Model.Issue, rows), Query.grouped(rows, by, Nil{}), by_group, json), "", quiet)

# S4.144–S4.150 S5.52 S5.161–S5.166 (spec twin) `count` once its filter is built
def count_built(b: Query.Built, +opts: List<&2, Cli.Occ>, issues: List<&2, Model.Issue>, json: Bool, quiet: Bool) -> Outcome:
  match b:
    case Query.BuildBad{f}:
      failed(f, json)
    case Query.BuildOk{f}:
      count_kept(Query.kept(issues, f), group_field(opts), Bool.not(List.is_empty(&2, String, selectors(opts))), json, quiet)

# S4.147 (spec twin) `count`: more than one grouping selector is refused before anything else
def count_cmd(+opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, json: Bool, quiet: Bool, many: Bool) -> Outcome:
  match many:
    case True{}:
      failed(many_selectors(selectors(opts)), json)
    case False{}:
      count_built(Query.build(opts, issues, False{}, True{}), opts, issues, json, quiet)

# S4.132 S5.127 S5.128 (spec twin) `list`; `--overdue` also hides deferred records unless a status, `--deferred` or
# `--all` asks for them (S4.132); `later` refuses a form the port does not carry (the dispatcher passes none today)
def list_cmd(+opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, json: Bool, quiet: Bool, later: Bool, now: Maybe<&2, Time.Instant>) -> Outcome:
  match later:
    case True{}:
      failed(unported(), json)
    case False{}:
      list_built(Query.build(opts, issues, Bool.not(Cli.given(opts, "overdue")), False{}), opts, issues, json, quiet, now)

# S4.141 S4.142 S5.34 S5.156–S5.159 (spec twin) `search` once its rows are ordered: the page, the `has_more` verdict,
# the hidden closed matches, as JSON or as plain text
def search_page(+rows: List<&2, Model.Issue>, +all: List<&2, Model.Issue>, query: String, +hidden: Nat, +limit: Nat, +offset: Nat, json: Bool, quiet: Bool) -> Outcome:
  match json:
    case True{}:
      printed(Render.search_json(Query.page(rows, offset, limit), all, hidden, limit, offset, Query.has_more(List.length(&2, Model.Issue, rows), offset, limit)), "", quiet)
    case False{}:
      printed(Render.search_plain(Query.page(rows, offset, limit), query, Query.has_more(List.length(&2, Model.Issue, rows), offset, limit), offset, limit, hidden), "", quiet)

# S4.139 S4.140 (spec twin) `search` once its filter is built: the matches of the kept records, ordered as `list` orders
def search_built(b: Query.Built, +opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, +query: String, json: Bool, quiet: Bool) -> Outcome:
  match b:
    case Query.BuildBad{f}:
      failed(f, json)
    case Query.BuildOk{+f}:
      search_page(Query.ordered(Query.matching(Query.kept(issues, f), Query.folded(query)), Query.sort_key(Cli.value(opts, "sort")), Cli.given(opts, "reverse")), issues, query, Query.hidden_closed(issues, f, Query.folded(query)), Query.search_limit(Cli.value(opts, "limit")), Query.count_of(Cli.value(opts, "offset")), json, quiet)

# S4.118 S4.143 (spec twin) `search`: an empty query is refused, then an unknown sort key, then the filter is built
def search_cmd(+opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, +query: String, json: Bool, quiet: Bool, empty: Bool, bad_sort: Bool) -> Outcome:
  match empty bad_sort:
    case True{} _:
      failed(Query.empty_query(), json)
    case False{} True{}:
      failed(Query.bad_sort(Maybe.default(&2, String, Cli.value(opts, "sort"), "")), json)
    case False{} False{}:
      search_built(Query.build(opts, issues, True{}, False{}), opts, issues, query, json, quiet)

# S4.119 (spec twin) at most `limit` rows of any list; 0 keeps them all
def limited_rows(+rows: List<&2, Work.Row>, +limit: Nat) -> List<&2, Work.Row>:
  Bool.pick(List<&2, Work.Row>, Nat.is_eq(limit, 0n), rows, List.take(&2, Work.Row, rows, limit))

# S4.170 S5.35 S5.137–S5.142 S5.254 (spec twin) `blocked` once its rows are ordered: the total is counted before
# the limit; `--detailed` changes the plain rows only, never the JSON
def blocked_page(+rows: List<&2, Work.Row>, +limit: Nat, json: Bool, quiet: Bool, detailed: Bool, all: List<&2, Model.Issue>) -> Outcome:
  match json:
    case True{}:
      printed(Render.blocked_json(limited_rows(rows, limit), List.length(&2, Work.Row, rows), limit, Nat.is_lt(List.length(&2, Work.Row, limited_rows(rows, limit)), List.length(&2, Work.Row, rows))), "", quiet)
    case False{}:
      printed(Render.blocked_plain(limited_rows(rows, limit), List.length(&2, Work.Row, rows), detailed, all), Render.blocked_note(List.length(&2, Work.Row, limited_rows(rows, limit)), List.length(&2, Work.Row, rows)), quiet)

# S4.107 S4.168 (spec twin) `blocked` once its priorities were judged; its limit is 50 unless told otherwise
def blocked_picked(p: Query.Picked, +opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, json: Bool, quiet: Bool, detailed: Bool) -> Outcome:
  match p:
    case Query.PickBad{f}:
      failed(f, json)
    case Query.PickOk{values}:
      blocked_page(Work.blocked_rows(issues, Query.folded_all(Cli.values(opts, "type")), values, Cli.values(opts, "label")), Query.search_limit(Cli.value(opts, "limit")), json, quiet, detailed, issues)

# S4.167–S4.170 S5.254 (spec twin) `blocked`, plain, `--detailed` or JSON
def blocked_cmd(+opts: List<&2, Cli.Occ>, issues: List<&2, Model.Issue>, json: Bool, quiet: Bool, detailed: Bool) -> Outcome:
  blocked_picked(Query.pick_go(Query.comma_split(Cli.values(opts, "priority")), Query.PickOk{Nil{}}), opts, issues, json, quiet, detailed)

# S4.177 S5.36 S5.130–S5.134 (spec twin) `ready` once its issues are ordered: the header counts the rows SHOWN, the note the rows found
def ready_page(+found: List<&2, Model.Issue>, +limit: Nat, any_active: Bool, filtered: Bool, json: Bool, quiet: Bool) -> Outcome:
  match json:
    case True{}:
      printed(Render.ready_json(Query.page(found, 0n, limit)), "", quiet)
    case False{}:
      printed(Render.ready_plain(Query.page(found, 0n, limit), any_active, filtered), Render.ready_note(List.length(&2, Model.Issue, Query.page(found, 0n, limit)), List.length(&2, Model.Issue, found)), quiet)

# S1.49 S1.64 (spec twin) `--assignee` without a value means the current actor: `--actor`, else `USER` (the
# configuration file's `actor` is not read yet, backlog E3.3)
def ready_assignee(given: Maybe<&2, String>, actor: String) -> Maybe<&2, String>:
  match given:
    case None{}:
      None{}
    case Some{SNil{}}:
      Some{actor}
    case Some{SCon{h, t}}:
      Some{SCon{h, t}}

# S1.64 (spec twin) the first of the two that is not blank, else `unknown`
def actor_pick(flag: String, user: String) -> String:
  match flag user:
    case SCon{h, t} _:
      SCon{h, t}
    case SNil{} SCon{h, t}:
      SCon{h, t}
    case SNil{} SNil{}:
      "unknown"

# S1.64 (spec twin) the acting actor: `--actor` when it is not blank, else `USER` trimmed, else `unknown`
def actor_of(flag: Maybe<&2, String>, user: String) -> String:
  actor_pick(String.trim(Maybe.default(&2, String, flag, "")), String.trim(user))

# S4.171–S4.178 (spec twin) `ready` once its priorities were judged; `scope` is the membership set of `--parent`
# or `--epic`, none without them. `--epic` is `--parent` for the empty-result wording (S4.178)
def ready_picked(p: Query.Picked, +opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, +env: List<&2, Var>, json: Bool, quiet: Bool, scope: Maybe<&2, List<&2, String>>) -> Outcome:
  match p:
    case Query.PickBad{f}:
      failed(f, json)
    case Query.PickOk{values}:
      ready_page(Work.scoped(scope, Work.ready_issues(issues, Show.pinned(now_of(env)), Cli.given(opts, "include-deferred"), ready_assignee(Cli.value(opts, "assignee"), actor_of(Cli.value(opts, "actor"), env_of(env, "USER"))), Cli.given(opts, "unassigned"), Cli.values(opts, "label"), Cli.values(opts, "label-any"), Query.folded_all(Cli.values(opts, "type")), values, Work.policy_of(Cli.value(opts, "sort")))), Query.count_of(Cli.value(opts, "limit")), Work.any_active(issues), (Cli.given(opts, "assignee") || Cli.given(opts, "unassigned") || Cli.given(opts, "label") || Cli.given(opts, "label-any") || Cli.given(opts, "type") || Cli.given(opts, "priority") || Cli.given(opts, "parent") || Cli.given(opts, "epic")), json, quiet)

# S4.173 (spec twin) the id `--parent` or `--epic` names (the parser refuses the two together, S1.49)
def parent_named(parent: Maybe<&2, String>, epic: Maybe<&2, String>) -> Maybe<&2, String>:
  match parent epic:
    case Some{w} _:
      Some{w}
    case None{} e:
      e

# S4.173 (spec twin) `ready` once the parent it is scoped to was resolved: an unknown parent is refused
def ready_rooted(h: Views.Hit, +opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, +env: List<&2, Var>, json: Bool, quiet: Bool, recursive: Bool) -> Outcome:
  match h:
    case Views.HitBad{f}:
      failed(f, json)
    case Views.HitOk{i}:
      ready_picked(Query.pick_go(Query.comma_split(Cli.values(opts, "priority")), Query.PickOk{Nil{}}), opts, issues, env, json, quiet, Some{Work.members(issues, Model.id_of(i), recursive)})

# S4.173 (spec twin) `ready`, scoped or not: `--epic <id>` is `--parent <id> --recursive`
def ready_scoped(named: Maybe<&2, String>, +opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, +env: List<&2, Var>, json: Bool, quiet: Bool, prefix: String) -> Outcome:
  match named:
    case None{}:
      ready_picked(Query.pick_go(Query.comma_split(Cli.values(opts, "priority")), Query.PickOk{Nil{}}), opts, issues, env, json, quiet, None{})
    case Some{word}:
      ready_rooted(Views.hit(issues, word, prefix), opts, issues, env, json, quiet, (Cli.given(opts, "recursive") || Cli.given(opts, "epic")))

# S4.171–S4.178 (spec twin) `ready`
def ready_cmd(+opts: List<&2, Cli.Occ>, issues: List<&2, Model.Issue>, env: List<&2, Var>, json: Bool, quiet: Bool, prefix: String) -> Outcome:
  ready_scoped(parent_named(Cli.value(opts, "parent"), Cli.value(opts, "epic")), opts, issues, env, json, quiet, prefix)

# S5.53 S5.167–S5.172 (spec twin) `stats` once its lead time is known: one the port cannot print yet answers the
# port's own failure; `dims` are the breakdowns asked for, counted over `live` (the records that are not tombstones)
def stats_out(f: Work.Figures, l: Work.Lead, json: Bool, quiet: Bool, +dims: List<&2, U32>, +live: List<&2, Model.Issue>) -> Outcome:
  match l json:
    case Work.LeadBad{} _:
      failed(unported(), json)
    case Work.NoLead{} True{}:
      printed(Render.stats_json(f, "", Render.breaks_json(dims, live)), "", quiet)
    case Work.NoLead{} False{}:
      printed(Render.stats_plain(f, "", Render.breaks_plain(dims, live)), "", quiet)
    case Work.LeadOk{plain, number} True{}:
      printed(Render.stats_json(f, number, Render.breaks_json(dims, live)), "", quiet)
    case Work.LeadOk{plain, number} False{}:
      printed(Render.stats_plain(f, plain, Render.breaks_plain(dims, live)), "", quiet)

# S4.154 (spec twin) the figures with their average lead time
def stats_figures(+f: Work.Figures, json: Bool, quiet: Bool, +dims: List<&2, U32>, +live: List<&2, Model.Issue>) -> Outcome:
  stats_out(f, Work.lead(f), json, quiet, dims, live)

# S5.172 (spec twin) the breakdowns the `--by-*` flags ask for, in the fixed order type, priority, assignee, label
# whatever the order of the flags (`stats_by_label_type`); the numbers are Query.group_keys'
def stats_dims(+opts: List<&2, Cli.Occ>) -> List<&2, U32>:
  List.concat(&2, U32, [Bool.pick(List<&2, U32>, Cli.given(opts, "by-type"), [2], []), Bool.pick(List<&2, U32>, Cli.given(opts, "by-priority"), [1], []), Bool.pick(List<&2, U32>, Cli.given(opts, "by-assignee"), [3], []), Bool.pick(List<&2, U32>, Cli.given(opts, "by-label"), [4], [])])

# S5.172 (spec twin) keep a record that is not a tombstone
def live_put(i: Model.Issue, keep: Bool, rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match keep:
    case True{}:
      i <> rest
    case False{}:
      rest

# S5.172 (spec twin) the records the breakdowns count: every one that is not a tombstone (`scn_stats_tombstone`)
def not_tombstones(issues: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      live_put(i, Bool.not(String.eq(Model.status_of(i), "tombstone")), not_tombstones(rest))

# S4.151–S4.156 S5.172 (spec twin) `stats` with its breakdowns; the activity block is not ported (it needs git: PLAN §3)
def stats_cmd(+opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, +env: List<&2, Var>, json: Bool, quiet: Bool, later: Bool) -> Outcome:
  match later:
    case True{}:
      failed(unported(), json)
    case False{}:
      stats_figures(Work.figures(issues, Show.pinned(now_of(env)), spec_of(env)), json, quiet, stats_dims(opts), not_tombstones(issues))

# S1.34 (spec twin) the one positional of `search`, trimmed
def first_word(words: List<&2, String>) -> String:
  match words:
    case Nil{}:
      ""
    case Con{w, rest}:
      String.trim(w)

# S1.55 S8.13 (spec twin) the one id in `.beads/last-touched`: its text, trimmed; "" when the file is absent, empty or not UTF-8
def touched_text(d: Bytes.Decoded) -> String:
  match d:
    case Bytes.NotUtf8{}:
      ""
    case Bytes.Utf8{codes}:
      String.trim(Cli.text(codes))

# ---------------------------------------------------------------- files the argv names (S4.340, S4.381, S4.397)

# S4.397 (data) what the shell read for one file the argv names: its bytes, or the errno of the open or of the
# first read that failed
type Side is Data:
  SideOk{bytes: List<&2, U32>}
  SideErr{code: U32}

# S4.397 (spec twin) keep a named path
def path_put(given: Maybe<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  match given:
    case None{}:
      rest
    case Some{p}:
      p <> rest

# S4.340 S4.381 S4.397 (spec twin) the files one command names: `delete --from-file`, `comments add -f/--file`
# except `-` (standard input, not ported), `update` and `create --description-file`
def command_files(+path: String, +opts: List<&2, Cli.Occ>) -> List<&2, String>:
  path_put(Bool.pick(Maybe<&2, String>, String.eq(path, "delete"), Cli.value(opts, "from-file"), None{}), path_put(Bool.pick(Maybe<&2, String>, (String.eq(path, "comments add") && Bool.not(String.eq(Maybe.default(&2, String, Cli.value(opts, "file"), "-"), "-"))), Cli.value(opts, "file"), None{}), path_put(Bool.pick(Maybe<&2, String>, (String.eq(path, "update") || String.eq(path, "create")), Cli.value(opts, "description-file"), None{}), Nil{})))

# S4.397 (spec twin) the files of a parse: none unless the argument parser accepted a command
def parsed_files(p: Cli.Parsed) -> List<&2, String>:
  match p:
    case Cli.Refused{err}:
      Nil{}
    case Cli.Helped{path, long}:
      Nil{}
    case Cli.GroupHelp{path}:
      Nil{}
    case Cli.Versioned{}:
      Nil{}
    case Cli.Outside{word}:
      Nil{}
    case Cli.Command{path, opts, words}:
      command_files(path, opts)

# S4.397 (spec twin, entry) the files the shell reads before the run, in the order the shell passes them back
def side_files(argv: List<&2, String>) -> List<&2, String>:
  parsed_files(Cli.parse(argv))

# S4.397 (spec twin) a text that is not UTF-8, as the variable of S4.397 carries it
def side_text(+path: String, d: Bytes.Decoded) -> Var:
  match d:
    case Bytes.NotUtf8{}:
      Var{"@errno " ++ path, "utf8"}
    case Bytes.Utf8{codes}:
      Var{"@file " ++ path, Cli.text(codes)}

# S4.397 (spec twin, entry) what the shell read, as a variable of the run: `@file <path>` holds the text,
# `@errno <path>` the errno (`utf8` for bytes that are not UTF-8)
def side_var(+path: String, s: Side) -> Var:
  match s:
    case SideErr{code}:
      Var{"@errno " ++ path, U32.show(code)}
    case SideOk{bytes}:
      side_text(path, Bytes.decode(bytes))

# S8.5 (spec twin) the value of a variable, when one was passed
def var_find(env: List<&2, Var>, +name: String) -> Maybe<&2, String>:
  match env:
    case Nil{}:
      None{}
    case Con{Var{n, v}, rest}:
      Bool.pick(Maybe<&2, String>, String.eq(n, name), Some{v}, var_find(rest, name))

# S4.397 (data) a file the argv names, as the run sees it: its text, or the words of the error that stopped the read
type Read is Data:
  ReadOk{text: String}
  ReadBad{why: String}

# S4.397 (spec twin) the `strerror` text of the errnos a read of a named path can meet
def errno_text(+code: String) -> String:
  Bool.pick(String, String.eq(code, "2"), "No such file or directory", Bool.pick(String, String.eq(code, "13"), "Permission denied", Bool.pick(String, String.eq(code, "20"), "Not a directory", Bool.pick(String, String.eq(code, "21"), "Is a directory", Bool.pick(String, String.eq(code, "36"), "File name too long", Bool.pick(String, String.eq(code, "40"), "Too many levels of symbolic links", "Unknown error " ++ code))))))

# S4.397 (spec twin) the words of Rust's `io::Error` for a failed read: `<strerror> (os error <n>)`
def os_words(+code: String) -> String:
  Bool.pick(String, String.eq(code, "utf8"), "stream did not contain valid UTF-8", String.concat([errno_text(code), " (os error ", code, ")"]))

# S4.397 (spec twin) the read from its two variables
def read_pick(ok: Maybe<&2, String>, bad: Maybe<&2, String>) -> Read:
  match ok bad:
    case Some{text} _:
      ReadOk{text}
    case None{} Some{code}:
      ReadBad{os_words(code)}
    case None{} None{}:
      ReadBad{"not read"}

# S4.397 (spec twin) a named file as the run sees it
def read_of(+env: List<&2, Var>, +path: String) -> Read:
  read_pick(var_find(env, "@file " ++ path), var_find(env, "@errno " ++ path))

# S4.397 (spec twin) the file an option names, read, when the option was given
def file_read(+env: List<&2, Var>, given: Maybe<&2, String>) -> Maybe<&2, Read>:
  match given:
    case None{}:
      None{}
    case Some{path}:
      Some{read_of(env, path)}

# S4.340 S4.381 S9.1 (spec twin) a read that failed where the original propagates `io::Error`: `IO_ERROR`, exit 8
def io_failure(+why: String) -> Failure.Failure:
  Failure.Failure{"IO_ERROR", "I/O error: " ++ why, None{}, False{}, Nil{}, 8}

# S4.397 (spec twin) a `--description-file` that could not be read: a validation failure naming the path
def description_unread(+path: String, +why: String) -> Failure.Failure:
  Create.invalid("description_file", "failed to read description file '" ++ path ++ "': " ++ why)


# S5.105 S5.155 (spec twin) what `show` answered, as an outcome
def shown(s: Show.Shown, json: Bool, quiet: Bool) -> Outcome:
  match s:
    case Show.ShowBad{f}:
      failed(f, json)
    case Show.ShowOk{out}:
      printed(out, "", quiet)

# S8.5 DISC-001 (spec twin) a mutation with no usable instant: `BEADS_BEND_NOW` is not `<seconds>[.<fraction>]`,
# or it is unset and the shell's wall-clock reading is missing or malformed (exit 1)
def no_clock() -> Failure.Failure:
  Failure.Failure{"INTERNAL_ERROR", "beads_bend: no usable clock: BEADS_BEND_NOW must be <epoch seconds>[.<fraction>] (DISC-001)", None{}, False{}, Nil{}, 1}

# S4.2 (spec twin) the id seed's instant from `<seconds>` or `<seconds>.<fraction>`: nanoseconds since the epoch in
# decimal, the seconds' digits followed by the fraction padded to nine digits (a whole second gets nine zeros)
def seed_parts(parts: List<&2, String>) -> String:
  match parts:
    case Con{s, Nil{}}:
      s ++ "000000000"
    case Con{s, Con{+f, Nil{}}}:
      s ++ f ++ String.repeat("0", Nat.sub(9n, String.length(f)))
    case _:
      ""

# S4.2 (spec twin) the id seed's instant from the text the instant was read from
def seed_digits(text: String) -> String:
  seed_parts(String.split(String.trim(text), Chr{46}))

# S4.200 S4.220 (spec twin) what a mutation knows of the world, once the invocation instant is known
def world_of(now: Time.Instant, digits: String, +opts: List<&2, Cli.Occ>, +raw: List<&2, Model.Issue>, +env: List<&2, Var>, +cwd: String) -> Create.World:
  Create.World{Show.ids_of(raw), actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), now, seed_digits(digits), Prefix.text_of(Prefix.minted(Prefix.configured(env_of(env, ".beads/config.yaml")), raw, cwd)), cwd}

# S5.1 S5.17 S5.18 (spec twin) the file changes of a mutation that acted on `id`: the whole store re-rendered (unless
# the store is to be left alone), then the sidecar
def changes(store: Maybe<&2, String>, id: String) -> List<&2, Write>:
  match store:
    case None{}:
      Write{".beads/last-touched", Some{id ++ "\n"}} <> Nil{}
    case Some{text}:
      Write{".beads/issues.jsonl", Some{text}} <> Write{".beads/last-touched", Some{id ++ "\n"}} <> Nil{}

# S4.235 (spec twin) an optional line of the dry-run preview
def preview_line(label: String, value: String, shown: Bool) -> String:
  match shown:
    case False{}:
      ""
    case True{}:
      label ++ value ++ "\n"

# S4.235 (spec twin) the plain preview of `create --dry-run`: four lines, then `Labels`, `Parent` and `Dependencies` when they were given
def preview(+built: Model.Issue, +opts: List<&2, Cli.Occ>) -> String:
  String.concat(["Dry run: would create issue ", Render.inline(Model.id_of(built)), "\nTitle: ", Render.inline(Model.title_of(built)), "\nType: ", Render.inline(Model.type_of(built)), "\nPriority: P", Model.priority_of(built), "\n", preview_line("Labels: ", Render.inline(String.join(Model.labels_of(built), ", ")), Cli.given(opts, "labels")), preview_line("Parent: ", Render.inline(Maybe.default(&2, String, Cli.value(opts, "parent"), "")), Cli.given(opts, "parent")), preview_line("Dependencies: ", Render.inline(String.join(Cli.values(opts, "deps"), ", ")), Cli.given(opts, "deps"))])

# S4.235 S4.236 S5.37 S5.38 S5.203 (spec twin) what `create` prints: the bare id under `--silent` (which beats
# `--json`); the record as the store spells it under `--json`; else one `✓ Created` line
def created_text(+issue: Model.Issue, silent: Bool, json: Bool) -> String:
  match silent json:
    case True{} _:
      Model.id_of(issue) ++ "\n"
    case False{} True{}:
      Model.line(Model.written(issue)) ++ "\n"
    case False{} False{}:
      "✓ Created " ++ Render.inline(Model.id_of(issue)) ++ ": " ++ Render.inline(Model.title_of(issue)) ++ "\n"

# S5.1 S5.106 (spec twin) a successful mutation: its file changes always happen; Quiet suppresses only the report
def wrote(out: String, writes: List<&2, Write>, quiet: Bool) -> Outcome:
  match quiet:
    case True{}:
      Outcome{"", "", 0, writes}
    case False{}:
      Outcome{out, "", 0, writes}

# S4.234 S4.235 S5.1 (spec twin) a made issue as an outcome. `--dry-run` writes nothing and prints the preview (JSON:
# the record as built, which has no `original_size`); `--ephemeral` leaves the store alone and still writes the
# sidecar; anything else re-renders the whole model with the new record in it
def created(m: Create.Made, +opts: List<&2, Cli.Occ>, model: List<&2, Model.Issue>, +json: Bool, quiet: Bool, dry: Bool, ephemeral: Bool) -> Outcome:
  match m dry ephemeral:
    case Create.MadeBad{f} _ _:
      failed(f, json)
    case Create.MadeOk{issue, +built} True{} _:
      printed(Bool.pick(String, json, "{" ++ Model.members_raw(built) ++ "}\n", preview(built, opts)), "", quiet)
    case Create.MadeOk{+issue, built} False{} True{}:
      wrote(created_text(issue, Cli.given(opts, "silent"), json), changes(None{}, Model.id_of(issue)), quiet)
    case Create.MadeOk{+issue, built} False{} False{}:
      wrote(created_text(issue, Cli.given(opts, "silent"), json), changes(Some{Store.text(List.append(&2, Model.Issue, model, issue <> Nil{}))}, Model.id_of(issue)), quiet)

# S4.222 (spec twin) the title of `create`: the positional, else `--title`, else nothing (which validation refuses)
def create_title(words: List<&2, String>, flag: Maybe<&2, String>) -> String:
  match words:
    case Con{w, rest}:
      w
    case Nil{}:
      Maybe.default(&2, String, flag, "")

# S4.15 S4.220–S4.234 (spec twin) the request of `create`: the id seed takes the RAW title, the raw description and the actor
def create_request(+opts: List<&2, Cli.Occ>, +title: String, actor: String) -> Create.Request:
  Create.Request{title, Maybe.default(&2, String, Cli.value(opts, "description"), ""), actor, Cli.value(opts, "description"), Cli.value(opts, "type"), Cli.value(opts, "priority"), Cli.value(opts, "status"), Cli.value(opts, "assignee"), Cli.value(opts, "owner"), Cli.values(opts, "labels"), Cli.value(opts, "parent"), Cli.values(opts, "deps"), Cli.value(opts, "estimate"), Cli.value(opts, "due"), Cli.value(opts, "defer"), Cli.value(opts, "external-ref"), Cli.value(opts, "acceptance-criteria"), Cli.value(opts, "prerequisites"), Cli.value(opts, "slug"), Cli.given(opts, "ephemeral"), False{}}

# S4.16 S1.38 (spec twin) the request of `q`: the title is the words joined by one space and trimmed; the id seed's
# description and creator parts are EMPTY
def q_request(+opts: List<&2, Cli.Occ>, words: List<&2, String>) -> Create.Request:
  Create.Request{String.trim(String.join(words, " ")), "", "", Cli.value(opts, "description"), Cli.value(opts, "type"), Cli.value(opts, "priority"), None{}, None{}, None{}, Cli.values(opts, "labels"), Cli.value(opts, "parent"), Nil{}, Cli.value(opts, "estimate"), None{}, None{}, None{}, None{}, None{}, None{}, False{}, True{}}

# S4.200 (spec twin) the actor a world names
def world_actor(w: Create.World) -> String:
  match w:
    case Create.World{ids, actor, now, nanos, prefix, repo_path}:
      actor

# S4.220–S4.239 (spec twin) `create` with the world known
def create_in(+w: Create.World, +opts: List<&2, Cli.Occ>, words: List<&2, String>, raw: List<&2, Model.Issue>, +json: Bool, quiet: Bool) -> Outcome:
  created(Create.make(create_request(opts, create_title(words, Cli.value(opts, "title")), world_actor(w)), w), opts, Store.model(raw), json, quiet, Cli.given(opts, "dry-run"), Cli.given(opts, "ephemeral"))

# S4.397 (spec twin) `create --description-file`: its text is the `--description` value (the parser refuses the two
# together), and a file that could not be read is a validation failure
def create_described(file: Maybe<&2, Read>, at: Time.Instant, +opts: List<&2, Cli.Occ>, words: List<&2, String>, +raw: List<&2, Model.Issue>, +env: List<&2, Var>, cwd: String, +json: Bool, quiet: Bool) -> Outcome:
  match file:
    case None{}:
      create_in(world_of(at, now_of(env), opts, raw, env, cwd), opts, words, raw, json, quiet)
    case Some{ReadBad{why}}:
      failed(description_unread(Maybe.default(&2, String, Cli.value(opts, "description-file"), ""), why), json)
    case Some{ReadOk{text}}:
      create_in(world_of(at, now_of(env), opts, raw, env, cwd), List.append(&2, Cli.Occ, opts, Cli.Occ{"description", text} <> Nil{}), words, raw, json, quiet)

# S4.254 S5.38 (spec twin) what `q` answered: the bare id and a newline; as JSON, an object of the id and the title only
def quick(m: Create.Made, model: List<&2, Model.Issue>, +json: Bool, quiet: Bool) -> Outcome:
  match m:
    case Create.MadeBad{f}:
      failed(f, json)
    case Create.MadeOk{+issue, built}:
      wrote(Bool.pick(String, json, "{\"id\":" ++ Failure.quoted(Model.id_of(issue)) ++ ",\"title\":" ++ Failure.quoted(Model.title_of(issue)) ++ "}\n", Model.id_of(issue) ++ "\n"), changes(Some{Store.text(List.append(&2, Model.Issue, model, issue <> Nil{}))}, Model.id_of(issue)), quiet)

# S4.237 S4.225 S4.232 (spec twin) `create` and `q` once the pinned instant was read: without one the port refuses
# (no clock effect yet); `--file` and `--agent-context` are not ported yet
def create_cmd(now: Maybe<&2, Time.Instant>, +opts: List<&2, Cli.Occ>, words: List<&2, String>, +raw: List<&2, Model.Issue>, +env: List<&2, Var>, cwd: String, +json: Bool, quiet: Bool, later: Bool, is_q: Bool) -> Outcome:
  match now later is_q:
    case None{} _ _:
      failed(no_clock(), json)
    case Some{at} True{} _:
      failed(unported(), json)
    case Some{at} False{} False{}:
      create_described(file_read(env, Cli.value(opts, "description-file")), at, opts, words, raw, env, cwd, json, quiet)
    case Some{at} False{} True{}:
      quick(Create.make(q_request(opts, words), world_of(at, now_of(env), opts, raw, env, cwd)), Store.model(raw), json, quiet)

# S4.269 (spec twin) is a status word terminal
def terminal_word(+word: String) -> Bool:
  (String.eq(word, "closed") || String.eq(word, "tombstone"))

# S4.269 (spec twin) `update --status closed` is refused before any I/O, with the original's words
def close_via_update() -> Failure.Failure:
  Create.invalid("status", "refusing to close via `br update --status closed`: terminal-state transitions must go through `br close` so close-policy (close-reason / AC / attribution) is enforced. Use `br close <id> --reason \"...\"` instead, or `br close <id> --bypass-policy --bypass-reason \"...\"` to opt out explicitly. See https://github.com/Dicklesworthstone/beads_rust/issues/301.")

# S4.203 S4.209 S5.18 (spec twin) the file changes of a batch: the store only when a stored column changed, the sidecar
# whenever an id was acted on
def batch_changes(model: List<&2, Model.Issue>, changed: Bool, last: String) -> List<&2, Write>:
  match changed last:
    case _ SNil{}:
      Nil{}
    case True{} SCon{h, t}:
      changes(Some{Store.text(model)}, SCon{h, t})
    case False{} SCon{h, t}:
      changes(None{}, SCon{h, t})

# S4.261 S4.273 S5.39 (spec twin) what `update` answered: the blocks in order (JSON: one array), and the file changes
def updated(b: Update.Batch, json: Bool, quiet: Bool) -> Outcome:
  match b json:
    case Update.BatchBad{f} mode:
      failed(f, mode)
    case Update.BatchOk{model, plain, elements, changed, last} True{}:
      wrote("[" ++ String.join(List.reverse(&2, String, elements), ",") ++ "]\n", batch_changes(model, changed, last), quiet)
    case Update.BatchOk{model, plain, elements, changed, last} False{}:
      wrote(String.concat(List.reverse(&2, String, plain)), batch_changes(model, changed, last), quiet)

# S4.260 S4.264 (spec twin) was any field flag given: without one, `update` reports `No updates specified`
def any_update_flag(+opts: List<&2, Cli.Occ>) -> Bool:
  (Cli.given(opts, "status") || Cli.given(opts, "priority") || Cli.given(opts, "type") || Cli.given(opts, "title") || Cli.given(opts, "description") || Cli.given(opts, "design") || Cli.given(opts, "acceptance-criteria") || Cli.given(opts, "prerequisites") || Cli.given(opts, "notes") || Cli.given(opts, "append-notes") || Cli.given(opts, "parent") || Cli.given(opts, "assignee") || Cli.given(opts, "owner") || Cli.given(opts, "estimate") || Cli.given(opts, "due") || Cli.given(opts, "defer") || Cli.given(opts, "external-ref") || Cli.given(opts, "source-repo") || Cli.given(opts, "source-repo-path") || Cli.given(opts, "claim") || Cli.given(opts, "set-labels") || Cli.given(opts, "add-label") || Cli.given(opts, "remove-label") || Cli.given(opts, "check-acceptance") || Cli.given(opts, "uncheck-acceptance") || Cli.given(opts, "add-acceptance"))

# S4.270 (spec twin) `update` once its `--parent` was resolved: an id that resolves to nothing is refused
# (`error_update_parent_missing`); `""` clears the parent (`update_parent_clear`)
def update_parented(p: Resolve.Found, given: Bool, ids: List<&2, String>, +opts: List<&2, Cli.Occ>, +model: List<&2, Model.Issue>, priority: Maybe<&2, String>, actor: String, now: Time.Instant, +json: Bool, quiet: Bool) -> Outcome:
  match p given:
    case Resolve.FoundBad{f} _:
      failed(f, json)
    case Resolve.FoundOk{pid} True{}:
      updated(Update.run(ids, model, opts, priority, Blocked.relation(model), actor, now, any_update_flag(opts), Some{pid}), json, quiet)
    case Resolve.FoundOk{pid} False{}:
      updated(Update.run(ids, model, opts, priority, Blocked.relation(model), actor, now, any_update_flag(opts), None{}), json, quiet)

# S4.270 (spec twin) the parent `--parent` names: `""` as it is (a clear), anything else resolved like an issue id
def new_parent(given: Maybe<&2, String>, +ids: List<&2, String>, +prefix: String) -> Resolve.Found:
  match given:
    case None{}:
      Resolve.FoundOk{""}
    case Some{+word}:
      Bool.pick(Resolve.Found, String.is_empty(String.trim(word)), Resolve.FoundOk{""}, Resolve.resolve(ids, word, prefix))

# S4.396 (spec twin) `update --session`: only a close takes a session, and `update` never closes (S4.269)
def session_via_update() -> Failure.Failure:
  Create.invalid("session", "--session can only be used when closing with --status closed")

# S4.212 S4.260 S4.396 (spec twin) `update` once every id is resolved, then its `--session`, then its `--parent`
def update_many(m: Resolve.Many, +opts: List<&2, Cli.Occ>, +model: List<&2, Model.Issue>, priority: Maybe<&2, String>, actor: String, now: Time.Instant, +json: Bool, quiet: Bool, +prefix: String) -> Outcome:
  match m:
    case Resolve.ManyBad{f}:
      failed(f, json)
    case Resolve.ManyOk{ids}:
      Bool.pick(Outcome, Cli.given(opts, "session"), failed(session_via_update(), json), update_parented(new_parent(Cli.value(opts, "parent"), Show.ids_of(model), prefix), Cli.given(opts, "parent"), ids, opts, model, priority, actor, now, json, quiet))

# S4.260 (spec twin) `update` once its ids are known: none at all (no positional, no last-touched issue) is refused
def update_ids(ids: List<&2, String>, +opts: List<&2, Cli.Occ>, +raw: List<&2, Model.Issue>, priority: Maybe<&2, String>, actor: String, now: Time.Instant, +prefix: String, +json: Bool, quiet: Bool) -> Outcome:
  match ids:
    case Nil{}:
      failed(Show.no_ids(), json)
    case Con{id, rest}:
      update_many(Resolve.many(id <> rest, Show.ids_of(raw), prefix), opts, Store.model(raw), priority, actor, now, json, quiet, prefix)

# S4.397 (spec twin) `update --description-file`: read before any id is resolved; its text is the `--description`
# value (the parser refuses the two together), and a file that could not be read is a validation failure
def update_described(file: Maybe<&2, Read>, ids: List<&2, String>, +opts: List<&2, Cli.Occ>, raw: List<&2, Model.Issue>, priority: Maybe<&2, String>, actor: String, now: Time.Instant, prefix: String, +json: Bool, quiet: Bool) -> Outcome:
  match file:
    case None{}:
      update_ids(ids, opts, raw, priority, actor, now, prefix, json, quiet)
    case Some{ReadBad{why}}:
      failed(description_unread(Maybe.default(&2, String, Cli.value(opts, "description-file"), ""), why), json)
    case Some{ReadOk{text}}:
      update_ids(ids, List.append(&2, Cli.Occ, opts, Cli.Occ{"description", text} <> Nil{}), raw, priority, actor, now, prefix, json, quiet)

# S4.224 S4.275 (spec twin) `update` once its priority was judged
def update_ranked(r: Create.Rank, given: Bool, ids: List<&2, String>, opts: List<&2, Cli.Occ>, raw: List<&2, Model.Issue>, actor: String, now: Time.Instant, prefix: String, json: Bool, quiet: Bool, file: Maybe<&2, Read>) -> Outcome:
  match r given:
    case Create.RankBad{f} _:
      failed(f, json)
    case Create.RankOk{digits} True{}:
      update_described(file, ids, opts, raw, Some{digits}, actor, now, prefix, json, quiet)
    case Create.RankOk{digits} False{}:
      update_described(file, ids, opts, raw, None{}, actor, now, prefix, json, quiet)

# S4.269 S4.275 (spec twin) `update`: the forms that are not ported, the missing clock, and a terminal `--status` are
# answered before anything else
def update_cmd(now: Maybe<&2, Time.Instant>, +opts: List<&2, Cli.Occ>, ids: List<&2, String>, raw: List<&2, Model.Issue>, actor: String, prefix: String, +json: Bool, quiet: Bool, later: Bool, terminal: Bool, file: Maybe<&2, Read>) -> Outcome:
  match now later terminal:
    case _ True{} _:
      failed(unported(), json)
    case None{} False{} _:
      failed(no_clock(), json)
    case Some{at} False{} True{}:
      failed(close_via_update(), json)
    case Some{at} False{} False{}:
      update_ranked(Create.rank_of(Cli.value(opts, "priority")), Cli.given(opts, "priority"), ids, opts, raw, actor, at, prefix, json, quiet, file)

# S5.1 S5.18 (spec twin) the file changes of a transition batch: nothing when no id was acted on
def batch_writes(model: List<&2, Model.Issue>, last: String) -> List<&2, Write>:
  match last:
    case SNil{}:
      Nil{}
    case SCon{h, t}:
      changes(Some{Store.text(model)}, SCon{h, t})

# S4.297 (spec twin) keep an id that was blocked before the write, is not blocked after it, and is then `open` or `in_progress`
def unblocked_put(found: Maybe<&2, Model.Issue>, freed: Bool, +rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match found freed:
    case Some{+i} True{}:
      Bool.pick(List<&2, Model.Issue>, (String.eq(Model.status_of(i), "open") || String.eq(Model.status_of(i), "in_progress")), i <> rest, rest)
    case _ _:
      rest

# S4.297 (spec twin) the issues a close unblocked: the blocked ids before the write minus the blocked ids after it
def unblocked(before: List<&2, String>, +after: List<&2, String>, +model: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match before:
    case Nil{}:
      Nil{}
    case Con{+id, rest}:
      unblocked_put(Blocked.lookup(model, id), Bool.not(Blocked.among(after, id)), unblocked(rest, after, model))

# S4.297 (spec twin) the unblocked issues as plain lines and as JSON objects `{"id","title","priority"}`
def unblocked_text(items: List<&2, Model.Issue>, json: Bool, first: Bool) -> List<&2, String>:
  match items json:
    case Nil{} _:
      Nil{}
    case Con{+i, rest} True{}:
      String.concat([Bool.pick(String, first, "", ","), "{\"id\":", Failure.quoted(Model.id_of(i)), ",\"title\":", Failure.quoted(Model.title_of(i)), ",\"priority\":", Model.priority_of(i), "}"]) <> unblocked_text(rest, True{}, False{})
    case Con{+i, rest} False{}:
      ("  " ++ Render.inline(Model.id_of(i)) ++ ": " ++ Render.inline(Model.title_of(i)) ++ "\n") <> unblocked_text(rest, False{}, False{})

# S4.297 S4.298 S5.40 (spec twin) the stdout of `close`. Plain: the success lines, then the unblocked block under
# `--suggest-next`. JSON: a bare array when nothing was skipped and `--suggest-next` was not given; else an object
# with `closed`, `skipped` (omitted when empty) and, under `--suggest-next`, `unblocked`
def close_text(+elements: List<&2, String>, lines: List<&2, String>, +skips: List<&2, Status.Skip>, +freed: List<&2, Model.Issue>, +suggest: Bool, json: Bool) -> String:
  match json:
    case False{}:
      String.concat(lines) ++ Bool.pick(String, (suggest && Bool.not(List.is_empty(&2, Model.Issue, freed))), "Unblocked " ++ Nat.show(List.length(&2, Model.Issue, freed)) ++ " issue(s):\n" ++ String.concat(unblocked_text(freed, False{}, True{})), "")
    case True{}:
      Bool.pick(String, (List.is_empty(&2, Status.Skip, skips) && Bool.not(suggest)), "[" ++ String.join(elements, ",") ++ "]\n", String.concat(["{\"closed\":[", String.join(elements, ","), "]", Bool.pick(String, List.is_empty(&2, Status.Skip, skips), "", ",\"skipped\":[" ++ String.concat(Status.skip_objects(skips, True{})) ++ "]"), Bool.pick(String, suggest, ",\"unblocked\":[" ++ String.concat(unblocked_text(freed, True{}, True{})) ++ "]", ""), "}\n"]))

# S4.293 S4.294 S5.22 S9.26 (spec twin) a `close` with skips fails AFTER its output and its writes; `--quiet`
# drops the success lines and the per-item warnings (golden close_blocked_quiet) and keeps the error. Every id skipped is
# `NOTHING_TO_DO`, some skipped is `CLOSE_INCOMPLETE`; JSON mode prints the payload and then the envelope on stdout and
# nothing on stderr; plain mode prints the warnings and the error on stderr
def close_failed(out: String, +skips: List<&2, Status.Skip>, +closed: Nat, writes: List<&2, Write>, json: Bool, +quiet: Bool) -> Outcome:
  match json:
    case True{}:
      Outcome{out ++ Failure.json_text(Bool.pick(Failure.Failure, Nat.is_eq(closed, 0n), Status.nothing_to_do(skips), Status.close_incomplete(closed, skips))), "", 3, writes}
    case False{}:
      Outcome{Bool.pick(String, quiet, "", out), Bool.pick(String, quiet, "", String.concat(Status.warning_lines(skips))) ++ Failure.plain_text(Bool.pick(Failure.Failure, Nat.is_eq(closed, 0n), Status.nothing_to_do(skips), Status.close_incomplete(closed, skips))), 3, writes}

# S4.293 S4.294 (spec twin) a `close` without skips succeeds; one with skips fails after its output and writes
def close_done(out: String, skips: List<&2, Status.Skip>, closed: Nat, writes: List<&2, Write>, json: Bool, +quiet: Bool) -> Outcome:
  match skips:
    case Nil{}:
      wrote(out, writes, quiet)
    case Con{s, rest}:
      close_failed(out, s <> rest, closed, writes, json, quiet)

# S4.290–S4.299 (spec twin) what a `close` batch answered; `before` is the blocked ids of the store before the batch
def closed_batch(b: Status.Batch, before: List<&2, String>, suggest: Bool, +json: Bool, quiet: Bool) -> Outcome:
  match b:
    case Status.Batch{+model, +plain, elements, +skips, last}:
      close_done(close_text(List.reverse(&2, String, elements), List.reverse(&2, String, plain), List.reverse(&2, Status.Skip, skips), unblocked(before, Blocked.keys(Blocked.relation(model)), model), suggest, json), List.reverse(&2, Status.Skip, skips), List.length(&2, String, plain), batch_writes(model, last), json, quiet)

# S4.290 S4.297 (spec twin) `close` once every id is resolved: `--suggest-next` works with a single id only
def close_many(m: Resolve.Many, +opts: List<&2, Cli.Occ>, +model: List<&2, Model.Issue>, actor: String, now: Time.Instant, +json: Bool, quiet: Bool) -> Outcome:
  match m:
    case Resolve.ManyBad{f}:
      failed(f, json)
    case Resolve.ManyOk{+ids}:
      Bool.pick(Outcome, (Cli.given(opts, "suggest-next") && Nat.is_gt(List.length(&2, String, ids), 1n)), failed(Create.invalid("suggest-next", "--suggest-next only works with a single issue ID"), json), closed_batch(Status.close_go(ids, Status.Batch{model, Nil{}, Nil{}, Nil{}, ""}, model, Blocked.relation(model), now, Maybe.default(&2, String, Cli.value(opts, "reason"), "done"), Cli.given(opts, "force"), Status.Note{Cli.value(opts, "transition-comment"), actor, Cli.value(opts, "session")}), Blocked.keys(Blocked.relation(model)), Cli.given(opts, "suggest-next"), json, quiet))

# S4.314 S4.326 S5.42 S5.43 S5.107 (spec twin) what `reopen`, `defer` or `undefer` answered: the successes before
# the skips; `hush` is `--quiet` for `defer` and `undefer`, which S5.107 short-circuits, and False for `reopen`,
# which prints its line even under `--quiet` (golden reopen_quiet);
# as JSON one object whose first member is named after the command, `skipped` omitted when empty; exit 0 even when
# every id was skipped; `nothing` is the line for a batch in which literally nothing happened
def gated_batch(b: Status.Batch, name: String, nothing: String, json: Bool, hush: Bool) -> Outcome:
  match b json:
    case Status.Batch{model, plain, elements, +skips, last} True{}:
      wrote(String.concat(["{\"", name, "\":[", String.join(List.reverse(&2, String, elements), ","), "]", Bool.pick(String, List.is_empty(&2, Status.Skip, skips), "", ",\"skipped\":[" ++ String.concat(Status.skip_objects(List.reverse(&2, Status.Skip, skips), True{})) ++ "]"), "}\n"]), batch_writes(model, last), hush)
    case Status.Batch{model, +plain, elements, +skips, last} False{}:
      wrote(Bool.pick(String, (List.is_empty(&2, String, plain) && List.is_empty(&2, Status.Skip, skips)), nothing, String.concat(List.reverse(&2, String, plain)) ++ String.concat(Status.skip_lines(List.reverse(&2, Status.Skip, skips)))), batch_writes(model, last), hush)

# S4.310–S4.315 (spec twin) `reopen` once every id is resolved
def reopen_many(m: Resolve.Many, +opts: List<&2, Cli.Occ>, +model: List<&2, Model.Issue>, actor: String, now: Time.Instant, +json: Bool, quiet: Bool) -> Outcome:
  match m:
    case Resolve.ManyBad{f}:
      failed(f, json)
    case Resolve.ManyOk{ids}:
      gated_batch(Status.reopen_go(ids, Status.Batch{model, Nil{}, Nil{}, Nil{}, ""}, model, now, Cli.value(opts, "reason"), actor), "reopened", "No issues to reopen.\n", json, False{})

# S4.321–S4.326 (spec twin) `defer` (`deferring` true) or `undefer` once every id is resolved
def gate_many(m: Resolve.Many, +model: List<&2, Model.Issue>, now: Time.Instant, until: Maybe<&2, Time.Instant>, +deferring: Bool, note: Status.Note, +json: Bool, quiet: Bool) -> Outcome:
  match m:
    case Resolve.ManyBad{f}:
      failed(f, json)
    case Resolve.ManyOk{ids}:
      gated_batch(Status.gate_go(ids, Status.Batch{model, Nil{}, Nil{}, Nil{}, ""}, model, now, until, deferring, note),Bool.pick(String, deferring, "deferred", "undeferred"), Bool.pick(String, deferring, "No issues to defer.\n", "No issues to undefer.\n"), json, quiet)

# S4.322 S4.324 (spec twin) `defer --until`, judged once before any issue is examined
def gate_until(n: When.Named, m: Resolve.Many, model: List<&2, Model.Issue>, now: Time.Instant, note: Status.Note, json: Bool, quiet: Bool) -> Outcome:
  match n:
    case When.NoTime{why}:
      failed(Create.invalid("defer_until", When.reason(why)), json)
    case When.AtTime{at}:
      gate_many(m, model, now, Some{at}, True{}, note, json, quiet)

# S4.399 (spec twin) `close --bypass-policy` and `--bypass-reason` come as a pair, judged before anything else (the ids,
# the last-touched fallback): the flag without a non-blank reason, and a reason without the flag, are refused. The port
# configures no close policy (PLAN §3), so a valid pair changes nothing else
def bypass_refusal(+opts: List<&2, Cli.Occ>) -> Maybe<&2, Failure.Failure>:
  Bool.pick(Maybe<&2, Failure.Failure>, (Cli.given(opts, "bypass-policy") && String.is_empty(String.trim(Maybe.default(&2, String, Cli.value(opts, "bypass-reason"), "")))), Some{Create.invalid("bypass-reason", "--bypass-policy requires --bypass-reason \"<text>\"")}, Bool.pick(Maybe<&2, Failure.Failure>, (Bool.not(Cli.given(opts, "bypass-policy")) && Cli.given(opts, "bypass-reason")), Some{Create.invalid("bypass-policy", "--bypass-reason was set without --bypass-policy")}, None{}))

# S4.399 (spec twin) the refusal of the pair, or the run
def bypassed(r: Maybe<&2, Failure.Failure>, json: Bool, o: Outcome) -> Outcome:
  match r:
    case None{}:
      o
    case Some{f}:
      failed(f, json)

# S4.290 S4.310 S4.320 (spec twin) the four status transitions: `which` is 0 close, 1 reopen, 2 defer, 3 undefer. Forms that
# are not ported and a missing clock are answered first; `close` and `reopen` fall back to `.beads/last-touched`,
# `defer` and `undefer` demand an id
def transition(which: U32, now: Maybe<&2, Time.Instant>, later: Bool, +ids: List<&2, String>, +opts: List<&2, Cli.Occ>, +raw: List<&2, Model.Issue>, +actor: String, +prefix: String, +json: Bool, +quiet: Bool) -> Outcome:
  match which now later ids:
    case _ _ True{} _:
      failed(unported(), json)
    case _ None{} False{} _:
      failed(no_clock(), json)
    case 0 Some{at} False{} Nil{}:
      failed(Show.no_ids(), json)
    case 1 Some{at} False{} Nil{}:
      failed(Show.no_ids(), json)
    case _ Some{at} False{} Nil{}:
      failed(Create.invalid("ids", "at least one issue ID is required"), json)
    case 0 Some{at} False{} Con{id, rest}:
      close_many(Resolve.many(id <> rest, Show.ids_of(raw), prefix), opts, Store.model(raw), actor, at, json, quiet)
    case 1 Some{at} False{} Con{id, rest}:
      reopen_many(Resolve.many(id <> rest, Show.ids_of(raw), prefix), opts, Store.model(raw), actor, at, json, quiet)
    case 2 Some{+at} False{} Con{id, rest}:
      Bool.pick(Outcome, Cli.given(opts, "until"), gate_until(When.named(String.trim(Maybe.default(&2, String, Cli.value(opts, "until"), "")), at), Resolve.many(id <> rest, Show.ids_of(raw), prefix), Store.model(raw), at, Status.Note{Cli.value(opts, "transition-comment"), actor, None{}}, json, quiet), gate_many(Resolve.many(id <> rest, Show.ids_of(raw), prefix), Store.model(raw), at, None{}, True{}, Status.Note{Cli.value(opts, "transition-comment"), actor, None{}}, json, quiet))
    case _ Some{at} False{} Con{id, rest}:
      gate_many(Resolve.many(id <> rest, Show.ids_of(raw), prefix), Store.model(raw), at, None{}, False{}, Status.Note{Cli.value(opts, "transition-comment"), actor, None{}}, json, quiet)

# S5.20 S5.105 (spec twin) what a small view answered, as an outcome; a form that is not ported answers the port's own failure
def viewed(v: Views.View, json: Bool, quiet: Bool) -> Outcome:
  match v:
    case Views.ViewBad{f}:
      failed(f, json)
    case Views.ViewOk{out}:
      printed(out, "", quiet)
    case Views.ViewLater{}:
      failed(unported(), json)

# S4.179 (spec twin) the `--type` filter of `dep list` as the model spells edge types; "" when it is not given
def kind_of(given: Maybe<&2, String>) -> String:
  match given:
    case None{}:
      ""
    case Some{word}:
      Model.dep_type_repaired(word)

# S4.179–S4.181 (spec twin) `dep list <issue>`
def dep_list_cmd(+opts: List<&2, Cli.Occ>, +model: List<&2, Model.Issue>, word: String, prefix: String, +json: Bool, quiet: Bool) -> Outcome:
  viewed(Views.dep_list(Views.hit(model, word, prefix), model, Views.direction_of(Cli.value(opts, "direction")), kind_of(Cli.value(opts, "type")), json), json, quiet)

# S4.182–S4.185 (spec twin) `dep tree <issue>`
def dep_tree_cmd(+opts: List<&2, Cli.Occ>, +model: List<&2, Model.Issue>, word: String, prefix: String, +json: Bool, quiet: Bool) -> Outcome:
  viewed(Views.dep_tree(Views.hit(model, word, prefix), model, Views.direction_of(Cli.value(opts, "direction")), json, Views.max_depth_of(Cli.value(opts, "max-depth")), Views.mermaid_of(Cli.value(opts, "format"))), json, quiet)

# S5.185–S5.188 (spec twin) `label list [issue]`: without an issue it lists every label of the project
def label_list_cmd(+model: List<&2, Model.Issue>, words: List<&2, String>, prefix: String, +json: Bool, quiet: Bool) -> Outcome:
  match words:
    case Nil{}:
      viewed(Views.label_list_all(model, json), json, quiet)
    case Con{word, rest}:
      viewed(Views.label_list(Views.hit(model, word, prefix), json), json, quiet)

# S1.86 (spec twin) `comments` with neither a subcommand nor an id
def no_comment_id() -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: id: missing issue id", None{}, True{}, [Failure.CtxMember{"field", Failure.CStr{"id"}}, Failure.CtxMember{"reason", Failure.CStr{"missing issue id"}}], 4}

# S1.53 S5.192–S5.194 (spec twin) `comments list <id>` and its shorthand `comments <id>`
def comments_list_cmd(+model: List<&2, Model.Issue>, words: List<&2, String>, prefix: String, +json: Bool, quiet: Bool) -> Outcome:
  match words:
    case Nil{}:
      failed(no_comment_id(), json)
    case Con{word, rest}:
      viewed(Views.comments_list(Views.hit(model, word, prefix), json), json, quiet)

# ---------------------------------------------------------------- dep add / dep remove (S4.350–S4.363)

# S5.45 S5.107 (spec twin) a mutation that reports on stderr and still writes its files: `dep remove` with no such
# edge. Quiet suppresses both streams and never the writes
def warned(out: String, note: String, writes: List<&2, Write>, quiet: Bool) -> Outcome:
  match quiet:
    case True{}:
      Outcome{"", "", 0, writes}
    case False{}:
      Outcome{out, note, 0, writes}

# S4.360 S4.361 S5.45 (spec twin) what an edge command answered: the payload under `--json`, the plain line
# otherwise, and the warning of a removal that found nothing (whose plain line is empty)
def edged(d: Edges.Done, +dependent: String, +target: String, json: Bool, quiet: Bool) -> Outcome:
  match d json:
    case Edges.EdgeBad{f} mode:
      failed(f, mode)
    case Edges.EdgeOk{model, plain, entry, last, changed} True{}:
      warned(entry, "", batch_changes(model, changed, last), quiet)
    case Edges.EdgeOk{model, +plain, entry, last, changed} False{}:
      warned(plain, Bool.pick(String, String.is_empty(plain), Edges.not_found_warning(dependent, target), ""), batch_changes(model, changed, last), quiet)

# S4.353 (spec twin) is this endpoint a tombstone
def is_tombstone(found: Maybe<&2, Model.Issue>) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{i}:
      String.eq(Model.status_of(i), "tombstone")

# S4.353 S4.357 (spec twin) the refusals of `dep add` that come before the edge is judged: a tombstoned dependent, a
# tombstoned target, a `parent-child` edge to an `external:` target
def edge_refusal(+dependent: String, +target: String, dead_from: Bool, dead_to: Bool, parent_out: Bool) -> Maybe<&2, Failure.Failure>:
  match dead_from dead_to parent_out:
    case True{} _ _:
      Some{Create.invalid("issue_id", "cannot add dependency from tombstone issue: " ++ dependent)}
    case False{} True{} _:
      Some{Create.invalid("depends_on_id", "cannot depend on tombstone issue: " ++ target)}
    case False{} False{} True{}:
      Some{Create.invalid("depends_on_id", "parent-child dependencies must link local issues: " ++ target)}
    case False{} False{} False{}:
      None{}

# S4.350 S4.353 (spec twin) `dep add` once the dependent's record is in hand
def dep_add_found(found: Maybe<&2, Model.Issue>, +model: List<&2, Model.Issue>, +dependent: String, +target: String, +kind: String, now: Time.Instant, actor: String, json: Bool, quiet: Bool) -> Outcome:
  match found:
    case None{}:
      failed(Resolve.not_found(dependent), json)
    case Some{i}:
      edged(Edges.add_checked(model, i, dependent, target, kind, now, actor, String.eq(dependent, target), Edges.closes_cycle(model, dependent, target, kind)), dependent, target, json, quiet)

# S4.352 S4.353 S4.357 (spec twin) `dep add` once its `--type` is known: a type outside the eleven is refused, then the
# refusals of `edge_refusal`; `--metadata` is not ported
def dep_add_typed(+model: List<&2, Model.Issue>, +dependent: String, +target: String, +word: String, now: Time.Instant, actor: String, +json: Bool, quiet: Bool, later: Bool, pre: Maybe<&2, Failure.Failure>) -> Outcome:
  match later pre:
    case True{} _:
      failed(unported(), json)
    case False{} Some{f}:
      Bool.pick(Outcome, String.is_empty(Edges.canonical(word)), failed(Edges.bad_type(word), json), failed(f, json))
    case False{} None{}:
      Bool.pick(Outcome, String.is_empty(Edges.canonical(word)), failed(Edges.bad_type(word), json), dep_add_found(Blocked.lookup(model, dependent), model, dependent, target, Edges.canonical(word), now, actor, json, quiet))

# S4.359 (spec twin) `dep remove` once the dependent's record is in hand: the types between the pair decide
def dep_remove_found(found: Maybe<&2, Model.Issue>, +model: List<&2, Model.Issue>, +dependent: String, +target: String, given: Maybe<&2, String>, now: Time.Instant, json: Bool, quiet: Bool) -> Outcome:
  match found:
    case None{}:
      failed(Resolve.not_found(dependent), json)
    case Some{+i}:
      edged(Edges.remove_edge(model, i, dependent, target, Edges.types_between(Model.deps_of(i), target), given, now), dependent, target, json, quiet)

# S4.350 S4.359 (spec twin) an edge command once both of its ids are resolved
def edge_at(+model: List<&2, Model.Issue>, +dependent: String, +target: String, +opts: List<&2, Cli.Occ>, now: Time.Instant, actor: String, +json: Bool, quiet: Bool, adding: Bool) -> Outcome:
  match adding:
    case True{}:
      dep_add_typed(model, dependent, target, Maybe.default(&2, String, Cli.value(opts, "type"), "blocks"), now, actor, json, quiet, Cli.given(opts, "metadata"), edge_refusal(dependent, target, is_tombstone(Blocked.lookup(model, dependent)), is_tombstone(Blocked.lookup(model, target)), (String.eq(Model.dep_type_repaired(Maybe.default(&2, String, Cli.value(opts, "type"), "blocks")), "parent-child") && Blocked.external(target))))
    case False{}:
      dep_remove_found(Blocked.lookup(model, dependent), model, dependent, target, Cli.value(opts, "type"), now, json, quiet)

# S4.353 S4.357 (spec twin) the two ids of an edge command, the dependent's refusal winning over the target's; an
# `external:` target is taken verbatim and never resolved
def edge_ids(+stored: List<&2, String>, +issue: String, +target: String, +prefix: String) -> Resolve.Many:
  Resolve.many_put(Resolve.resolve(stored, issue, prefix), Bool.pick(Resolve.Many, Blocked.external(target), Resolve.ManyOk{target <> Nil{}}, Resolve.many(target <> Nil{}, stored, prefix)))

# S4.353 (spec twin) an edge command once its ids were judged
def edge_resolved(m: Resolve.Many, +model: List<&2, Model.Issue>, +opts: List<&2, Cli.Occ>, now: Time.Instant, actor: String, +json: Bool, quiet: Bool, adding: Bool) -> Outcome:
  match m:
    case Resolve.ManyBad{f}:
      failed(f, json)
    case Resolve.ManyOk{Con{dependent, Con{target, more}}}:
      edge_at(model, dependent, target, opts, now, actor, json, quiet, adding)
    case Resolve.ManyOk{other}:
      failed(unported(), json)

# S4.350–S4.363 (spec twin) `dep add` and `dep remove`; `adding` says which. The parser requires both positionals,
# so a shorter argv never reaches here
def edge_cmd(adding: Bool, now: Maybe<&2, Time.Instant>, +opts: List<&2, Cli.Occ>, words: List<&2, String>, +raw: List<&2, Model.Issue>, actor: String, +prefix: String, +json: Bool, quiet: Bool) -> Outcome:
  match now words:
    case None{} _:
      failed(no_clock(), json)
    case Some{at} Con{issue, Con{target, more}}:
      edge_resolved(edge_ids(Show.ids_of(raw), issue, target, prefix), Store.model(raw), opts, at, actor, json, quiet, adding)
    case Some{at} other:
      failed(unported(), json)

# ---------------------------------------------------------------- label add / remove / rename (S4.370–S4.379)

# S4.370 S9.18 (spec twin) `label add`/`label remove` with an issue but no label
def label_usage(+sub: String) -> Failure.Failure:
  Create.invalid("arguments", "usage: label " ++ sub ++ " <issue...> <label...> or label " ++ sub ++ " <issue...> -l <label>[,<label>]")

# S4.372 (spec twin) a refusal that still writes the store: the labels added before the ceiling cut the batch
# (no success line, no `.beads/last-touched`)
def failed_writing(o: Outcome, +model: List<&2, Model.Issue>, changed: Bool) -> Outcome:
  match o:
    case Outcome{out, err, code, writes}:
      Outcome{out, err, code, Bool.pick(List<&2, Write>, changed, Write{".beads/issues.jsonl", Some{Store.text(model)}} <> Nil{}, Nil{})}

# S4.371 S4.372 S4.376 (spec twin) what a label batch answered: its rows in label-major order, as one JSON array or
# as the plain lines, and the file changes (the store only when a record changed)
def labelled(b: Labels.Batch, json: Bool, quiet: Bool) -> Outcome:
  match b json:
    case Labels.BatchBad{f} mode:
      failed(f, mode)
    case Labels.BatchCut{f, model, changed} mode:
      failed_writing(failed(f, mode), model, changed)
    case Labels.BatchOk{model, plain, rows, last, changed} True{}:
      wrote("[" ++ String.join(List.reverse(&2, String, rows), ",") ++ "]\n", batch_changes(model, changed, last), quiet)
    case Labels.BatchOk{model, plain, rows, last, changed} False{}:
      wrote(String.concat(List.reverse(&2, String, plain)), batch_changes(model, changed, last), quiet)

# S4.370 (spec twin) a code point allowed before the last `-` of an id-shaped word: `a`–`z`, `0`–`9`, `_`, `.`, `-`
def id_head_char(+c: U32) -> Bool:
  (((c >= 97 : U32) && (c <= 122 : U32)) || ((c >= 48 : U32) && (c <= 57 : U32)) || U32.is_eq(c, 95) || U32.is_eq(c, 46) || U32.is_eq(c, 45))

# S4.370 (spec twin) a code point allowed after the last `-` of an id-shaped word: `a`–`z`, `0`–`9`, `.`
def id_tail_char(+c: U32) -> Bool:
  (((c >= 97 : U32) && (c <= 122 : U32)) || ((c >= 48 : U32) && (c <= 57 : U32)) || U32.is_eq(c, 46))

# S4.370 (spec twin) every code point of one side of an id-shaped word allowed there (`tail` picks the side)
def id_chars(s: String, +tail: Bool) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      (Bool.pick(Bool, tail, id_tail_char(c), id_head_char(c)) && id_chars(rest, tail))

# S4.370 (spec twin) a cut at the last `-`, both sides non-empty and made of their allowed code points
def shaped_cut(c: Resolve.Cut) -> Bool:
  match c:
    case Resolve.Cut{+left, +right, True{}}:
      (Bool.not(String.is_empty(left)) && Bool.not(String.is_empty(right)) && id_chars(left, False{}) && id_chars(right, True{}))
    case Resolve.Cut{left, right, False{}}:
      False{}

# S4.370 (spec twin) does a positional look like an issue id: `proj-mta`, `a-b-c`, `my_proj-abc`, `proj-mta.1` do;
# `Proj-mta`, `proj-MTA`, `ab-c_d`, `proj-`, `5u2` and `alpha` do not
def id_shaped(+w: String) -> Bool:
  shaped_cut(Resolve.cut_last(w, 45))

# S4.370 (spec twin) how many of the positionals before the last (REVERSED) are labels: each one that is not id-shaped,
# up to the first that is, and never the first positional (`left` counts the ones that may still be)
def label_count(rev: List<&2, String>, left: Nat) -> Nat:
  match rev left:
    case Nil{} _:
      0n
    case Con{w, rest} 0n:
      0n
    case Con{+w, rest} 1n+k:
      Bool.pick(Nat, id_shaped(w), 0n, Nat.add(1n, label_count(rest, k)))

# S4.370 (spec twin) how many positionals are issues: all but the last and the labels walked before it
def issue_count(+words: List<&2, String>) -> Nat:
  Nat.sub(List.length(&2, String, words), Nat.add(1n, label_count(List.drop(&2, String, List.reverse(&2, String, words), 1n), Nat.sub(List.length(&2, String, words), 2n))))

# S4.370 (spec twin) the issues of a label command: with `-l` every positional is one, otherwise the ones left of
# the labels
def label_issues(+words: List<&2, String>, flagged: Bool) -> List<&2, String>:
  Bool.pick(List<&2, String>, flagged, words, List.take(&2, String, words, issue_count(words)))

# S4.370 (spec twin) the labels of a label command: the `-l` values (comma split), otherwise the positionals from
# the first label to the end
def label_words(+words: List<&2, String>, flagged: Bool, given: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, flagged, given, List.drop(&2, String, words, issue_count(words)))

# S4.370 (spec twin) the shape of a label command's positionals: 0 usable, 1 the usage refusal (no `-l` and fewer
# than two)
def label_shape(flagged: Bool, +n: Nat) -> U32:
  Bool.pick(U32, flagged, 0, Bool.pick(U32, Bool.not(Nat.is_gt(n, 1n)), 1, 0))

# S4.370 (spec twin) a word on the issue side that resolves to nothing and is not id-shaped: most likely a label
# placed before an issue id
def not_an_issue(+word: String, +verb: String) -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: issues: '" ++ word ++ "' is not an issue ID and does not match any issue", Some{"Labels go after all issue IDs: br label " ++ verb ++ " <issue...> " ++ word ++ "; or pass -l " ++ word ++ " to name the label explicitly."}, True{}, [Failure.CtxMember{"field", Failure.CStr{"issues"}}, Failure.CtxMember{"reason", Failure.CStr{"'" ++ word ++ "' is not an issue ID and does not match any issue"}}, Failure.CtxMember{"hint", Failure.CStr{"Labels go after all issue IDs: br label " ++ verb ++ " <issue...> " ++ word ++ "; or pass -l " ++ word ++ " to name the label explicitly."}}], 4}

# S4.370 S4.212 (spec twin) one issue word that did not resolve: an id-shaped one keeps the resolution's own failure
def word_refusal(f: Resolve.Found, +word: String, +verb: String) -> Maybe<&2, Failure.Failure>:
  match f:
    case Resolve.FoundOk{id}:
      None{}
    case Resolve.FoundBad{bad}:
      Some{Bool.pick(Failure.Failure, id_shaped(word), bad, not_an_issue(word, verb))}

# S4.370 (spec twin) the first of two refusals that exists
def first_refusal(a: Maybe<&2, Failure.Failure>, b: Maybe<&2, Failure.Failure>) -> Maybe<&2, Failure.Failure>:
  match a:
    case Some{f}:
      Some{f}
    case None{}:
      b

# S4.370 S4.212 (spec twin) the first issue word, left to right, that resolves to nothing
def issue_refusal(words: List<&2, String>, +ids: List<&2, String>, +prefix: String, +verb: String) -> Maybe<&2, Failure.Failure>:
  match words:
    case Nil{}:
      None{}
    case Con{+w, rest}:
      first_refusal(word_refusal(Resolve.resolve(ids, w, prefix), w, verb), issue_refusal(rest, ids, prefix, verb))

# S4.373 S4.375 (spec twin) a label batch once its issues are resolved
def label_pairs(m: Resolve.Many, model: List<&2, Model.Issue>, labels: List<&2, String>, now: Time.Instant, adding: Bool, +json: Bool, quiet: Bool) -> Outcome:
  match m:
    case Resolve.ManyBad{f}:
      failed(f, json)
    case Resolve.ManyOk{ids}:
      labelled(Labels.run(model, ids, labels, now, adding, ""), json, quiet)

# S4.370 (spec twin) a label batch: an issue word that resolves to nothing refuses the whole command first
def label_resolved(r: Maybe<&2, Failure.Failure>, +issues: List<&2, String>, +raw: List<&2, Model.Issue>, +prefix: String, labels: List<&2, String>, now: Time.Instant, adding: Bool, +json: Bool, quiet: Bool) -> Outcome:
  match r:
    case Some{f}:
      failed(f, json)
    case None{}:
      label_pairs(Resolve.many(issues, Show.ids_of(raw), prefix), Store.model(raw), labels, now, adding, json, quiet)

# S4.372 (spec twin) every named label is validated before any issue is touched
def label_checked(+adding: Bool, at: Time.Instant, +opts: List<&2, Cli.Occ>, +words: List<&2, String>, +raw: List<&2, Model.Issue>, +prefix: String, +json: Bool, quiet: Bool, +bad: String) -> Outcome:
  match bad:
    case SCon{h, t}:
      failed(Labels.label_refusal(SCon{h, t}), json)
    case SNil{}:
      label_resolved(issue_refusal(label_issues(words, Cli.given(opts, "label")), Show.ids_of(raw), prefix, Bool.pick(String, adding, "add", "remove")), label_issues(words, Cli.given(opts, "label")), raw, prefix, label_words(words, Cli.given(opts, "label"), Query.comma_split(Cli.values(opts, "label"))), at, adding, json, quiet)

# S4.370 (spec twin) a label command once its positionals were counted
def label_shaped(+adding: Bool, at: Time.Instant, +opts: List<&2, Cli.Occ>, +words: List<&2, String>, +raw: List<&2, Model.Issue>, +prefix: String, +json: Bool, quiet: Bool, shape: U32) -> Outcome:
  match shape:
    case 1:
      failed(label_usage(Bool.pick(String, adding, "add", "remove")), json)
    case _:
      label_checked(adding, at, opts, words, raw, prefix, json, quiet, Labels.first_bad(label_words(words, Cli.given(opts, "label"), Query.comma_split(Cli.values(opts, "label")))))

# S4.370–S4.376 (spec twin) `label add` and `label remove`; `adding` says which
def label_cmd(adding: Bool, now: Maybe<&2, Time.Instant>, +opts: List<&2, Cli.Occ>, +words: List<&2, String>, +raw: List<&2, Model.Issue>, +prefix: String, +json: Bool, quiet: Bool) -> Outcome:
  match now:
    case None{}:
      failed(no_clock(), json)
    case Some{at}:
      label_shaped(adding, at, opts, words, raw, prefix, json, quiet, label_shape(Cli.given(opts, "label"), List.length(&2, String, words)))

# S4.377 S5.18 (spec twin) the file changes of a rename: the store when a record changed, and never the sidecar
def store_only(model: List<&2, Model.Issue>, changed: Bool) -> List<&2, Write>:
  match changed:
    case True{}:
      Write{".beads/issues.jsonl", Some{Store.text(model)}} <> Nil{}
    case False{}:
      Nil{}

# S4.377 S4.378 S5.50 (spec twin) what `label rename` answered
def renamed(d: Labels.Done, json: Bool, quiet: Bool) -> Outcome:
  match d json:
    case Labels.LabelBad{f} mode:
      failed(f, mode)
    case Labels.LabelOk{model, plain, entry, last, changed} True{}:
      wrote(entry, store_only(model, changed), quiet)
    case Labels.LabelOk{model, plain, entry, last, changed} False{}:
      wrote(plain, store_only(model, changed), quiet)

# S4.372 S4.377 (spec twin) `label rename` once both names were validated
def rename_checked(at: Time.Instant, +model: List<&2, Model.Issue>, +old: String, +new: String, json: Bool, quiet: Bool, +bad: String) -> Outcome:
  match bad:
    case SCon{h, t}:
      failed(Labels.label_refusal(SCon{h, t}), json)
    case SNil{}:
      renamed(Labels.rename(model, old, new, at, String.eq(old, new), Labels.affected(model, old, 0)), json, quiet)

# S4.377–S4.379 (spec twin) `label rename <old> <new>`; the parser requires both positionals
def rename_cmd(now: Maybe<&2, Time.Instant>, words: List<&2, String>, +raw: List<&2, Model.Issue>, +json: Bool, quiet: Bool) -> Outcome:
  match now words:
    case None{} _:
      failed(no_clock(), json)
    case Some{at} Con{+old, Con{+new, more}}:
      rename_checked(at, Store.model(raw), old, new, json, quiet, Labels.first_bad(old <> new <> Nil{}))
    case Some{at} other:
      failed(unported(), json)

# ---------------------------------------------------------------- comments add (S4.380–S4.385)

# S4.381 (spec twin) `comments add` with no text source at all
def comment_required() -> Failure.Failure:
  Create.invalid("text", "comment text required")

# S4.381 (spec twin) the text of a comment: `-m/--content` wins over the positional words, which are joined by one
# ASCII space and never trimmed before storage
def comment_text(given: Maybe<&2, String>, words: List<&2, String>) -> String:
  Maybe.default(&2, String, given, String.join(words, " "))

# S4.381 (spec twin) the positionals after the issue id
def after_first(words: List<&2, String>) -> List<&2, String>:
  match words:
    case Nil{}:
      Nil{}
    case Con{w, rest}:
      rest

# S4.380 S4.383 (spec twin) what `comments add` answered: the comment object under `--json`, the plain line
# otherwise, the store and the sidecar
def commented(d: Labels.Done, json: Bool, quiet: Bool) -> Outcome:
  match d json:
    case Labels.LabelBad{f} mode:
      failed(f, mode)
    case Labels.LabelOk{model, plain, entry, last, changed} True{}:
      wrote(entry, batch_changes(model, changed, last), quiet)
    case Labels.LabelOk{model, plain, entry, last, changed} False{}:
      wrote(plain, batch_changes(model, changed, last), quiet)

# S4.380 (spec twin) `comments add` once the issue's record is in hand
def comment_found(found: Maybe<&2, Model.Issue>, +model: List<&2, Model.Issue>, +id: String, author: String, text: Read, at: Time.Instant, json: Bool, quiet: Bool) -> Outcome:
  match found text:
    case None{} _:
      failed(Resolve.not_found(id), json)
    case Some{i} ReadBad{why}:
      failed(io_failure(why), json)
    case Some{i} ReadOk{+t}:
      commented(Labels.comment(model, i, author, t, at, String.is_empty(String.trim(t))), json, quiet)

# S4.381 (spec twin) the text source that wins: the file of `-f`, else `-m`, else the positional words
def comment_source(file: Maybe<&2, Read>, given: Maybe<&2, String>, words: List<&2, String>) -> Read:
  match file:
    case None{}:
      ReadOk{comment_text(given, words)}
    case Some{r}:
      r

# S4.380 S4.384 (spec twin) `comments add` once its issue is resolved; a missing text source is its own refusal,
# and a file that could not be read an `IO_ERROR` (after the issue resolved)
def comment_resolved(f: Resolve.Found, +model: List<&2, Model.Issue>, author: String, text: Read, at: Time.Instant, +json: Bool, quiet: Bool, none: Bool) -> Outcome:
  match f none:
    case Resolve.FoundBad{bad} _:
      failed(bad, json)
    case Resolve.FoundOk{id} True{}:
      failed(comment_required(), json)
    case Resolve.FoundOk{+id} False{}:
      comment_found(Blocked.lookup(model, id), model, id, author, text, at, json, quiet)

# S4.380–S4.385 (spec twin) `comments add <id> [text…]`; `-f -` (standard input) is not ported
def comment_cmd(now: Maybe<&2, Time.Instant>, +opts: List<&2, Cli.Occ>, words: List<&2, String>, +raw: List<&2, Model.Issue>, actor: String, +prefix: String, +json: Bool, quiet: Bool, later: Bool, file: Maybe<&2, Read>) -> Outcome:
  match now words later:
    case _ _ True{}:
      failed(unported(), json)
    case None{} _ False{}:
      failed(no_clock(), json)
    case Some{at} Con{first, +rest} False{}:
      comment_resolved(Resolve.resolve(Show.ids_of(raw), first, prefix), Store.model(raw), Maybe.default(&2, String, Cli.value(opts, "author"), actor), comment_source(file, Cli.value(opts, "message"), rest), at, json, quiet, (Bool.not(Cli.given(opts, "file")) && Bool.not(Cli.given(opts, "message")) && Bool.not(Nat.is_gt(List.length(&2, String, rest), 0n))))
    case Some{at} Nil{} False{}:
      failed(no_comment_id(), json)

# ---------------------------------------------------------------- epic close-eligible (S4.390–S4.393)

# S4.391 S4.393 (spec twin) one line per epic: a dry run names the title too, a real run the id alone
def epic_line(+i: Model.Issue, dry: Bool) -> String:
  Bool.pick(String, dry, "  - " ++ Render.inline(Model.id_of(i)) ++ ": " ++ Render.inline(Model.title_of(i)) ++ "\n", "  - " ++ Render.inline(Model.id_of(i)) ++ "\n")

# S4.391 S4.393 (spec twin) the lines of a batch, in the order `epic status` lists them
def epic_lines(epics: List<&2, Model.Issue>, +dry: Bool) -> String:
  match epics:
    case Nil{}:
      ""
    case Con{i, rest}:
      epic_line(i, dry) ++ epic_lines(rest, dry)

# S4.391 (spec twin) the JSON of a real run: the closed ids and their count
def epic_json(+ids: List<&2, String>) -> String:
  String.concat(["{\"closed\":[", String.join(Remove.quoted_all(ids), ","), "],\"count\":", Nat.show(List.length(&2, String, ids)), "}\n"])

# S4.393 (spec twin) `--dry-run` writes nothing: plain names the epics it would close, JSON is the epic-status
# list of the ELIGIBLE epics alone (`[]` when none, as `epic_close_eligible_dry_run_json` shows)
def epic_dry(+epics: List<&2, Model.Issue>, model: List<&2, Model.Issue>, json: Bool, +quiet: Bool) -> Outcome:
  Bool.pick(Outcome, json, viewed(Views.epic_status(model, True{}, True{}, False{}), True{}, quiet), printed("Would close " ++ Nat.show(List.length(&2, Model.Issue, epics)) ++ " epic(s):\n" ++ epic_lines(epics, True{}), "", quiet))

# S4.391 S4.392 (spec twin) a real run: nothing eligible prints its own line and writes nothing; otherwise every
# eligible epic is closed at one instant and the store is rewritten, but never `.beads/last-touched`
def epic_done(+model: List<&2, Model.Issue>, +epics: List<&2, Model.Issue>, +ids: List<&2, String>, now: Time.Instant, none: Bool, json: Bool, quiet: Bool, note: Maybe<&2, String>, actor: String) -> Outcome:
  match none json:
    case True{} True{}:
      printed("{\"closed\":[],\"count\":0}\n", "", quiet)
    case True{} False{}:
      printed("No epics eligible for closure\n", "", quiet)
    case False{} mode:
      wrote(Bool.pick(String, mode, epic_json(ids), "✓ Closed " ++ Nat.show(List.length(&2, Model.Issue, epics)) ++ " epic(s)\n" ++ epic_lines(epics, False{})), store_only(Status.epics_closed(model, ids, now, note, actor, (Status.max_comment_id(model, 0) + 1 : U32)), True{}), quiet)

# S4.390 (spec twin) `epic close-eligible` once the eligible epics are known
def epic_at(+epics: List<&2, Model.Issue>, model: List<&2, Model.Issue>, at: Time.Instant, json: Bool, quiet: Bool, dry: Bool, note: Maybe<&2, String>, actor: String) -> Outcome:
  match dry:
    case True{}:
      epic_dry(epics, model, json, quiet)
    case False{}:
      epic_done(model, epics, Show.ids_of(epics), at, Nat.is_eq(List.length(&2, Model.Issue, epics), 0n), json, quiet, note, actor)

# S4.390–S4.393 S4.396 (spec twin) `epic close-eligible`; `--transition-comment` comments on every epic it closes
def epic_close_cmd(now: Maybe<&2, Time.Instant>, +opts: List<&2, Cli.Occ>, +model: List<&2, Model.Issue>, +json: Bool, quiet: Bool, actor: String) -> Outcome:
  match now:
    case None{}:
      failed(no_clock(), json)
    case Some{at}:
      epic_at(Query.ordered(Views.epics_of(model, Work.child_index(False{}, model), True{}), 0, False{}), model, at, json, quiet, Cli.given(opts, "dry-run"), Cli.value(opts, "transition-comment"), actor)

# ---------------------------------------------------------------- delete (S4.330–S4.341)

# S4.340 S9.18 (spec twin) `delete` with no ids at all
def no_delete_ids() -> Failure.Failure:
  Create.invalid("ids", "no issue IDs provided")

# S4.210 S4.341 S5.18 (spec twin) the file changes of a delete: the store when a record actually changed (a
# second delete of the same id changes nothing), and the REMOVAL of `.beads/last-touched` when the id it names
# is one of the deleted ones
def delete_writes(+model: List<&2, Model.Issue>, deleted: List<&2, String>, +touched: String, +changed: Bool) -> List<&2, Write>:
  List.append(&2, Write, Bool.pick(List<&2, Write>, changed, Write{".beads/issues.jsonl", Some{Store.text(model)}} <> Nil{}, Nil{}), Bool.pick(List<&2, Write>, (Bool.not(String.is_empty(touched)) && Blocked.among(deleted, touched)), Write{".beads/last-touched", None{}} <> Nil{}, Nil{}))

# S4.333 S4.337 S4.338 (spec twin) what a delete answered: a preview writes nothing, a delete writes the store
def deleted_out(d: Remove.Done, +touched: String, json: Bool, quiet: Bool) -> Outcome:
  match d:
    case Remove.DelBad{f}:
      failed(f, json)
    case Remove.DelPreview{out}:
      printed(out, "", quiet)
    case Remove.DelDone{out, model, ids, changed}:
      wrote(out, delete_writes(model, ids, touched, changed), quiet)

# S4.333 S4.335 (spec twin) `delete` once its ids are resolved and its dependents are known
def delete_at(+model: List<&2, Model.Issue>, +ids: List<&2, String>, +direct: List<&2, String>, now: Time.Instant, actor: String, reason: String, +force: Bool, +cascade: Bool, +json: Bool, quiet: Bool, +dry: Bool, hard: Bool, +touched: String) -> Outcome:
  deleted_out(Remove.run(model, ids, direct, now, actor, reason, (Nat.is_gt(List.length(&2, String, direct), 0n) && Bool.not(force) && Bool.not(cascade)), force, cascade, json, dry, hard), touched, json, quiet)

# S4.332 (spec twin) `delete` once its ids are resolved
def delete_resolved(m: Resolve.Many, +model: List<&2, Model.Issue>, +opts: List<&2, Cli.Occ>, now: Time.Instant, actor: String, +json: Bool, quiet: Bool, touched: String) -> Outcome:
  match m:
    case Resolve.ManyBad{f}:
      failed(f, json)
    case Resolve.ManyOk{+ids}:
      delete_at(model, ids, Remove.dependents(model, ids), now, actor, Maybe.default(&2, String, Cli.value(opts, "reason"), "delete"), Cli.given(opts, "force"), Cli.given(opts, "cascade"), json, quiet, Cli.given(opts, "dry-run"), Cli.given(opts, "hard"), touched)

# S4.339 S4.340 (spec twin) `delete` with no ids: under `--hard` the purge of every tombstone, else the refusal
def delete_none(+model: List<&2, Model.Issue>, +opts: List<&2, Cli.Occ>, now: Time.Instant, +json: Bool, quiet: Bool, touched: String) -> Outcome:
  Bool.pick(Outcome, Cli.given(opts, "hard"), deleted_out(Remove.purge(model, now, json, Cli.given(opts, "dry-run")), touched, json, quiet), failed(no_delete_ids(), json))

# S4.340 (spec twin) keep one line of a `--from-file` as an id: trimmed, unless empty or a `#` comment
def id_line_put(+line: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, (String.is_empty(String.trim(line)) || String.starts_with(String.trim(line), "#")), rest, String.trim(line) <> rest)

# S4.340 (spec twin) the ids of the lines of a `--from-file`
def id_lines_kept(lines: List<&2, String>) -> List<&2, String>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{line, rest}:
      id_line_put(line, id_lines_kept(rest))

# S4.330–S4.340 (spec twin) `delete` once its ids are gathered: the ids are deduplicated and sorted ascending before
# resolution, so the command line's order never reaches the output
def delete_words(at: Time.Instant, +opts: List<&2, Cli.Occ>, words: List<&2, String>, +raw: List<&2, Model.Issue>, actor: String, +prefix: String, +json: Bool, quiet: Bool, touched: String) -> Outcome:
  match words:
    case Nil{}:
      delete_none(Store.model(raw), opts, at, json, quiet, touched)
    case Con{w, rest}:
      delete_resolved(Resolve.many(Model.dedup(List.sort(~String, ~String.is_le, w <> rest)), Show.ids_of(raw), prefix), Store.model(raw), opts, at, actor, json, quiet, touched)

# S4.330–S4.340 (spec twin) `delete`: the positional ids, then the ids of `--from-file`; a file that could not be
# read is an `IO_ERROR` before any id is resolved
def delete_cmd(now: Maybe<&2, Time.Instant>, +opts: List<&2, Cli.Occ>, words: List<&2, String>, +raw: List<&2, Model.Issue>, actor: String, +prefix: String, +json: Bool, quiet: Bool, touched: String, file: Maybe<&2, Read>) -> Outcome:
  match now file:
    case None{} _:
      failed(no_clock(), json)
    case Some{at} Some{ReadBad{why}}:
      failed(io_failure(why), json)
    case Some{at} Some{ReadOk{text}}:
      delete_words(at, opts, List.append(&2, String, words, id_lines_kept(String.split(text, Chr{10}))), raw, actor, prefix, json, quiet, touched)
    case Some{at} None{}:
      delete_words(at, opts, words, raw, actor, prefix, json, quiet, touched)

# S2.2 S2.4 S5.56 (spec twin) the workspace directory as discovery found it (`<root>/_beads`, or `BEADS_DIR` as
# given), which the shell passes as `BEADS_BEND_DIR`; `<root>/.beads` when it is not given (a law's inputs)
def beads_dir_of(+env: List<&2, Var>, +cwd: String) -> String:
  Bool.pick(String, String.is_empty(env_of(env, "BEADS_BEND_DIR")), cwd ++ "/.beads", env_of(env, "BEADS_BEND_DIR"))

# S1 S4 S5 (spec twin) one ported command on a loaded store. `show` reads the file's records as they are
# (S2.38, S2.39); every other command reads the loaded model (Store.model). `n` is the command's number
# (`command_number`); 0 is a command that is not ported, which answers the port's own failure
def command_at(n: U32, c: Call, issues: List<&2, Model.Issue>, +prefix: String) -> Outcome:
  match n c:
    case 1 Call{path, +opts, words, json, quiet, touched, env, cwd}:
      list_cmd(opts, Store.model(issues), json, quiet, False{}, Show.pinned(now_of(env)))
    case 2 Call{path, +opts, words, json, quiet, touched, env, cwd}:
      count_cmd(opts, Store.model(issues), json, quiet, Nat.is_gt(List.length(&2, String, selectors(opts)), 1n))
    case 3 Call{path, opts, words, +json, quiet, touched, +env, cwd}:
      shown(Show.run(words, issues, touched_text(Bytes.decode(touched)), env_of(env, "USER"), now_of(env), prefix, json), json, quiet)
    case 4 Call{path, +opts, +words, json, quiet, touched, env, cwd}:
      search_cmd(opts, Store.model(issues), first_word(words), json, quiet, String.is_empty(first_word(words)), U32.is_eq(Query.sort_key(Cli.value(opts, "sort")), 9))
    case 5 Call{path, +opts, words, json, quiet, touched, env, cwd}:
      ready_cmd(opts, Store.model(issues), env, json, quiet, prefix)
    case 6 Call{path, +opts, words, json, quiet, touched, env, cwd}:
      blocked_cmd(opts, Store.model(issues), json, quiet, Cli.given(opts, "detailed"))
    case 7 Call{path, +opts, words, json, quiet, touched, env, cwd}:
      stats_cmd(opts, Store.model(issues), env, json, quiet, Cli.given(opts, "activity"))
    case 8 Call{path, opts, words, json, quiet, touched, env, cwd}:
      dep_list_cmd(opts, Store.model(issues), first_word(words), prefix, json, quiet)
    case 9 Call{path, opts, words, json, quiet, touched, env, cwd}:
      dep_tree_cmd(opts, Store.model(issues), first_word(words), prefix, json, quiet)
    case 10 Call{path, +opts, words, +json, quiet, touched, env, cwd}:
      viewed(Views.dep_cycles(Store.model(issues), Cli.given(opts, "blocking-only"), Cli.given(opts, "include-closed"), json), json, quiet)
    case 11 Call{path, opts, words, json, quiet, touched, env, cwd}:
      label_list_cmd(Store.model(issues), words, prefix, json, quiet)
    case 12 Call{path, opts, words, +json, quiet, touched, env, cwd}:
      viewed(Views.label_list_all(Store.model(issues), json), json, quiet)
    case 13 Call{path, opts, words, json, quiet, touched, env, cwd}:
      comments_list_cmd(Store.model(issues), words, prefix, json, quiet)
    case 14 Call{path, opts, words, +json, quiet, touched, env, cwd}:
      viewed(Views.epic_status(Store.model(issues), Cli.given(opts, "eligible-only"), json, spec_of(env)), json, quiet)
    case 15 Call{path, opts, words, +json, quiet, touched, +env, +cwd}:
      viewed(Views.whereabouts(beads_dir_of(env, cwd), Prefix.reported(Prefix.configured(env_of(env, ".beads/config.yaml")), issues), json), json, quiet)
    case 16 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      create_cmd(Show.pinned(now_of(env)), opts, words, issues, env, cwd, json, quiet, (Cli.given(opts, "file") || Cli.given(opts, "agent-context")), False{})
    case 17 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      create_cmd(Show.pinned(now_of(env)), opts, words, issues, env, cwd, json, quiet, False{}, True{})
    case 19 Call{path, +opts, words, +json, quiet, touched, +env, cwd}:
      bypassed(bypass_refusal(opts), json, transition(0, Show.pinned(now_of(env)), False{}, Show.wanted(words, touched_text(Bytes.decode(touched))), opts, issues, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), prefix, json, quiet))
    case 20 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      transition(1, Show.pinned(now_of(env)), False{}, Show.wanted(words, touched_text(Bytes.decode(touched))), opts, issues, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), prefix, json, quiet)
    case 21 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      transition(2, Show.pinned(now_of(env)), False{}, words, opts, issues, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), prefix, json, quiet)
    case 22 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      transition(3, Show.pinned(now_of(env)), False{}, words, opts, issues, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), prefix, json, quiet)
    case 18 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      update_cmd(Show.pinned(now_of(env)), opts, Show.wanted(words, touched_text(Bytes.decode(touched))), issues, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), prefix, json, quiet, Cli.given(opts, "agent-context"), terminal_word(Model.lowered(String.trim(Maybe.default(&2, String, Cli.value(opts, "status"), "")))), file_read(env, Cli.value(opts, "description-file")))
    case 23 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      edge_cmd(True{}, Show.pinned(now_of(env)), opts, words, issues, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), prefix, json, quiet)
    case 24 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      edge_cmd(False{}, Show.pinned(now_of(env)), opts, words, issues, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), prefix, json, quiet)
    case 25 Call{path, opts, words, json, quiet, touched, +env, cwd}:
      label_cmd(True{}, Show.pinned(now_of(env)), opts, words, issues, prefix, json, quiet)
    case 26 Call{path, opts, words, json, quiet, touched, +env, cwd}:
      label_cmd(False{}, Show.pinned(now_of(env)), opts, words, issues, prefix, json, quiet)
    case 27 Call{path, opts, words, json, quiet, touched, +env, cwd}:
      rename_cmd(Show.pinned(now_of(env)), words, issues, json, quiet)
    case 28 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      comment_cmd(Show.pinned(now_of(env)), opts, words, issues, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), prefix, json, quiet, String.eq(Maybe.default(&2, String, Cli.value(opts, "file"), ""), "-"), file_read(env, Cli.value(opts, "file")))
    case 30 Call{path, +opts, words, json, quiet, touched, +env, cwd}:
      epic_close_cmd(Show.pinned(now_of(env)), opts, Store.model(issues), json, quiet, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")))
    case 29 Call{path, +opts, words, json, quiet, +touched, +env, cwd}:
      delete_cmd(Show.pinned(now_of(env)), opts, words, issues, actor_of(Cli.value(opts, "actor"), env_of(env, "USER")), prefix, json, quiet, touched_text(Bytes.decode(touched)), file_read(env, Cli.value(opts, "from-file")))
    case _ Call{path, opts, words, json, quiet, touched, env, cwd}:
      failed(unported(), json)

# S1 S4 S5 (spec twin) the words that name the command
def path_of(c: Call) -> String:
  match c:
    case Call{path, opts, words, json, quiet, touched, env, cwd}:
      path

# S1.16 (spec twin) the number `command_at` routes on: 0 for a command that is not ported yet
def command_number(+path: String) -> U32:
  Bool.pick(U32, String.eq(path, "list"), 1, Bool.pick(U32, String.eq(path, "count"), 2, Bool.pick(U32, String.eq(path, "show"), 3, Bool.pick(U32, String.eq(path, "search"), 4, Bool.pick(U32, String.eq(path, "ready"), 5, Bool.pick(U32, String.eq(path, "blocked"), 6, Bool.pick(U32, String.eq(path, "stats"), 7, Bool.pick(U32, String.eq(path, "dep list"), 8, Bool.pick(U32, String.eq(path, "dep tree"), 9, Bool.pick(U32, String.eq(path, "dep cycles"), 10, Bool.pick(U32, String.eq(path, "label list"), 11, Bool.pick(U32, String.eq(path, "label list-all"), 12, Bool.pick(U32, (String.eq(path, "comments list") || String.eq(path, "comments")), 13, Bool.pick(U32, String.eq(path, "epic status"), 14, Bool.pick(U32, String.eq(path, "where"), 15, Bool.pick(U32, String.eq(path, "create"), 16, Bool.pick(U32, String.eq(path, "q"), 17, Bool.pick(U32, String.eq(path, "update"), 18, Bool.pick(U32, String.eq(path, "close"), 19, Bool.pick(U32, String.eq(path, "reopen"), 20, Bool.pick(U32, String.eq(path, "defer"), 21, Bool.pick(U32, String.eq(path, "undefer"), 22, Bool.pick(U32, String.eq(path, "dep add"), 23, Bool.pick(U32, String.eq(path, "dep remove"), 24, Bool.pick(U32, String.eq(path, "label add"), 25, Bool.pick(U32, String.eq(path, "label remove"), 26, Bool.pick(U32, String.eq(path, "label rename"), 27, Bool.pick(U32, String.eq(path, "comments add"), 28, Bool.pick(U32, String.eq(path, "delete"), 29, Bool.pick(U32, String.eq(path, "epic close-eligible"), 30, 0))))))))))))))))))))))))))))))

# S2.18 (spec twin) the text of `.beads/config.yaml`, as the shell gathered it
def config_of(c: Call) -> String:
  match c:
    case Call{path, opts, words, json, quiet, touched, env, cwd}:
      env_of(env, ".beads/config.yaml")

# S4.190 S2.24 (spec twin) the kill-switch of a call: `BEADS_RUST_SPEC=1` runs every spec twin
def spec_call(c: Call) -> Bool:
  match c:
    case Call{path, opts, words, json, quiet, touched, env, cwd}:
      spec_of(env)

# S2.24 (spec twin) the store loaded by the spec loop or by its fast twin (parallel decode)
def load_chosen(spec: Bool, codes: List<&2, U32>, +path: String) -> Store.Loaded:
  match spec:
    case True{}:
      Store.load(codes, path)
    case False{}:
      Store.load_fast(codes, path)

# S2.12 (spec twin) the workspace directory of a call
def cwd_of(c: Call) -> String:
  match c:
    case Call{path, opts, words, json, quiet, touched, env, cwd}:
      cwd

# S5.20 (spec twin) whether a call answers in JSON
def json_of(c: Call) -> Bool:
  match c:
    case Call{path, opts, words, json, quiet, touched, env, cwd}:
      json

# S2.18 S8.13 (spec twin) a side file the shell read, as a named value the core can look up (`.beads/config.yaml`);
# a file that is absent, empty or not UTF-8 is the empty text
def file_var(name: String, bytes: List<&2, U32>) -> Var:
  Var{name, touched_text(Bytes.decode(bytes))}

# ---------------------------------------------------------------- workspace discovery (S2.1–S2.4)

# S2.2 (spec twin) the directory above one: `/a/b` → `/a`, `/a` → `` (the root)
def parent_dir(d: String) -> String:
  Prefix.cut_left(Resolve.cut_last(d, 47))

# S2.2 (spec twin) a directory and each ancestor up to the root, nearest first; the root is the empty text. The fuel
# is one per code point of the path plus one, and every step removes at least one
def ancestors(fuel: Nat, +dir: String) -> List<&2, String>:
  match fuel:
    case Zero{}:
      Nil{}
    case Succ{f}:
      dir <> Bool.pick(List<&2, String>, String.is_empty(dir), Nil{}, ancestors(f, parent_dir(dir)))

# S2.2 S2.3 (spec twin) the two names tested at each level, `.beads` before `_beads`
def beads_names(dirs: List<&2, String>) -> List<&2, String>:
  match dirs:
    case Nil{}:
      Nil{}
    case Con{+d, rest}:
      (d ++ "/.beads") <> (d ++ "/_beads") <> beads_names(rest)

# S2.4 (spec twin) `BEADS_DIR` as a path: an absolute value as given, a relative one against the working directory
def absolute(+path: String, +cwd: String) -> String:
  Bool.pick(String, String.starts_with(path, "/"), path, cwd ++ "/" ++ path)

# S2.1 S2.2 S2.4 (spec twin) the directories the shell tests, in order: `BEADS_DIR` alone when it does not trim to
# empty (it short-circuits the walk), else `.beads` and `_beads` at the working directory and at every ancestor. The
# `--db` and `BD_DB`-family overrides name a database, which `--no-db` never opens, and are not read
def discovery(+cwd: String, +beads_dir: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(String.trim(beads_dir)), beads_names(ancestors((String.length(cwd) + 1n : Nat), cwd)), absolute(String.trim(beads_dir), cwd) <> Nil{})

# S2.2 (spec twin) the first tested directory that opened; the empty text when none did (NOT_INITIALIZED, S2.8).
# Bend 2.0.20 has no directory test: the shell opens each path for reading, which succeeds on a directory and fails
# on a missing path on every engine (`port/probes/dir`); a regular FILE named `.beads` would also open
def found(dirs: List<&2, String>, oks: List<&2, Bool>) -> String:
  match dirs oks:
    case Con{d, drest} Con{ok, orest}:
      Bool.pick(String, ok, d, found(drest, orest))
    case _ _:
      ""

# S2.2 S2.12 (spec twin) the workspace root the core works in: the directory that holds `.beads` (the source path new
# records carry, and whose name gives the default prefix); the working directory when none was found
def root_of(+ws: String, cwd: String) -> String:
  Bool.pick(String, String.is_empty(ws), cwd, parent_dir(ws))

# S8.12 S8.13 (spec twin) a file inside the workspace directory; the empty path (which opens nothing) when there is none
def inside(+ws: String, name: String) -> String:
  Bool.pick(String, String.is_empty(ws), "", ws ++ "/" ++ name)

# S5.1 S8.30 (spec twin) where a file change lands: the core names `.beads/<file>`, the shell writes it inside the
# directory discovery found (which may be `_beads`, or `BEADS_DIR`)
def relocated(+ws: String, +path: String) -> String:
  Bool.pick(String, String.starts_with(path, ".beads/"), inside(ws, String.drop(path, 7n)), path)

# S2.10 S2.14 (spec twin) the command, once the prefix new ids take is known: a configured prefix that sanitizes to
# nothing refuses every command but `where`, which reports the raw value (`error_prefix_config_bad_list`,
# `prefix_config_bad_where`)
def prefixed(m: Prefix.Minted, +c: Call, issues: List<&2, Model.Issue>) -> Outcome:
  match m:
    case Prefix.MintOk{+prefix}:
      command_at(command_number(path_of(c)), c, issues, prefix)
    case Prefix.MintBad{raw}:
      Bool.pick(Outcome, String.eq(path_of(c), "where"), command_at(15, c, issues, ""), failed(Prefix.refusal(raw), json_of(c)))

# S1 S4 S5 S2.10 (spec twin, dispatcher) the command a loaded store reaches, once the prefix new ids take is known
def command(+c: Call, +issues: List<&2, Model.Issue>) -> Outcome:
  prefixed(Prefix.minted(Prefix.configured(config_of(c)), issues, cwd_of(c)), c, issues)

# S2.26 S2.27 (spec twin) a loaded store: a refusal is the outcome; a good store reaches the command
def loaded(st: Store.Loaded, +c: Call) -> Outcome:
  match st:
    case Store.LoadBad{f}:
      failed(f, wants_json(c))
    case Store.LoadOk{issues}:
      command(c, issues)

# S2.24 (spec twin) the store's bytes as code points, then as records
def decoded(d: Bytes.Decoded, path: String, +c: Call) -> Outcome:
  match d:
    case Bytes.NotUtf8{}:
      failed(not_utf8(), wants_json(c))
    case Bytes.Utf8{codes}:
      loaded(load_chosen(spec_call(c), codes, path), c)

# S2.1 S9.8 (spec twin) route on the workspace verdict; the store path the messages quote is absolute
def routed(workspace: Bool, +c: Call, cwd: String, store: List<&2, U32>) -> Outcome:
  match workspace:
    case False{}:
      failed(Failure.not_initialized(), wants_json(c))
    case True{}:
      decoded(Bytes.decode(store), cwd ++ "/.beads/issues.jsonl", c)

# S1.29 S1.89 (spec twin) a help request: the text on stdout, exit 0. A level whose help text the port does
# not carry answers with the port's own refusal (PLAN §3: help texts beyond the captured ones are excluded)
def helped(text: String) -> Outcome:
  match text:
    case SNil{}:
      failed(unported(), False{})
    case SCon{h, t}:
      Outcome{SCon{h, t}, "", 0, Nil{}}

# S5.200 S5.201 DISC-006 (spec twin) the port's own identity. The original's `version` prints build metadata of a
# different program (a Rust toolchain, a target triple, a git branch); printing those bytes would be a false
# statement about the binary that is running, so the port names itself, the Bend it was built with and the
# original it ports. The three captured cases are compared through the shape canonicalizer of DISC-006
def port_name() -> String:
  "bn"

# S5.200 DISC-006 (spec twin) the port's version, chosen 2026-09-20: nothing is released yet
def port_version() -> String:
  "0.1.0"

# S5.201 DISC-006 (spec twin) the pinned toolchain and oracle the version report names
def port_bend() -> String:
  "2.0.20"

# S5.201 DISC-006 (spec twin) `<name> version <version> (bend <bend>) (port of br 0.6.0@<commit>)`
def version_plain() -> String:
  String.concat([port_name(), " version ", port_version(), " (bend ", port_bend(), ") (port of br 0.6.0@b1cfebe)\n"])

# S5.202 DISC-006 (spec twin) the JSON report: one compact object, the members in this order
def version_json() -> String:
  String.concat(["{\"version\":", Failure.quoted(port_version()), ",\"build\":\"bend\",\"bend_version\":", Failure.quoted(port_bend()), ",\"port_of\":\"br 0.6.0\",\"oracle_commit\":\"b1cfebe05437463e91a353cf2bedafac27266f5b\",\"features\":[]}\n"])

# S5.107 DISC-006 (spec twin) `version` needs no workspace and no store; Quiet prints nothing
def version_out(json: Bool, quiet: Bool) -> Outcome:
  printed(Bool.pick(String, json, version_json(), version_plain()), "", quiet)

# S1.28 DISC-006 (spec twin) the top-level `--version` / `-V` flag: the name and the version alone
def version_flag() -> Outcome:
  Outcome{port_name() ++ " " ++ port_version() ++ "\n", "", 0, Nil{}}

# S1.16 (spec twin) a command of the original that is outside the port's `--no-db` surface (PLAN §3): the port's own words, exit 1
def outside(word: String) -> Outcome:
  Outcome{"", "Error: `" ++ word ++ "` is outside beads_bend's --no-db surface (docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md §3)\n", 1, Nil{}}

# S1.30 S1.6 (spec twin) the argument parser's answer decides first: its refusals never reach the
# workspace (exit 2, stderr only, whatever the output mode). JSON mode is `--json` or a command's `--robot`
def ran(p: Cli.Parsed, workspace: Bool, +cwd: String, store: List<&2, U32>, touched: List<&2, U32>, env: List<&2, Var>) -> Outcome:
  match p:
    case Cli.Refused{err}:
      Outcome{"", err, 2, Nil{}}
    case Cli.Helped{path, long}:
      helped(Help.text(path, long))
    case Cli.GroupHelp{path}:
      Outcome{"", Help.text(path, True{}), 2, Nil{}}
    case Cli.Versioned{}:
      version_flag()
    case Cli.Outside{word}:
      outside(word)
    case Cli.Command{+path, +opts, words}:
      Bool.pick(Outcome, String.eq(path, "version"), version_out((Cli.given(opts, "json") || Cli.given(opts, "robot")), (Cli.given(opts, "quiet") && Bool.not((Cli.given(opts, "json") || Cli.given(opts, "robot"))))), routed(workspace, Call{path, opts, words, (Cli.given(opts, "json") || Cli.given(opts, "robot")), (Cli.given(opts, "quiet") && Bool.not((Cli.given(opts, "json") || Cli.given(opts, "robot")))), touched, env, cwd}, cwd, store))

# S1 S4 S5 S9 (spec twin, dispatcher) the single entry the shell calls
def outcome(inputs: Inputs) -> Outcome:
  match inputs:
    case Inputs{argv, workspace, cwd, store, touched, env}:
      ran(Cli.parse(argv), workspace, cwd, store, touched, env)
