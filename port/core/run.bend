# core/run — the pure program: Inputs -> Outcome (docs/PROPOSED_ARCHITECTURE.md).
# The shell gathers the inputs with one effect each, calls `outcome` once and
# performs what it answers. Nothing here mentions IO or consults the original.
import Base
import ./failure.bend as Failure
import ./bytes.bend as Bytes
import ./store.bend as Store
import ./cli.bend as Cli
import ./help.bend as Help

# S8.1 S8.12 S8.13 (data) what the shell gathered: argv, whether a `.beads` workspace was found, the
# working directory, and the BYTES of `.beads/issues.jsonl` (empty when there is no workspace)
type Inputs is Data:
  Inputs{argv: List<&2, String>, workspace: Bool, cwd: String, store: List<&2, U32>}

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

# S2.26 S2.27 (spec twin) a loaded store: a refusal is the outcome; a good store reaches commands that are not ported yet
def loaded(st: Store.Loaded, json: Bool) -> Outcome:
  match st:
    case Store.LoadBad{f}:
      failed(f, json)
    case Store.LoadOk{issues}:
      failed(unported(), json)

# S2.24 (spec twin) the store's bytes as code points, then as records
def decoded(d: Bytes.Decoded, path: String, json: Bool) -> Outcome:
  match d:
    case Bytes.NotUtf8{}:
      failed(not_utf8(), json)
    case Bytes.Utf8{codes}:
      loaded(Store.load(codes, path), json)

# S2.1 S9.8 (spec twin) route on the workspace verdict; the store path the messages quote is absolute
def routed(workspace: Bool, json: Bool, cwd: String, store: List<&2, U32>) -> Outcome:
  match workspace:
    case False{}:
      failed(Failure.not_initialized(), json)
    case True{}:
      decoded(Bytes.decode(store), cwd ++ "/.beads/issues.jsonl", json)

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
def ran(p: Cli.Parsed, workspace: Bool, cwd: String, store: List<&2, U32>) -> Outcome:
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
      routed(workspace, (Cli.given(opts, "json") || Cli.given(opts, "robot")), cwd, store)

# S1 S4 S5 S9 (spec twin, dispatcher) the single entry the shell calls
def outcome(inputs: Inputs) -> Outcome:
  match inputs:
    case Inputs{argv, workspace, cwd, store}:
      ran(Cli.parse(argv), workspace, cwd, store)
