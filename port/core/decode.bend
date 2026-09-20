# core/decode — one line of .beads/issues.jsonl as an issue record (S2.24–S2.38).
# tokens -> members (core/json) -> the record, member by member. A member the
# port does not know is dropped without being interpreted (S2.29). A value of
# the wrong shape, a malformed timestamp or a missing required member is a
# verdict with the byte column serde_json would report, never a default.
# The load-time REPAIRS of S2.31–S2.36 (case folding, label sorting, duplicate
# edges) are core/store's: this module reads what the line says.
# The repetitive parts of this file were produced once by a script; this file,
# not the script, is the source. Nothing here consults the original.
import Base
import ./json.bend as Json
import ./time.bend as Time
import ./model.bend as Model

# S2.28 (data) what a value turned out to be, by the shape its member expects
type Got is Data:
  GotBad{msg: String}
  GotStr{v: String}
  GotOptStr{v: Maybe<&2, String>}
  GotTime{v: Time.Instant}
  GotOptTime{v: Maybe<&2, Time.Instant>}
  GotFlag{v: Bool}
  GotOptFlag{v: Maybe<&2, Bool>}
  GotOptList{v: Maybe<&2, List<&2, String>>}
  GotStrings{v: List<&2, String>}
  GotDeps{v: List<&2, Model.Dependency>}
  GotComments{v: List<&2, Model.Comment>}

# S2.27 S2.30 (data) a decoded record, or the message and byte column of the refusal
type Dec is Data:
  DecBad{msg: String, at: U32}
  DecOk{issue: Model.Issue}

# S2.34 (spec twin) every character is an ASCII digit, and there is at least one
def digits_ok(s: String, seen: Bool) -> Bool:
  match s:
    case SNil{}:
      seen
    case SCon{Chr{+c}, rest}:
      (((c >= 48 : U32) && (c <= 57 : U32)) && digits_ok(rest, True{}))

# S2.34 (spec twin) `-` then digits
def neg_ok(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, rest}:
      (U32.is_eq(c, 45) && digits_ok(rest, False{}))

# S2.34 S5.11 (spec twin) a bare JSON integer: digits with an optional leading `-`
def is_int(+s: String) -> Bool:
  (digits_ok(s, False{}) || neg_ok(s))

# S2.28 (spec twin) a required string
def take_str(value: List<&2, Json.Tok>) -> Got:
  match value:
    case Con{Json.Tok{Json.KStr{text}, _}, Nil{}}:
      GotStr{text}
    case _:
      GotBad{"invalid type: expected a string"}

# S2.34 (spec twin) route on the integer verdict
def int_pick(text: String, ok: Bool) -> Got:
  match ok:
    case True{}:
      GotStr{text}
    case False{}:
      GotBad{"invalid type: expected an integer"}

# S2.34 (spec twin) a required integer, kept as its digit string
def take_int(value: List<&2, Json.Tok>) -> Got:
  match value:
    case Con{Json.Tok{Json.KLit{+text}, _}, Nil{}}:
      int_pick(text, is_int(text))
    case _:
      GotBad{"invalid type: expected an integer"}

# S2.38 (spec twin) a literal where a string may stand: only `null` means "not set"
def null_str(is_null: Bool) -> Got:
  match is_null:
    case True{}:
      GotOptStr{None{}}
    case False{}:
      GotBad{"invalid type: expected a string"}

# S2.38 (spec twin) an optional string; `""` is an empty string, not "not set"
def take_opt_str(value: List<&2, Json.Tok>) -> Got:
  match value:
    case Con{Json.Tok{Json.KStr{text}, _}, Nil{}}:
      GotOptStr{Some{text}}
    case Con{Json.Tok{Json.KLit{text}, _}, Nil{}}:
      null_str(String.eq(text, "null"))
    case _:
      GotBad{"invalid type: expected a string"}

# S2.34 (spec twin) route on `null` and on the integer verdict
def opt_int_pick(text: String, is_null: Bool, ok: Bool) -> Got:
  match is_null ok:
    case True{} _:
      GotOptStr{None{}}
    case False{} True{}:
      GotOptStr{Some{text}}
    case False{} False{}:
      GotBad{"invalid type: expected an integer"}

# S2.34 (spec twin) an optional integer, kept as its digit string
def take_opt_int(value: List<&2, Json.Tok>) -> Got:
  match value:
    case Con{Json.Tok{Json.KLit{+text}, _}, Nil{}}:
      opt_int_pick(text, String.eq(text, "null"), is_int(text))
    case _:
      GotBad{"invalid type: expected an integer"}

# S2.35 (spec twin) a parsed timestamp as a required instant
def time_got(p: Time.Parsed) -> Got:
  match p:
    case Time.Good{at}:
      GotTime{at}
    case Time.Bad{}:
      GotBad{"invalid timestamp"}

# S2.35 (spec twin) a required RFC 3339 timestamp
def take_time(value: List<&2, Json.Tok>) -> Got:
  match value:
    case Con{Json.Tok{Json.KStr{text}, _}, Nil{}}:
      time_got(Time.parse(text))
    case _:
      GotBad{"invalid type: expected a timestamp string"}

# S2.35 (spec twin) a parsed timestamp as an optional instant
def opt_time_got(p: Time.Parsed) -> Got:
  match p:
    case Time.Good{at}:
      GotOptTime{Some{at}}
    case Time.Bad{}:
      GotBad{"invalid timestamp"}

# S2.35 (spec twin) a literal where a timestamp may stand: only `null` means "not set"
def null_time(is_null: Bool) -> Got:
  match is_null:
    case True{}:
      GotOptTime{None{}}
    case False{}:
      GotBad{"invalid type: expected a timestamp string"}

# S2.35 (spec twin) an optional RFC 3339 timestamp
def take_opt_time(value: List<&2, Json.Tok>) -> Got:
  match value:
    case Con{Json.Tok{Json.KStr{text}, _}, Nil{}}:
      opt_time_got(Time.parse(text))
    case Con{Json.Tok{Json.KLit{text}, _}, Nil{}}:
      null_time(String.eq(text, "null"))
    case _:
      GotBad{"invalid type: expected a timestamp string"}

# S3.3 (spec twin) route on `true` and `false`
def flag_pick(yes: Bool, no: Bool) -> Got:
  match yes no:
    case True{} _:
      GotFlag{True{}}
    case False{} True{}:
      GotFlag{False{}}
    case False{} False{}:
      GotBad{"invalid type: expected a boolean"}

# S3.3 (spec twin) a flag
def take_flag(value: List<&2, Json.Tok>) -> Got:
  match value:
    case Con{Json.Tok{Json.KLit{+text}, _}, Nil{}}:
      flag_pick(String.eq(text, "true"), String.eq(text, "false"))
    case _:
      GotBad{"invalid type: expected a boolean"}

# S3.1 (spec twin) route on `true`, `false` and `null`
def opt_flag_pick(yes: Bool, no: Bool, is_null: Bool) -> Got:
  match yes no is_null:
    case True{} _ _:
      GotOptFlag{Some{True{}}}
    case False{} True{} _:
      GotOptFlag{Some{False{}}}
    case False{} False{} True{}:
      GotOptFlag{None{}}
    case False{} False{} False{}:
      GotBad{"invalid type: expected a boolean"}

# S3.1 (spec twin) an optional boolean
def take_opt_flag(value: List<&2, Json.Tok>) -> Got:
  match value:
    case Con{Json.Tok{Json.KLit{+text}, _}, Nil{}}:
      opt_flag_pick(String.eq(text, "true"), String.eq(text, "false"), String.eq(text, "null"))
    case _:
      GotBad{"invalid type: expected a boolean"}

# S2.39 (spec twin) the strings of `[ "a" , "b" ]` in file order, duplicates kept; acc is REVERSED.
# Brackets and commas are skipped; anything else makes the verdict false.
def strings_go(toks: List<&2, Json.Tok>, acc: List<&2, String>, ok: Bool) -> Got:
  match toks ok:
    case Nil{} True{}:
      GotStrings{List.reverse(&2, String, acc)}
    case Nil{} False{}:
      GotBad{"invalid type: expected an array of strings"}
    case Con{Json.Tok{Json.KStr{text}, _}, rest} good:
      strings_go(rest, text <> acc, good)
    case Con{Json.Tok{Json.KComma{}, _}, rest} good:
      strings_go(rest, acc, good)
    case Con{Json.Tok{Json.KLBrack{}, _}, rest} good:
      strings_go(rest, acc, good)
    case Con{Json.Tok{Json.KRBrack{}, _}, rest} good:
      strings_go(rest, acc, good)
    case Con{other, rest} good:
      strings_go(rest, acc, False{})

# S2.39 (spec twin) an array of strings
def take_strings(value: List<&2, Json.Tok>) -> Got:
  strings_go(value, Nil{}, True{})

# S3.1 (spec twin) an array of strings as an optional member
def opt_list_got(g: Got) -> Got:
  match g:
    case GotStrings{v}:
      GotOptList{Some{v}}
    case GotBad{msg}:
      GotBad{msg}
    case _:
      GotBad{"invalid type: expected an array of strings"}

# S3.1 (spec twin) a literal where a list may stand: only `null` means "not set"
def null_list(is_null: Bool) -> Got:
  match is_null:
    case True{}:
      GotOptList{None{}}
    case False{}:
      GotBad{"invalid type: expected an array of strings"}

# S3.1 (spec twin) `null` is "not set"; anything else must be an array of strings
def take_opt_list(value: List<&2, Json.Tok>) -> Got:
  match value:
    case Con{Json.Tok{Json.KLit{text}, _}, Nil{}}:
      null_list(String.eq(text, "null"))
    case other:
      opt_list_got(take_strings(other))

# S2.28 (spec twin) the position of a key in a list of names, or 999 when it is not there. The loop
# never stops early (a match on a computed Bool would need a second def): Bool.pick keeps the hit.
def index_go(names: List<&2, String>, +key: String, +n: U32, acc: U32) -> U32:
  match names:
    case Nil{}:
      acc
    case Con{name, rest}:
      index_go(rest, key, (n + 1 : U32), Bool.pick(U32, String.eq(name, key), n, acc))

# S2.28 (spec twin) the position of a key in a list of names, or 999
def index_of(names: List<&2, String>, key: String) -> U32:
  index_go(names, key, 0, 999)

# ---------------------------------------------------------------- array elements

# S2.24 (data) the element splitter's state: nesting depth (1 = inside the array itself), the current
# element's tokens (REVERSED), the elements so far (REVERSED), the verdict
type Els is Data:
  Els{depth: Nat, cur: List<&2, Json.Tok>, out: List<&2, List<&2, Json.Tok>>, ok: Bool}

# S2.24 (spec twin) an element ends at a depth-1 comma or at the closing bracket. An empty element
# before a comma is malformed; before the closing bracket it is the empty array or a finished one.
def els_flush(cur: List<&2, Json.Tok>, out: List<&2, List<&2, Json.Tok>>, ok: Bool, closing: Bool, depth: Nat) -> Els:
  match cur closing:
    case Nil{} True{}:
      Els{depth, Nil{}, out, ok}
    case Nil{} False{}:
      Els{depth, Nil{}, out, False{}}
    case Con{first, rest} _:
      Els{depth, Nil{}, List.reverse(&2, Json.Tok, first <> rest) <> out, ok}

# S2.24 (spec twin) one token of an array's tokens
def els_step(kind: Json.TokKind, at: U32, depth: Nat, cur: List<&2, Json.Tok>, out: List<&2, List<&2, Json.Tok>>, ok: Bool) -> Els:
  match kind depth:
    case Json.KLBrack{} 0n:
      Els{1n, Nil{}, out, ok}
    case other 0n:
      Els{0n, Nil{}, out, False{}}
    case Json.KComma{} 1n+0n:
      els_flush(cur, out, ok, False{}, 1n)
    case Json.KRBrack{} 1n+0n:
      els_flush(cur, out, ok, True{}, 0n)
    case Json.KLBrack{} 1n+d:
      Els{1n+(1n+d), Json.Tok{Json.KLBrack{}, at} <> cur, out, ok}
    case Json.KLBrace{} 1n+d:
      Els{1n+(1n+d), Json.Tok{Json.KLBrace{}, at} <> cur, out, ok}
    case Json.KRBrack{} 1n+d:
      Els{d, Json.Tok{Json.KRBrack{}, at} <> cur, out, ok}
    case Json.KRBrace{} 1n+d:
      Els{d, Json.Tok{Json.KRBrace{}, at} <> cur, out, ok}
    case other 1n+d:
      Els{1n+d, Json.Tok{other, at} <> cur, out, ok}

# S2.24 (spec twin) the loop: the token list is the measure
def els_go(toks: List<&2, Json.Tok>, st: Els) -> Els:
  match toks st:
    case Nil{} done:
      done
    case Con{Json.Tok{kind, at}, rest} Els{depth, cur, out, ok}:
      els_go(rest, els_step(kind, at, depth, cur, out, ok))

# S2.24 (data) the elements of an array, each as its own token list, or a refusal
type Elements is Data:
  ElsBad{}
  ElsOk{items: List<&2, List<&2, Json.Tok>>}

# S2.24 (spec twin) a complete array returns to depth zero with a true verdict
def els_end(st: Els) -> Elements:
  match st:
    case Els{0n, cur, out, True{}}:
      ElsOk{List.reverse(&2, List<&2, Json.Tok>, out)}
    case _:
      ElsBad{}

# S2.24 (spec twin) the elements of `[ e , e , e ]`
def elements(toks: List<&2, Json.Tok>) -> Elements:
  els_end(els_go(toks, Els{0n, Nil{}, Nil{}, True{}}))

# ---------------------------------------------------------------- dependencies

# S3.5 (data) a dependency being read, or the refusal
type DepDec is Data:
  DepBad{msg: String}
  DepOk{dep: Model.Dependency}

# S2.37 (spec twin) a `metadata` string that is empty or only whitespace loads as "not set"
def metadata_pick(text: String, blank: Bool) -> Maybe<&2, String>:
  match blank:
    case True{}:
      None{}
    case False{}:
      Some{text}

# S2.37 (spec twin) the metadata member
def metadata_of(v: Maybe<&2, String>) -> Maybe<&2, String>:
  match v:
    case None{}:
      None{}
    case Some{+text}:
      metadata_pick(text, String.is_empty(String.trim(text)))

# S3.5 (spec twin) one member of a dependency, by its index in the seven names
def dep_put(idx: U32, d: Model.Dependency, got_str: Got, got_opt: Got, got_time: Got) -> DepDec:
  match idx d got_str got_opt got_time:
    case 0 Model.Dependency{_, b, c, e, f, g, h} GotStr{v} _ _:
      DepOk{Model.Dependency{v, b, c, e, f, g, h}}
    case 1 Model.Dependency{a, _, c, e, f, g, h} GotStr{v} _ _:
      DepOk{Model.Dependency{a, v, c, e, f, g, h}}
    case 2 Model.Dependency{a, b, _, e, f, g, h} GotStr{v} _ _:
      DepOk{Model.Dependency{a, b, v, e, f, g, h}}
    case 3 Model.Dependency{a, b, c, _, f, g, h} _ _ GotTime{v}:
      DepOk{Model.Dependency{a, b, c, v, f, g, h}}
    case 4 Model.Dependency{a, b, c, e, _, g, h} _ GotOptStr{v} _:
      DepOk{Model.Dependency{a, b, c, e, v, g, h}}
    case 5 Model.Dependency{a, b, c, e, f, _, h} _ GotOptStr{v} _:
      DepOk{Model.Dependency{a, b, c, e, f, metadata_of(v), h}}
    case 6 Model.Dependency{a, b, c, e, f, g, _} _ GotOptStr{v} _:
      DepOk{Model.Dependency{a, b, c, e, f, g, v}}
    case 999 keep _ _ _:
      DepOk{keep}
    case _ _ _ _ _:
      DepBad{"invalid dependency member"}

# S3.5 (spec twin) the seven member names of a dependency, in wire order
def dep_names() -> List<&2, String>:
  ["issue_id", "depends_on_id", "type", "created_at", "created_by", "metadata", "thread_id"]

# S3.5 (spec twin) a refusal is sticky; otherwise read one member
def dep_member(st: DepDec, key: String, +value: List<&2, Json.Tok>) -> DepDec:
  match st:
    case DepBad{msg}:
      DepBad{msg}
    case DepOk{d}:
      dep_put(index_of(dep_names(), key), d, take_str(value), take_opt_str(value), take_time(value))

# S3.5 (spec twin) the loop over a dependency's members
def dep_go(ms: List<&2, Json.Member>, st: DepDec) -> DepDec:
  match ms:
    case Nil{}:
      st
    case Con{Json.Member{key, value, _}, rest}:
      dep_go(rest, dep_member(st, key, value))

# S3.5 (spec twin) a dependency from the members of its object
def dep_of(sp: Json.Split) -> DepDec:
  match sp:
    case Json.SplitBad{msg, _}:
      DepBad{msg}
    case Json.SplitOk{ms}:
      dep_go(ms, DepOk{Model.Dependency{"", "", "blocks", Time.Instant{0, 0, 0}, None{}, None{}, None{}}})

# S3.5 (spec twin) fold one decoded dependency into the list being built (REVERSED); a refusal is sticky
def deps_push(acc: Got, one: DepDec) -> Got:
  match acc one:
    case GotDeps{sofar} DepOk{d}:
      GotDeps{d <> sofar}
    case GotDeps{sofar} DepBad{msg}:
      GotBad{msg}
    case bad _:
      bad

# S3.5 (spec twin) the loop over the array's elements
def deps_go(items: List<&2, List<&2, Json.Tok>>, acc: Got, +eof: U32) -> Got:
  match items:
    case Nil{}:
      acc
    case Con{item, rest}:
      deps_go(rest, deps_push(acc, dep_of(Json.members(item, eof))), eof)

# S3.5 (spec twin) put the collected dependencies back in file order
def deps_done(g: Got) -> Got:
  match g:
    case GotDeps{v}:
      GotDeps{List.reverse(&2, Model.Dependency, v)}
    case other:
      other

# S3.5 (spec twin) route on the element split
def deps_from(els: Elements, eof: U32) -> Got:
  match els:
    case ElsBad{}:
      GotBad{"invalid type: expected an array of dependencies"}
    case ElsOk{items}:
      deps_done(deps_go(items, GotDeps{Nil{}}, eof))

# S3.5 (spec twin) the `dependencies` member
def take_deps(value: List<&2, Json.Tok>, eof: U32) -> Got:
  deps_from(elements(value), eof)

# ---------------------------------------------------------------- comments

# S3.6 (data) a comment being read, or the refusal
type ComDec is Data:
  ComBad{msg: String}
  ComOk{com: Model.Comment}

# S3.6 (spec twin) one member of a comment, by its index in the five names
def com_put(idx: U32, c: Model.Comment, got_str: Got, got_int: Got, got_time: Got) -> ComDec:
  match idx c got_str got_int got_time:
    case 0 Model.Comment{_, b, d, e, f} _ GotStr{v} _:
      ComOk{Model.Comment{v, b, d, e, f}}
    case 1 Model.Comment{a, _, d, e, f} GotStr{v} _ _:
      ComOk{Model.Comment{a, v, d, e, f}}
    case 2 Model.Comment{a, b, _, e, f} GotStr{v} _ _:
      ComOk{Model.Comment{a, b, v, e, f}}
    case 3 Model.Comment{a, b, d, _, f} GotStr{v} _ _:
      ComOk{Model.Comment{a, b, d, v, f}}
    case 4 Model.Comment{a, b, d, e, _} _ _ GotTime{v}:
      ComOk{Model.Comment{a, b, d, e, v}}
    case 999 keep _ _ _:
      ComOk{keep}
    case _ _ _ _ _:
      ComBad{"invalid comment member"}

# S3.6 (spec twin) the five member names of a comment, in wire order
def com_names() -> List<&2, String>:
  ["id", "issue_id", "author", "text", "created_at"]

# S3.6 (spec twin) a refusal is sticky; otherwise read one member
def com_member(st: ComDec, key: String, +value: List<&2, Json.Tok>) -> ComDec:
  match st:
    case ComBad{msg}:
      ComBad{msg}
    case ComOk{c}:
      com_put(index_of(com_names(), key), c, take_str(value), take_int(value), take_time(value))

# S3.6 (spec twin) the loop over a comment's members
def com_go(ms: List<&2, Json.Member>, st: ComDec) -> ComDec:
  match ms:
    case Nil{}:
      st
    case Con{Json.Member{key, value, _}, rest}:
      com_go(rest, com_member(st, key, value))

# S3.6 (spec twin) a comment from the members of its object
def com_of(sp: Json.Split) -> ComDec:
  match sp:
    case Json.SplitBad{msg, _}:
      ComBad{msg}
    case Json.SplitOk{ms}:
      com_go(ms, ComOk{Model.Comment{"0", "", "", "", Time.Instant{0, 0, 0}}})

# S3.6 (spec twin) fold one decoded comment into the list being built (REVERSED); a refusal is sticky
def coms_push(acc: Got, one: ComDec) -> Got:
  match acc one:
    case GotComments{sofar} ComOk{c}:
      GotComments{c <> sofar}
    case GotComments{sofar} ComBad{msg}:
      GotBad{msg}
    case bad _:
      bad

# S3.6 (spec twin) the loop over the array's elements
def coms_go(items: List<&2, List<&2, Json.Tok>>, acc: Got, +eof: U32) -> Got:
  match items:
    case Nil{}:
      acc
    case Con{item, rest}:
      coms_go(rest, coms_push(acc, com_of(Json.members(item, eof))), eof)

# S3.6 (spec twin) put the collected comments back in file order
def coms_done(g: Got) -> Got:
  match g:
    case GotComments{v}:
      GotComments{List.reverse(&2, Model.Comment, v)}
    case other:
      other

# S3.6 (spec twin) route on the element split
def coms_from(els: Elements, eof: U32) -> Got:
  match els:
    case ElsBad{}:
      GotBad{"invalid type: expected an array of comments"}
    case ElsOk{items}:
      coms_done(coms_go(items, GotComments{Nil{}}, eof))

# S3.6 (spec twin) the `comments` member
def take_comments(value: List<&2, Json.Tok>, eof: U32) -> Got:
  coms_from(elements(value), eof)

# ---------------------------------------------------------------- the three collections

# S3.4 (spec twin) replace the labels
def put_labels(i: Model.Issue, got: Got, at: U32) -> Dec:
  match i got:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, _, dependencies, comments} GotStrings{v}:
      DecOk{Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, v, dependencies, comments}}
    case _ GotBad{msg}:
      DecBad{msg, at}
    case _ _:
      DecBad{"invalid type", at}

# S3.4 (spec twin) replace the dependencies
def put_dependencies(i: Model.Issue, got: Got, at: U32) -> Dec:
  match i got:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, _, comments} GotDeps{v}:
      DecOk{Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, v, comments}}
    case _ GotBad{msg}:
      DecBad{msg, at}
    case _ _:
      DecBad{"invalid type", at}

# S3.4 (spec twin) replace the comments
def put_comments(i: Model.Issue, got: Got, at: U32) -> Dec:
  match i got:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, _} GotComments{v}:
      DecOk{Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, v}}
    case _ GotBad{msg}:
      DecBad{msg, at}
    case _ _:
      DecBad{"invalid type", at}

# ---------------------------------------------------------------- the 41 scalar members

# S2.28 (spec twin) replace the member `id`
def set_id(i: Model.Issue, v: String) -> Model.Issue:
  match i:
    case Model.Issue{Model.Head{_, title, status, priority, issue_type}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{v, title, status, priority, issue_type}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `title`
def set_title(i: Model.Issue, v: String) -> Model.Issue:
  match i:
    case Model.Issue{Model.Head{id, _, status, priority, issue_type}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, v, status, priority, issue_type}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `description`
def set_description(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, Model.Texts{_, design, acceptance_criteria, prerequisites, notes}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{v, design, acceptance_criteria, prerequisites, notes}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `design`
def set_design(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, Model.Texts{description, _, acceptance_criteria, prerequisites, notes}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{description, v, acceptance_criteria, prerequisites, notes}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `acceptance_criteria`
def set_acceptance_criteria(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, Model.Texts{description, design, _, prerequisites, notes}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{description, design, v, prerequisites, notes}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `prerequisites`
def set_prerequisites(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, Model.Texts{description, design, acceptance_criteria, _, notes}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{description, design, acceptance_criteria, v, notes}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `notes`
def set_notes(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, Model.Texts{description, design, acceptance_criteria, prerequisites, _}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, Model.Texts{description, design, acceptance_criteria, prerequisites, v}, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `status`
def set_status(i: Model.Issue, v: String) -> Model.Issue:
  match i:
    case Model.Issue{Model.Head{id, title, _, priority, issue_type}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, v, priority, issue_type}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `priority`
def set_priority(i: Model.Issue, v: String) -> Model.Issue:
  match i:
    case Model.Issue{Model.Head{id, title, status, _, issue_type}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, status, v, issue_type}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `issue_type`
def set_issue_type(i: Model.Issue, v: String) -> Model.Issue:
  match i:
    case Model.Issue{Model.Head{id, title, status, priority, _}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, status, priority, v}, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `assignee`
def set_assignee(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, Model.People{_, owner, created_by, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, Model.People{v, owner, created_by, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `owner`
def set_owner(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, Model.People{assignee, _, created_by, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, Model.People{assignee, v, created_by, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `estimated_minutes`
def set_estimated_minutes(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, Model.Meta{_}, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, Model.Meta{v}, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `created_at`
def set_created_at(i: Model.Issue, v: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{_, updated_at, closed_at, due_at, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{v, updated_at, closed_at, due_at, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `created_by`
def set_created_by(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, Model.People{assignee, owner, _, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, Model.People{assignee, owner, v, sender}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `updated_at`
def set_updated_at(i: Model.Issue, v: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, _, closed_at, due_at, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, v, closed_at, due_at, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `closed_at`
def set_closed_at(i: Model.Issue, v: Maybe<&2, Time.Instant>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, _, due_at, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, updated_at, v, due_at, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `close_reason`
def set_close_reason(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, Model.Closing{_, closed_by_session, bypassed_policy, bypass_reason, policy_gates_fired}, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, Model.Closing{v, closed_by_session, bypassed_policy, bypass_reason, policy_gates_fired}, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `closed_by_session`
def set_closed_by_session(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, Model.Closing{close_reason, _, bypassed_policy, bypass_reason, policy_gates_fired}, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, Model.Closing{close_reason, v, bypassed_policy, bypass_reason, policy_gates_fired}, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `bypassed_policy`
def set_bypassed_policy(i: Model.Issue, v: Maybe<&2, Bool>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, Model.Closing{close_reason, closed_by_session, _, bypass_reason, policy_gates_fired}, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, Model.Closing{close_reason, closed_by_session, v, bypass_reason, policy_gates_fired}, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `bypass_reason`
def set_bypass_reason(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, Model.Closing{close_reason, closed_by_session, bypassed_policy, _, policy_gates_fired}, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, Model.Closing{close_reason, closed_by_session, bypassed_policy, v, policy_gates_fired}, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `policy_gates_fired`
def set_policy_gates_fired(i: Model.Issue, v: Maybe<&2, List<&2, String>>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, Model.Closing{close_reason, closed_by_session, bypassed_policy, bypass_reason, _}, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, Model.Closing{close_reason, closed_by_session, bypassed_policy, bypass_reason, v}, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `due_at`
def set_due_at(i: Model.Issue, v: Maybe<&2, Time.Instant>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, closed_at, _, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, updated_at, closed_at, v, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `defer_until`
def set_defer_until(i: Model.Issue, v: Maybe<&2, Time.Instant>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, _, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, v, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `external_ref`
def set_external_ref(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, Model.Source{_, source_system, source_repo, source_repo_path, agent_context}, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, Model.Source{v, source_system, source_repo, source_repo_path, agent_context}, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `source_system`
def set_source_system(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, Model.Source{external_ref, _, source_repo, source_repo_path, agent_context}, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, Model.Source{external_ref, v, source_repo, source_repo_path, agent_context}, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `source_repo`
def set_source_repo(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, Model.Source{external_ref, source_system, _, source_repo_path, agent_context}, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, Model.Source{external_ref, source_system, v, source_repo_path, agent_context}, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `source_repo_path`
def set_source_repo_path(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, Model.Source{external_ref, source_system, source_repo, _, agent_context}, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, Model.Source{external_ref, source_system, source_repo, v, agent_context}, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `agent_context`
def set_agent_context(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, Model.Source{external_ref, source_system, source_repo, source_repo_path, _}, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, Model.Source{external_ref, source_system, source_repo, source_repo_path, v}, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `deleted_at`
def set_deleted_at(i: Model.Issue, v: Maybe<&2, Time.Instant>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, defer_until, _, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, defer_until, v, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `deleted_by`
def set_deleted_by(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, Model.Deletion{_, delete_reason, original_type}, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, Model.Deletion{v, delete_reason, original_type}, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `delete_reason`
def set_delete_reason(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, Model.Deletion{deleted_by, _, original_type}, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, Model.Deletion{deleted_by, v, original_type}, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `original_type`
def set_original_type(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, Model.Deletion{deleted_by, delete_reason, _}, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, Model.Deletion{deleted_by, delete_reason, v}, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `compaction_level`
def set_compaction_level(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, Model.Compaction{_, compacted_at_commit, original_size}, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, Model.Compaction{v, compacted_at_commit, original_size}, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `compacted_at`
def set_compacted_at(i: Model.Issue, v: Maybe<&2, Time.Instant>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, defer_until, deleted_at, _}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, defer_until, deleted_at, v}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `compacted_at_commit`
def set_compacted_at_commit(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, Model.Compaction{compaction_level, _, original_size}, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, Model.Compaction{compaction_level, v, original_size}, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `original_size`
def set_original_size(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, Model.Compaction{compaction_level, compacted_at_commit, _}, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, Model.Compaction{compaction_level, compacted_at_commit, v}, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `sender`
def set_sender(i: Model.Issue, v: Maybe<&2, String>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, Model.People{assignee, owner, created_by, _}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, Model.People{assignee, owner, created_by, v}, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `ephemeral`
def set_ephemeral(i: Model.Issue, v: Bool) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, Model.Flags{_, pinned, is_template}, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, Model.Flags{v, pinned, is_template}, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `pinned`
def set_pinned(i: Model.Issue, v: Bool) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, Model.Flags{ephemeral, _, is_template}, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, Model.Flags{ephemeral, v, is_template}, labels, dependencies, comments}

# S2.28 (spec twin) replace the member `is_template`
def set_is_template(i: Model.Issue, v: Bool) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, Model.Flags{ephemeral, pinned, _}, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, Model.Flags{ephemeral, pinned, v}, labels, dependencies, comments}

# S2.28 S2.35 (spec twin) the member `id` from its value
def put_id(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotStr{v}:
      DecOk{set_id(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `title` from its value
def put_title(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotStr{v}:
      DecOk{set_title(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `description` from its value
def put_description(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_description(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `design` from its value
def put_design(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_design(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `acceptance_criteria` from its value
def put_acceptance_criteria(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_acceptance_criteria(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `prerequisites` from its value
def put_prerequisites(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_prerequisites(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `notes` from its value
def put_notes(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_notes(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `status` from its value
def put_status(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotStr{v}:
      DecOk{set_status(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `priority` from its value
def put_priority(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotStr{v}:
      DecOk{set_priority(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `issue_type` from its value
def put_issue_type(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotStr{v}:
      DecOk{set_issue_type(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `assignee` from its value
def put_assignee(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_assignee(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `owner` from its value
def put_owner(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_owner(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `estimated_minutes` from its value
def put_estimated_minutes(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_estimated_minutes(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `created_at` from its value
def put_created_at(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotTime{v}:
      DecOk{set_created_at(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `created_by` from its value
def put_created_by(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_created_by(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `updated_at` from its value
def put_updated_at(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotTime{v}:
      DecOk{set_updated_at(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `closed_at` from its value
def put_closed_at(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptTime{v}:
      DecOk{set_closed_at(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `close_reason` from its value
def put_close_reason(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_close_reason(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `closed_by_session` from its value
def put_closed_by_session(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_closed_by_session(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `bypassed_policy` from its value
def put_bypassed_policy(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptFlag{v}:
      DecOk{set_bypassed_policy(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `bypass_reason` from its value
def put_bypass_reason(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_bypass_reason(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `policy_gates_fired` from its value
def put_policy_gates_fired(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptList{v}:
      DecOk{set_policy_gates_fired(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `due_at` from its value
def put_due_at(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptTime{v}:
      DecOk{set_due_at(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `defer_until` from its value
def put_defer_until(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptTime{v}:
      DecOk{set_defer_until(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `external_ref` from its value
def put_external_ref(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_external_ref(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `source_system` from its value
def put_source_system(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_source_system(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `source_repo` from its value
def put_source_repo(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_source_repo(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `source_repo_path` from its value
def put_source_repo_path(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_source_repo_path(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `agent_context` from its value
def put_agent_context(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_agent_context(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `deleted_at` from its value
def put_deleted_at(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptTime{v}:
      DecOk{set_deleted_at(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `deleted_by` from its value
def put_deleted_by(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_deleted_by(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `delete_reason` from its value
def put_delete_reason(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_delete_reason(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `original_type` from its value
def put_original_type(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_original_type(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `compaction_level` from its value
def put_compaction_level(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_compaction_level(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `compacted_at` from its value
def put_compacted_at(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptTime{v}:
      DecOk{set_compacted_at(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `compacted_at_commit` from its value
def put_compacted_at_commit(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_compacted_at_commit(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `original_size` from its value
def put_original_size(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_original_size(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `sender` from its value
def put_sender(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotOptStr{v}:
      DecOk{set_sender(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `ephemeral` from its value
def put_ephemeral(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotFlag{v}:
      DecOk{set_ephemeral(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `pinned` from its value
def put_pinned(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotFlag{v}:
      DecOk{set_pinned(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S2.28 S2.35 (spec twin) the member `is_template` from its value
def put_is_template(i: Model.Issue, got: Got, at: U32) -> Dec:
  match got:
    case GotFlag{v}:
      DecOk{set_is_template(i, v)}
    case GotBad{msg}:
      DecBad{msg, at}
    case _:
      DecBad{"invalid type", at}

# S5.4 (spec twin) the member names this port knows, in the wire order; any other key is dropped (S2.29)
def known() -> List<&2, String>:
  ["id", "title", "description", "design", "acceptance_criteria", "prerequisites", "notes", "status", "priority", "issue_type", "assignee", "owner", "estimated_minutes", "created_at", "created_by", "updated_at", "closed_at", "close_reason", "closed_by_session", "bypassed_policy", "bypass_reason", "policy_gates_fired", "due_at", "defer_until", "external_ref", "source_system", "source_repo", "source_repo_path", "agent_context", "deleted_at", "deleted_by", "delete_reason", "original_type", "compaction_level", "compacted_at", "compacted_at_commit", "original_size", "sender", "ephemeral", "pinned", "is_template", "labels", "dependencies", "comments"]

# S2.28 S2.29 (spec twin) one member applied to the record by its index in `known`; an unknown key changes nothing
def put(idx: U32, i: Model.Issue, value: List<&2, Json.Tok>, at: U32, +eof: U32) -> Dec:
  match idx:
    case 0:
      put_id(i, take_str(value), at)
    case 1:
      put_title(i, take_str(value), at)
    case 2:
      put_description(i, take_opt_str(value), at)
    case 3:
      put_design(i, take_opt_str(value), at)
    case 4:
      put_acceptance_criteria(i, take_opt_str(value), at)
    case 5:
      put_prerequisites(i, take_opt_str(value), at)
    case 6:
      put_notes(i, take_opt_str(value), at)
    case 7:
      put_status(i, take_str(value), at)
    case 8:
      put_priority(i, take_int(value), at)
    case 9:
      put_issue_type(i, take_str(value), at)
    case 10:
      put_assignee(i, take_opt_str(value), at)
    case 11:
      put_owner(i, take_opt_str(value), at)
    case 12:
      put_estimated_minutes(i, take_opt_int(value), at)
    case 13:
      put_created_at(i, take_time(value), at)
    case 14:
      put_created_by(i, take_opt_str(value), at)
    case 15:
      put_updated_at(i, take_time(value), at)
    case 16:
      put_closed_at(i, take_opt_time(value), at)
    case 17:
      put_close_reason(i, take_opt_str(value), at)
    case 18:
      put_closed_by_session(i, take_opt_str(value), at)
    case 19:
      put_bypassed_policy(i, take_opt_flag(value), at)
    case 20:
      put_bypass_reason(i, take_opt_str(value), at)
    case 21:
      put_policy_gates_fired(i, take_opt_list(value), at)
    case 22:
      put_due_at(i, take_opt_time(value), at)
    case 23:
      put_defer_until(i, take_opt_time(value), at)
    case 24:
      put_external_ref(i, take_opt_str(value), at)
    case 25:
      put_source_system(i, take_opt_str(value), at)
    case 26:
      put_source_repo(i, take_opt_str(value), at)
    case 27:
      put_source_repo_path(i, take_opt_str(value), at)
    case 28:
      put_agent_context(i, take_opt_str(value), at)
    case 29:
      put_deleted_at(i, take_opt_time(value), at)
    case 30:
      put_deleted_by(i, take_opt_str(value), at)
    case 31:
      put_delete_reason(i, take_opt_str(value), at)
    case 32:
      put_original_type(i, take_opt_str(value), at)
    case 33:
      put_compaction_level(i, take_opt_int(value), at)
    case 34:
      put_compacted_at(i, take_opt_time(value), at)
    case 35:
      put_compacted_at_commit(i, take_opt_str(value), at)
    case 36:
      put_original_size(i, take_opt_int(value), at)
    case 37:
      put_sender(i, take_opt_str(value), at)
    case 38:
      put_ephemeral(i, take_flag(value), at)
    case 39:
      put_pinned(i, take_flag(value), at)
    case 40:
      put_is_template(i, take_flag(value), at)
    case 41:
      put_labels(i, take_strings(value), at)
    case 42:
      put_dependencies(i, take_deps(value, eof), at)
    case 43:
      put_comments(i, take_comments(value, eof), at)
    case _:
      DecOk{i}

# ---------------------------------------------------------------- one line

# S2.27 (spec twin) a refusal is sticky; otherwise apply one member
def member_step(st: Dec, key: String, value: List<&2, Json.Tok>, at: U32, eof: U32) -> Dec:
  match st:
    case DecBad{msg, col}:
      DecBad{msg, col}
    case DecOk{i}:
      put(index_of(known(), key), i, value, at, eof)

# S2.28 (spec twin) the loop over the line's members
def members_go(ms: List<&2, Json.Member>, st: Dec, +eof: U32) -> Dec:
  match ms:
    case Nil{}:
      st
    case Con{Json.Member{key, value, at}, rest}:
      members_go(rest, member_step(st, key, value, at, eof), eof)

# S2.28 (spec twin) is a member with this key present
def has_key(ms: List<&2, Json.Member>, +key: String) -> Bool:
  match ms:
    case Nil{}:
      False{}
    case Con{Json.Member{name, _, _}, rest}:
      (String.eq(name, key) || has_key(rest, key))

# S2.28 (spec twin) the four members with no default, reported in the order serde_json meets them
def missing_pick(id: Bool, title: Bool, created: Bool, updated: Bool) -> String:
  match id title created updated:
    case False{} _ _ _:
      "missing field `id`"
    case True{} False{} _ _:
      "missing field `title`"
    case True{} True{} False{} _:
      "missing field `created_at`"
    case True{} True{} True{} False{}:
      "missing field `updated_at`"
    case True{} True{} True{} True{}:
      ""

# S2.28 (spec twin) route on the missing-member verdict
def checked(+ms: List<&2, Json.Member>, missing: String, +eof: U32) -> Dec:
  match missing:
    case SNil{}:
      members_go(ms, DecOk{Model.blank()}, eof)
    case SCon{h, t}:
      DecBad{SCon{h, t}, eof}

# S2.27 S2.28 (spec twin) the record of a split line
def from_split(sp: Json.Split, eof: U32) -> Dec:
  match sp:
    case Json.SplitBad{msg, at}:
      DecBad{msg, at}
    case Json.SplitOk{+ms}:
      checked(ms, missing_pick(has_key(ms, "id"), has_key(ms, "title"), has_key(ms, "created_at"), has_key(ms, "updated_at")), eof)

# S2.27 (spec twin) the record of a lexed line
def from_lexed(lx: Json.Lexed, +eof: U32) -> Dec:
  match lx:
    case Json.LexBad{msg, at}:
      DecBad{msg, at}
    case Json.LexOk{toks}:
      from_split(Json.members(toks, eof), eof)

# S2.24 S2.27 S2.28 (spec twin) one trimmed line's code points as an issue record.
# `eof` is the line's byte length: the column serde_json reports when the text ends too early.
def issue_of(cs: List<&2, U32>, eof: U32) -> Dec:
  from_lexed(Json.lex(cs), eof)
