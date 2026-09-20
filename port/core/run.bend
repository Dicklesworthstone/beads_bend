# core/run — the pure program: Inputs -> Outcome (docs/PROPOSED_ARCHITECTURE.md).
# The shell gathers the inputs with one effect each, calls `outcome` once and
# performs what it answers. Nothing here mentions IO or consults the original.
import Base
import ./failure.bend as Failure
import ./bytes.bend as Bytes
import ./store.bend as Store

# S8.1 S8.12 S8.13 (data) what the shell gathered: argv, whether a `.beads` workspace was found, the
# working directory, and the BYTES of `.beads/issues.jsonl` (empty when there is no workspace)
type Inputs is Data:
  Inputs{argv: List<&2, String>, workspace: Bool, cwd: String, store: List<&2, U32>}

# S8.34 S8.36 (data) what the shell must do: the bytes for stdout, the bytes for stderr, the exit code
type Outcome is Data:
  Outcome{out: String, err: String, code: U32}

# S1.8 (spec twin) is this exact word among the arguments
def has_word(argv: List<&2, String>, +word: String) -> Bool:
  match argv:
    case Nil{}:
      False{}
    case Con{arg, rest}:
      (String.eq(arg, word) || has_word(rest, word))

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

# S1 S4 S5 S9 (spec twin, dispatcher) the single entry the shell calls
def outcome(inputs: Inputs) -> Outcome:
  match inputs:
    case Inputs{argv, workspace, cwd, store}:
      routed(workspace, has_word(argv, "--json"), cwd, store)
