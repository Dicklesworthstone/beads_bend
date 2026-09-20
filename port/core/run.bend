# core/run — the pure program: Inputs -> Outcome (docs/PROPOSED_ARCHITECTURE.md).
# The shell gathers the inputs with one effect each, calls `outcome` once and
# performs what it answers. Nothing here mentions IO or consults the original.
import Base
import ./failure.bend as Failure

# S8.1 S8.12 (data) what the shell gathered: argv, and whether a `.beads` workspace was found
type Inputs is Data:
  Inputs{argv: List<&2, String>, workspace: Bool}

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

# S2.1 S9.8 (spec twin) route on the workspace verdict
def routed(workspace: Bool, json: Bool) -> Outcome:
  match workspace:
    case False{}:
      failed(Failure.not_initialized(), json)
    case True{}:
      failed(unported(), json)

# S1 S4 S5 S9 (spec twin, dispatcher) the single entry the shell calls
def outcome(inputs: Inputs) -> Outcome:
  match inputs:
    case Inputs{argv, workspace}:
      routed(workspace, has_word(argv, "--json"))
