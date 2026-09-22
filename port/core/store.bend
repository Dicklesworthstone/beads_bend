# core/store — the text of .beads/issues.jsonl as records, and back (S2.24–S2.27, S5.2–S5.3).
# Loading: split into lines, trim each, refuse the whole file on a git
# conflict marker (before any JSON is parsed) or on a line that is not a
# record, skip blank lines while still counting them. Writing: one
# Model.line per record, by id in byte order, each ended by one newline.
# `load` answers the file's records AS THEY ARE (what `show` reads, S2.38–S2.39);
# `model` answers the loaded model: every record through the repairs of S2.31–
# S2.36 and S5.9 (core/model `repaired`), ephemeral records dropped (S2.42).
# Not here yet, and stated so nothing is assumed: the duplicate-id refusal of
# S2.40 and the validation of S2.43–S2.56. Nothing here consults the original.
import Base
import ./json.bend as Json
import ./model.bend as Model
import ./decode.bend as Decode
import ./failure.bend as Failure

# S2.24 (spec twin) the file's code points as lines, split at `\n` (10); cur and out are REVERSED.
# A final line without a newline is a line; the empty tail after a final newline is a blank line.
def lines_go(cs: List<&2, U32>, cur: List<&2, U32>, out: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match cs:
    case Nil{}:
      List.reverse(&2, List<&2, U32>, List.reverse(&2, U32, cur) <> out)
    case Con{10, rest}:
      lines_go(rest, Nil{}, List.reverse(&2, U32, cur) <> out)
    case Con{c, rest}:
      lines_go(rest, c <> cur, out)

# S2.24 (spec twin) leading whitespace removed: space, tab, line feed, vertical tab, form feed, carriage return
def trim_start(cs: List<&2, U32>) -> List<&2, U32>:
  match cs:
    case Con{32, rest}:
      trim_start(rest)
    case Con{9, rest}:
      trim_start(rest)
    case Con{10, rest}:
      trim_start(rest)
    case Con{11, rest}:
      trim_start(rest)
    case Con{12, rest}:
      trim_start(rest)
    case Con{13, rest}:
      trim_start(rest)
    case other:
      other

# S2.24 (spec twin) a line trimmed at both ends, so `\r\n` and stray blanks are tolerated
def trim(cs: List<&2, U32>) -> List<&2, U32>:
  List.reverse(&2, U32, trim_start(List.reverse(&2, U32, trim_start(cs))))

# S2.27 (spec twin) a line's length in UTF-8 BYTES: the column serde_json reports at an early end
def byte_len(cs: List<&2, U32>, acc: U32) -> U32:
  match cs:
    case Nil{}:
      acc
    case Con{c, rest}:
      byte_len(rest, (acc + Json.width(c) : U32))

# S2.26 (data) what a trimmed line is, as far as git conflict markers go; a label is the rest of the line
type Marker is Data:
  NoMarker{}
  MarkStart{label: List<&2, U32>}
  MarkSep{}
  MarkEnd{label: List<&2, U32>}

# S2.26 (spec twin) a marker is a trimmed line that STARTS with seven `<` (60), `=` (61) or `>` (62)
def marker_of(cs: List<&2, U32>) -> Marker:
  match cs:
    case Con{60, Con{60, Con{60, Con{60, Con{60, Con{60, Con{60, rest}}}}}}}:
      MarkStart{trim(rest)}
    case Con{61, Con{61, Con{61, Con{61, Con{61, Con{61, Con{61, rest}}}}}}}:
      MarkSep{}
    case Con{62, Con{62, Con{62, Con{62, Con{62, Con{62, Con{62, rest}}}}}}}:
      MarkEnd{trim(rest)}
    case other:
      NoMarker{}

# S2.26 (spec twin) a code-point list as a String, in order
def text_in_order(cs: List<&2, U32>) -> String:
  match cs:
    case Nil{}:
      ""
    case Con{c, rest}:
      SCon{Chr{c}, text_in_order(rest)}

# S2.26 (spec twin) one report line: `<path>:<n> Start (<label>)`, `<path>:<n> Separator`, `<path>:<n> End (<label>)`
def marker_line(m: Marker, path: String, n: U32) -> String:
  match m:
    case NoMarker{}:
      ""
    case MarkStart{label}:
      path ++ ":" ++ U32.show(n) ++ " Start (" ++ text_in_order(label) ++ ")\n"
    case MarkSep{}:
      path ++ ":" ++ U32.show(n) ++ " Separator\n"
    case MarkEnd{label}:
      path ++ ":" ++ U32.show(n) ++ " End (" ++ text_in_order(label) ++ ")\n"

# S2.26 (spec twin) the report lines of every marker in the file, in file order; n is the 1-based line number
# The report lines are collected REVERSED and concatenated once (appending to a growing string re-walks it).
def markers_go(ls: List<&2, List<&2, U32>>, +path: String, +n: U32, acc: List<&2, String>) -> String:
  match ls:
    case Nil{}:
      String.concat(List.reverse(&2, String, acc))
    case Con{l, rest}:
      markers_go(rest, path, (n + 1 : U32), marker_line(marker_of(trim(l)), path, n) <> acc)

# S2.26 S9 (spec twin) the refusal for conflict markers: CONFIG_ERROR, exit 7, no hint, no context
def conflict(path: String, report: String) -> Failure.Failure:
  Failure.Failure{"CONFIG_ERROR", "Configuration error: Merge conflict markers detected in " ++ path ++ ".\n" ++ report ++ "Resolve conflicts before importing.", None{}, False{}, Nil{}, 7}

# S2.27 S9 (spec twin) the refusal for a line that is not a record: CONFIG_ERROR, exit 7
def invalid_json(n: U32, msg: String, col: U32) -> Failure.Failure:
  Failure.Failure{"CONFIG_ERROR", "Configuration error: Invalid JSON at line " ++ U32.show(n) ++ ": " ++ msg ++ " at line 1 column " ++ U32.show(col), None{}, False{}, Nil{}, 7}

# S2.24 (data) the records of a store, or the refusal of the whole load
type Loaded is Data:
  LoadBad{failure: Failure.Failure}
  LoadOk{issues: List<&2, Model.Issue>}

# S2.27 (spec twin) fold one decoded line in; a refusal is sticky; acc is REVERSED
def keep(st: Loaded, d: Decode.Dec, n: U32) -> Loaded:
  match st d:
    case LoadBad{f} _:
      LoadBad{f}
    case LoadOk{sofar} Decode.DecOk{i}:
      LoadOk{i <> sofar}
    case LoadOk{sofar} Decode.DecBad{msg, col}:
      LoadBad{invalid_json(n, msg, col)}

# S2.24 (spec twin) a line that is empty after trimming is skipped but still counted
def line_step(st: Loaded, +l: List<&2, U32>, n: U32) -> Loaded:
  match l:
    case Nil{}:
      st
    case Con{c, rest}:
      keep(st, Decode.issue_of(l, byte_len(l, 0)), n)

# S2.24 S2.27 (spec twin) the loop over the lines; n is the 1-based line number
def records_go(ls: List<&2, List<&2, U32>>, +n: U32, st: Loaded) -> Loaded:
  match ls:
    case Nil{}:
      st
    case Con{l, rest}:
      records_go(rest, (n + 1 : U32), line_step(st, trim(l), n))

# S2.24 (spec twin) put the records back in file order
def in_file_order(st: Loaded) -> Loaded:
  match st:
    case LoadBad{f}:
      LoadBad{f}
    case LoadOk{sofar}:
      LoadOk{List.reverse(&2, Model.Issue, sofar)}

# ---------------------------------------------------------------- the fast twin of the record loop

# S2.24 (data) one trimmed line decoded on its own: blank, or the decoder's verdict
type Step is Data:
  Blank{}
  Line{dec: Decode.Dec}

# S2.24 S2.27 (fast twin) one trimmed line decoded on its own
def step_of(+l: List<&2, U32>) -> Step:
  match l:
    case Nil{}:
      Blank{}
    case Con{c, rest}:
      Line{Decode.issue_of(l, byte_len(l, 0))}

# S2.24 (fast twin) every line trimmed and decoded, in order, one after another
def steps_seq(ls: List<&2, List<&2, U32>>) -> List<&2, Step>:
  match ls:
    case Nil{}:
      Nil{}
    case Con{l, rest}:
      step_of(trim(l)) <> steps_seq(rest)

# S2.24 (fast twin) the same decoded lines through a balanced fork tree `depth` levels deep: each half is decoded
# as its own task (a parallel let; `--threads N` runs them side by side), and the halves are joined in order
def steps_par(+depth: Nat, +ls: List<&2, List<&2, U32>>, +n: Nat) -> List<&2, Step>:
  match depth:
    case 0n:
      steps_seq(ls)
    case 1n+d:
      a b = steps_par(d, List.take(&2, List<&2, U32>, ls, Nat.div(n, 2n)), Nat.div(n, 2n)) steps_par(d, List.drop(&2, List<&2, U32>, ls, Nat.div(n, 2n)), Nat.sub(n, Nat.div(n, 2n)))
      List.append(&2, Step, a, b)

# S2.24 S2.27 (fast twin) one decoded line folded in: a blank line counts but adds nothing
def step_keep(st: Loaded, s: Step, n: U32) -> Loaded:
  match s:
    case Blank{}:
      st
    case Line{d}:
      keep(st, d, n)

# S2.24 S2.27 (fast twin) the fold over the decoded lines, exactly the spec loop's: a refusal is sticky and names
# its 1-based line
def fold_steps(steps: List<&2, Step>, +n: U32, st: Loaded) -> Loaded:
  match steps:
    case Nil{}:
      st
    case Con{s, rest}:
      fold_steps(rest, (n + 1 : U32), step_keep(st, s, n))

# S2.26 (fast twin) as `guarded`, the lines decoded in parallel before the fold (16 tasks)
def guarded_fast(+ls: List<&2, List<&2, U32>>, path: String, report: String) -> Loaded:
  match report:
    case SNil{}:
      in_file_order(fold_steps(steps_par(4n, ls, List.length(&2, List<&2, U32>, ls)), 1, LoadOk{Nil{}}))
    case SCon{h, t}:
      LoadBad{conflict(path, SCon{h, t})}

# S2.26 (fast twin) the lines split once and read twice, as in `load_lines`
def load_fast_lines(+ls: List<&2, List<&2, U32>>, +path: String) -> Loaded:
  guarded_fast(ls, path, markers_go(ls, path, 1, Nil{}))

# S2.24 S2.26 S2.27 (fast twin) `load` with the parallel decode; bound to `load` by the closed laws
# `store_load_fast_basic`, `store_load_fast_precision` and `store_load_fast_refusal`; `BEADS_RUST_SPEC=1` selects `load`
def load_fast(cs: List<&2, U32>, +path: String) -> Loaded:
  load_fast_lines(lines_go(cs, Nil{}, Nil{}), path)

# S2.26 (spec twin) markers refuse the load before any line is parsed as JSON
def guarded(+ls: List<&2, List<&2, U32>>, path: String, report: String) -> Loaded:
  match report:
    case SNil{}:
      in_file_order(records_go(ls, 1, LoadOk{Nil{}}))
    case SCon{h, t}:
      LoadBad{conflict(path, SCon{h, t})}

# S2.26 (spec twin) the lines are split once and read twice: by the marker scan, then by the record loop
def load_lines(+ls: List<&2, List<&2, U32>>, +path: String) -> Loaded:
  guarded(ls, path, markers_go(ls, path, 1, Nil{}))

# S2.24 S2.26 S2.27 (spec twin) the store from the file's code points; `path` is the absolute store path the messages quote
def load(cs: List<&2, U32>, path: String) -> Loaded:
  load_lines(lines_go(cs, Nil{}, Nil{}), path)

# S2.26 S2.27 S9.2 (spec twin) what a load prints on stderr in plain mode: the refusal, or nothing
def refusal(st: Loaded) -> String:
  match st:
    case LoadBad{f}:
      Failure.plain_text(f)
    case LoadOk{issues}:
      ""


# S2.42 (spec twin) keep a record that is not ephemeral
def model_put(i: Model.Issue, ephemeral: Bool, rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match ephemeral:
    case True{}:
      rest
    case False{}:
      i <> rest

# S2.42 (spec twin) one repaired record joins the model unless it is ephemeral
def model_one(+i: Model.Issue, rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  model_put(i, Model.is_ephemeral(i), rest)

# S2.36 S2.42 (spec twin) the loaded MODEL of a store: every record repaired, and the ephemeral ones (after the
# repair that marks a `-wisp-` id) dropped. `show` does not read this: it reads the file's records as they are (S2.38, S2.39)
def model(issues: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{i, rest}:
      model_one(Model.repaired(i), model(rest))

# S5.3 (spec twin) the order of the written lines: ascending BYTE order of the id
def id_le(x: Model.Issue, y: Model.Issue) -> Bool:
  String.is_le(Model.id_of(x), Model.id_of(y))

# S5.2 (spec twin) one line per record, each ended by one newline; the pieces are collected and concatenated once
def text_lines(issues: List<&2, Model.Issue>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{i, rest}:
      Model.line(Model.written(i)) <> "\n" <> text_lines(rest)

# S5.16 (spec twin) keep a record the file holds: not ephemeral, and no `-wisp-` in its id
def text_put(i: Model.Issue, keep: Bool, rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match keep:
    case True{}:
      i <> rest
    case False{}:
      rest

# S5.16 (spec twin) the records the file holds
def text_kept(issues: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      text_put(i, (Bool.not(Model.is_ephemeral(i)) && Bool.not(String.contains(Model.id_of(i), "-wisp-"))), text_kept(rest))

# S5.1–S5.3 S5.16 (spec twin) the whole text of `.beads/issues.jsonl` for a model: every kept record re-rendered
# (so records a command never named are normalized too), ascending by id bytes; zero records are zero bytes
def text(issues: List<&2, Model.Issue>) -> String:
  String.concat(text_lines(List.sort(~Model.Issue, ~id_le, text_kept(issues))))

# S5.1 (spec twin) what a write-back that changes no record leaves in the file: the loaded store rendered again; a
# refused load renders nothing
def rewritten(st: Loaded) -> String:
  match st:
    case LoadBad{f}:
      ""
    case LoadOk{issues}:
      text(model(issues))
