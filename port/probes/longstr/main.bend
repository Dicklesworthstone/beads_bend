# bb-rvt probe: which stage of the load faults on the JS lane when one record holds a long text member? The JS lane
# aborts with `bend: memory fault (machine stack overflow?)` on a one-record store whose description is 64 KB
# (16 KB answers); the C lanes answer. This builds that record in memory (no file effect), as a code-point list
# made by accumulator-shaped loops only, and runs ONE stage of the load per mode:
#   lines   Store.lines_go            the lines of the store
#   trim    Store.trim of every line
#   lex     Json.lex of the one line  the tokens
#   dec     Decode.issue_of           the decoded record, then Store.violations on it
#   load    Store.load_fast           the whole load
#   spec    Store.load                the spec loop
#   mem     Json.members              the members, before any decoding
#   plain   Decode.issue_of           the decoded record alone
# (`mem` and `plain` are the two modes that split the fault between the members and the decode.)
# Build: NOT from this directory. Bend 2.0.20 resolves an operator's type inside an imported module whose path holds
# `../` wrongly (`expected: a defined name; observed: U32../../core/json.width`, in `json.punct`), so the probe is
# copied next to a symlink `core -> port/core` with its imports rewritten to `./core/…`, then
#   bend main.bend -o p.js; python3 scripts/js-lane.py p.js -- <mode> <n>   (n = description length)
# Answer (2026-09-24, before the repair): lines, trim, lex and mem answered at n = 70000; dec, load and spec faulted.
# After `Json.codes`, `Json.byte_len`, `Store.has_nul` and `Store.has_space` took an accumulator: load answers at
# n = 1400000 in 4.8 s (bb-rvt, the DISC-008 amendment)
import Base
import ../../core/json.bend as Json
import ../../core/decode.bend as Decode
import ../../core/store.bend as Store
import ../../core/model.bend as Model

# the code points of a String, in order, by an accumulator (REVERSED first)
def rev_codes(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, rest}:
      rev_codes(rest, c <> acc)

# n copies of `x` put in front of acc
def xs(n: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      acc
    case 1n+m:
      xs(m, 120 <> acc)

# the record, REVERSED then put in order: head, n x's, tail, newline
def record(n: Nat) -> List<&2, U32>:
  List.reverse(&2, U32, rev_codes("\"}\n", xs(n, rev_codes("{\"id\":\"proj-a1\",\"title\":\"t\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-01-01T10:00:00Z\",\"updated_at\":\"2026-01-01T10:00:00Z\",\"description\":\"", Nil{}))))

def count_go(xs: List<&2, List<&2, U32>>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case Con{x, rest}:
      count_go(rest, (1n + acc : Nat))

def len_go(xs: List<&2, U32>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case Con{x, rest}:
      len_go(rest, (1n + acc : Nat))

def trim_all(ls: List<&2, List<&2, U32>>, acc: Nat) -> Nat:
  match ls:
    case Nil{}:
      acc
    case Con{l, rest}:
      trim_all(rest, len_go(Store.trim(l), acc))

def lexed(lx: Json.Lexed) -> String:
  match lx:
    case Json.LexBad{msg, at}:
      "lex bad: " ++ msg
    case Json.LexOk{toks}:
      "lex ok " ++ Nat.show(List.length(&2, Json.Tok, toks))

def decoded(d: Decode.Dec) -> String:
  match d:
    case Decode.DecBad{msg, at}:
      "dec bad: " ++ msg
    case Decode.DecOk{i}:
      "dec ok " ++ Nat.show(List.length(&2, String, Store.violations(i)))

def loaded(l: Store.Loaded) -> String:
  match l:
    case Store.LoadBad{f}:
      "load bad"
    case Store.LoadOk{issues}:
      "load ok " ++ Nat.show(List.length(&2, Model.Issue, issues))

def split_of(sp: Json.Split) -> String:
  match sp:
    case Json.SplitBad{msg, at}:
      "split bad: " ++ msg
    case Json.SplitOk{ms}:
      "split ok " ++ Nat.show(List.length(&2, Json.Member, ms))

def members_of(lx: Json.Lexed) -> String:
  match lx:
    case Json.LexBad{msg, at}:
      "lex bad"
    case Json.LexOk{toks}:
      split_of(Json.members(toks, 99999))

def plain(d: Decode.Dec) -> String:
  match d:
    case Decode.DecBad{msg, at}:
      "dec bad: " ++ msg
    case Decode.DecOk{i}:
      "dec ok"

def first_line(ls: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match ls:
    case Nil{}:
      Nil{}
    case Con{l, rest}:
      l

def stage(mode: String, +n: Nat) -> String:
  match mode:
    case SCon{Chr{108}, SCon{Chr{105}, rest}}:
      "lines " ++ Nat.show(count_go(Store.lines_go(record(n), Nil{}, Nil{}), 0n))
    case SCon{Chr{116}, rest}:
      "trim " ++ Nat.show(trim_all(Store.lines_go(record(n), Nil{}, Nil{}), 0n))
    case SCon{Chr{108}, SCon{Chr{101}, rest}}:
      lexed(Json.lex(Store.trim(first_line(Store.lines_go(record(n), Nil{}, Nil{})))))
    case SCon{Chr{109}, rest}:
      members_of(Json.lex(Store.trim(first_line(Store.lines_go(record(n), Nil{}, Nil{})))))
    case SCon{Chr{112}, rest}:
      plain(Decode.issue_of(Store.trim(first_line(Store.lines_go(record(n), Nil{}, Nil{}))), U32.from_nat(Nat.add(n, 200n))))
    case SCon{Chr{100}, rest}:
      decoded(Decode.issue_of(Store.trim(first_line(Store.lines_go(record(n), Nil{}, Nil{}))), U32.from_nat(Nat.add(n, 200n))))
    case SCon{Chr{108}, SCon{Chr{111}, rest}}:
      loaded(Store.load_fast(record(n), "/mnt/proj/.beads/issues.jsonl"))
    case SCon{Chr{115}, rest}:
      loaded(Store.load(record(n), "/mnt/proj/.beads/issues.jsonl"))
    case _:
      "usage: <lines|trim|lex|dec|load|spec> <n>"

def chosen(args: List<String>) -> IO(Unit):
  match args:
    case Con{mode, Con{n, rest}}:
      IO.print(stage(mode, Maybe.default(&2, Nat, Nat.read(n), 0n)))
    case _:
      IO.print("usage: <lines|trim|lex|dec|load|spec> <n>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    chosen(args)
