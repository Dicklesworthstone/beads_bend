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
# the actor ladders (S1.64, S1.65), the output format (S1.61), and the pinned instant of DISC-001
def env_names() -> List<&2, String>:
  ["USER", "BD_ACTOR", "BEADS_ACTOR", "LOGNAME", "USERNAME", "BR_OUTPUT_FORMAT", "TOON_DEFAULT_FORMAT", "BEADS_BEND_NOW"]

# S8.5 (spec twin) the value of a variable; one that is not set, or was not read, is the empty string
def env_of(env: List<&2, Var>, +name: String) -> String:
  match env:
    case Nil{}:
      ""
    case Con{Var{n, v}, rest}:
      Bool.pick(String, String.eq(n, name), v, env_of(rest, name))

# S8.34 S8.36 (data) what the shell must do: the bytes for stdout, the bytes for stderr, the exit code
type Outcome is Data:
  Outcome{out: String, err: String, code: U32}

# S9.1 S9.2 (spec twin) a failure as an outcome: JSON mode writes the envelope to
# STDOUT and nothing to stderr; plain mode writes `Error:` / `Hint:` to STDERR
def failed(+f: Failure.Failure, json: Bool) -> Outcome:
  match json:
    case True{}:
      Outcome{Failure.json_text(f), "", Failure.exit_of(f)}
    case False{}:
      Outcome{"", Failure.plain_text(f), Failure.exit_of(f)}

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
      Outcome{"", "", 0}
    case False{}:
      Outcome{out, note, 0}

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
      printed(Render.list_plain(Query.page(rows, offset, limit), Cli.given(opts, "long")), Render.truncation_note(Query.has_more(List.length(&2, Model.Issue, rows), offset, limit), outside_query(opts), List.length(&2, Model.Issue, Query.page(rows, offset, limit)), List.length(&2, Model.Issue, rows)), quiet)

# S4.118 (spec twin) `list` once its filter is built: the sort key is judged next (9 is a key nobody knows)
def list_sorted(+key: U32, f: Query.Filter, +opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, json: Bool, quiet: Bool, bad: Bool) -> Outcome:
  match bad:
    case True{}:
      failed(Query.bad_sort(Maybe.default(&2, String, Cli.value(opts, "sort"), "")), json)
    case False{}:
      list_page(Query.ordered(Query.kept(issues, f), key, Cli.given(opts, "reverse")), issues, opts, Query.count_of(Cli.value(opts, "limit")), Query.count_of(Cli.value(opts, "offset")), json, quiet)

# S4.105 S4.107 S4.108 (spec twin) `list` once its options were judged
def list_built(b: Query.Built, +opts: List<&2, Cli.Occ>, issues: List<&2, Model.Issue>, json: Bool, quiet: Bool) -> Outcome:
  match b:
    case Query.BuildBad{f}:
      failed(f, json)
    case Query.BuildOk{f}:
      list_sorted(Query.sort_key(Cli.value(opts, "sort")), f, opts, issues, json, quiet, U32.is_eq(Query.sort_key(Cli.value(opts, "sort")), 9))

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

# S4.132 S5.127 S5.128 (spec twin) `list`; its `--overdue` (which needs the clock), `--tree` and `--pretty` are not ported yet
def list_cmd(+opts: List<&2, Cli.Occ>, +issues: List<&2, Model.Issue>, json: Bool, quiet: Bool, later: Bool) -> Outcome:
  match later:
    case True{}:
      failed(unported(), json)
    case False{}:
      list_built(Query.build(opts, issues, True{}, False{}), opts, issues, json, quiet)

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

# S2.10 (spec twin) the workspace's default prefix: the name of the workspace directory. The `issue_prefix` of
# `.beads/config.yaml` and the directory-name rules of S2.11–S2.15 are not read yet (backlog E3.2)
def prefix_of(cwd: String) -> String:
  Resolve.remainder_of(Resolve.cut_last(cwd, 47))

# S5.105 S5.155 (spec twin) what `show` answered, as an outcome
def shown(s: Show.Shown, json: Bool, quiet: Bool) -> Outcome:
  match s:
    case Show.ShowBad{f}:
      failed(f, json)
    case Show.ShowOk{out}:
      printed(out, "", quiet)

# S1 S4 S5 (spec twin) route on the command's words. `list` and `count` read the loaded model (Store.model);
# `show` reads the file's records as they are (S2.38, S2.39)
def command_pick(is_list: Bool, is_count: Bool, is_show: Bool, is_search: Bool, c: Call, issues: List<&2, Model.Issue>) -> Outcome:
  match is_list is_count is_show is_search c:
    case True{} _ _ _ Call{path, +opts, words, json, quiet, touched, env, cwd}:
      list_cmd(opts, Store.model(issues), json, quiet, (Cli.given(opts, "overdue") || Cli.given(opts, "tree") || Cli.given(opts, "pretty")))
    case False{} True{} _ _ Call{path, +opts, words, json, quiet, touched, env, cwd}:
      count_cmd(opts, Store.model(issues), json, quiet, Nat.is_gt(List.length(&2, String, selectors(opts)), 1n))
    case False{} False{} True{} _ Call{path, opts, words, +json, quiet, touched, +env, cwd}:
      shown(Show.run(words, issues, touched_text(Bytes.decode(touched)), env_of(env, "USER"), env_of(env, "BEADS_BEND_NOW"), prefix_of(cwd), json), json, quiet)
    case False{} False{} False{} True{} Call{path, +opts, +words, json, quiet, touched, env, cwd}:
      search_cmd(opts, Store.model(issues), first_word(words), json, quiet, String.is_empty(first_word(words)), U32.is_eq(Query.sort_key(Cli.value(opts, "sort")), 9))
    case False{} False{} False{} False{} Call{path, opts, words, json, quiet, touched, env, cwd}:
      failed(unported(), json)

# S1 S4 S5 (spec twin) the words that name the command
def path_of(c: Call) -> String:
  match c:
    case Call{path, opts, words, json, quiet, touched, env, cwd}:
      path

# S1 S4 S5 (spec twin, dispatcher) the command a loaded store reaches; a command that is not ported answers the port's own failure
def command(+c: Call, issues: List<&2, Model.Issue>) -> Outcome:
  command_pick(String.eq(path_of(c), "list"), String.eq(path_of(c), "count"), String.eq(path_of(c), "show"), String.eq(path_of(c), "search"), c, issues)

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
      loaded(Store.load(codes, path), c)

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
      Outcome{SCon{h, t}, "", 0}

# S1.16 (spec twin) a command of the original that is outside the port's `--no-db` surface (PLAN §3): the port's own words, exit 1
def outside(word: String) -> Outcome:
  Outcome{"", "Error: `" ++ word ++ "` is outside beads_bend's --no-db surface (docs/PLAN_TO_PORT_BEADS_RUST_TO_BEND2.md §3)\n", 1}

# S1.30 S1.6 (spec twin) the argument parser's answer decides first: its refusals never reach the
# workspace (exit 2, stderr only, whatever the output mode). JSON mode is `--json` or a command's `--robot`
def ran(p: Cli.Parsed, workspace: Bool, +cwd: String, store: List<&2, U32>, touched: List<&2, U32>, env: List<&2, Var>) -> Outcome:
  match p:
    case Cli.Refused{err}:
      Outcome{"", err, 2}
    case Cli.Helped{path, long}:
      helped(Help.text(path, long))
    case Cli.GroupHelp{path}:
      Outcome{"", Help.text(path, True{}), 2}
    case Cli.Versioned{}:
      failed(unported(), False{})
    case Cli.Outside{word}:
      outside(word)
    case Cli.Command{path, +opts, words}:
      routed(workspace, Call{path, opts, words, (Cli.given(opts, "json") || Cli.given(opts, "robot")), (Cli.given(opts, "quiet") && Bool.not((Cli.given(opts, "json") || Cli.given(opts, "robot")))), touched, env, cwd}, cwd, store)

# S1 S4 S5 S9 (spec twin, dispatcher) the single entry the shell calls
def outcome(inputs: Inputs) -> Outcome:
  match inputs:
    case Inputs{argv, workspace, cwd, store, touched, env}:
      ran(Cli.parse(argv), workspace, cwd, store, touched, env)
