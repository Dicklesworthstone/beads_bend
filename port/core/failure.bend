# core/failure — an error as data and its two renderings (S9.1–S9.5), and the
# serde_json string escaping both renderings and the store share (S5.10).
# Plain mode: `Error: <message>` and an optional `Hint: <hint>` on STDERR.
# JSON mode: a PRETTY-printed `{"error": {...}}` envelope on STDOUT (two-space
# indent, `": "` after a key), with `null` for an absent hint or context, and
# nothing on stderr. Nothing here consults the original.
import Base

# S9.1 (data) one context member's value: a string, a bare literal, or a list of strings
type CtxVal is Data:
  CStr{text: String}
  CBare{text: String}
  CList{items: List<&2, String>}

# S9.1 (data) one context member
type CtxMember is Data:
  CtxMember{key: String, value: CtxVal}

# S9.1 S3.13 (data) the five-member error record plus the process exit code (S9.6)
type Failure is Data:
  Failure{code: String, message: String, hint: Maybe<&2, String>, retryable: Bool, context: List<&2, CtxMember>, exit: U32}

# S5.10 (spec twin) one lower-case hex digit of a control character's \u00XX form
def hex_digit(+n: U32, small: Bool) -> U32:
  match small:
    case True{}:
      (n + 48 : U32)
    case False{}:
      (n + 87 : U32)

# S5.10 (spec twin) a control character below U+0020 pushed, escaped, onto a REVERSED accumulator:
# \b \t \n \f \r where a short form exists, \u00XX with lower-case hex otherwise
def esc_ctl(+c: U32, acc: List<&2, U32>, b: Bool, t: Bool, n: Bool, f: Bool, r: Bool) -> List<&2, U32>:
  match b t n f r:
    case True{} _ _ _ _:
      98 <> (92 <> acc)
    case False{} True{} _ _ _:
      116 <> (92 <> acc)
    case False{} False{} True{} _ _:
      110 <> (92 <> acc)
    case False{} False{} False{} True{} _:
      102 <> (92 <> acc)
    case False{} False{} False{} False{} True{}:
      114 <> (92 <> acc)
    case False{} False{} False{} False{} False{}:
      hex_digit((c .&. 15 : U32), ((c .&. 15 : U32) < 10 : U32)) <> (hex_digit((c >> 4n : U32), True{}) <> (48 <> (48 <> (117 <> (92 <> acc)))))

# S5.10 (spec twin) one code point pushed, escaped, onto a REVERSED accumulator. Only `"`, `\`
# and the controls below U+0020 are escaped: DEL, U+00A0, every non-ASCII scalar, `/`, `<`, `>`, `&` pass raw
def esc_push(+c: U32, acc: List<&2, U32>, quote: Bool, slash: Bool, ctl: Bool) -> List<&2, U32>:
  match quote slash ctl:
    case True{} _ _:
      34 <> (92 <> acc)
    case False{} True{} _:
      92 <> (92 <> acc)
    case False{} False{} True{}:
      esc_ctl(c, acc, U32.is_eq(c, 8), U32.is_eq(c, 9), U32.is_eq(c, 10), U32.is_eq(c, 12), U32.is_eq(c, 13))
    case False{} False{} False{}:
      c <> acc

# S5.10 (spec twin) the loop: the string is the measure, acc is reversed
def esc_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+c}, rest}:
      esc_go(rest, esc_push(c, acc, U32.is_eq(c, 34), U32.is_eq(c, 92), (c < 32 : U32)))

# S5.10 (spec twin) a reversed code-point list as a String, in order
def unreverse(rev: List<&2, U32>, acc: String) -> String:
  match rev:
    case Nil{}:
      acc
    case Con{c, rest}:
      unreverse(rest, SCon{Chr{c}, acc})

# S5.10 (spec twin) a JSON string literal, quotes included
def quoted(s: String) -> String:
  "\"" ++ unreverse(esc_go(s, Nil{}), "\"")

# S9.1 (spec twin) the items of a context list, one per line at eight spaces, comma separated
def list_lines(items: List<&2, String>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{item, Nil{}}:
      "        " ++ quoted(item) ++ "\n"
    case Con{item, rest}:
      "        " ++ quoted(item) ++ ",\n" ++ list_lines(rest)

# S9.1 (spec twin) a context value; a list opens on the key's line and closes at six spaces
def ctx_value(v: CtxVal) -> String:
  match v:
    case CStr{text}:
      quoted(text)
    case CBare{text}:
      text
    case CList{Nil{}}:
      "[]"
    case CList{items}:
      "[\n" ++ list_lines(items) ++ "      ]"

# S9.1 (spec twin) the context members, one per line at six spaces, comma separated
def ctx_lines(members: List<&2, CtxMember>) -> String:
  match members:
    case Nil{}:
      ""
    case Con{CtxMember{key, value}, Nil{}}:
      "      " ++ quoted(key) ++ ": " ++ ctx_value(value) ++ "\n"
    case Con{CtxMember{key, value}, rest}:
      "      " ++ quoted(key) ++ ": " ++ ctx_value(value) ++ ",\n" ++ ctx_lines(rest)

# S9.1 (spec twin) `null` for no context, else a pretty object closing at four spaces
def ctx_text(members: List<&2, CtxMember>) -> String:
  match members:
    case Nil{}:
      "null"
    case Con{first, rest}:
      "{\n" ++ ctx_lines(first <> rest) ++ "    }"

# S9.1 (spec twin) `null` for no hint, else the string
def hint_json(hint: Maybe<&2, String>) -> String:
  match hint:
    case None{}:
      "null"
    case Some{text}:
      quoted(text)

# S9.1 (spec twin) `true` / `false`
def bool_text(b: Bool) -> String:
  match b:
    case True{}:
      "true"
    case False{}:
      "false"

# S9.1 (spec twin) the JSON-mode rendering, written to STDOUT
def json_text(f: Failure) -> String:
  match f:
    case Failure{code, message, hint, retryable, context, _}:
      "{\n  \"error\": {\n    \"code\": " ++ quoted(code) ++ ",\n    \"message\": " ++ quoted(message) ++ ",\n    \"hint\": " ++ hint_json(hint) ++ ",\n    \"retryable\": " ++ bool_text(retryable) ++ ",\n    \"context\": " ++ ctx_text(context) ++ "\n  }\n}\n"

# S9.2 (spec twin) the `Hint:` line, when there is a hint
def hint_plain(hint: Maybe<&2, String>) -> String:
  match hint:
    case None{}:
      ""
    case Some{text}:
      "Hint: " ++ text ++ "\n"

# S9.2 (spec twin) the plain-mode rendering, written to STDERR
def plain_text(f: Failure) -> String:
  match f:
    case Failure{_, message, hint, _, _, _}:
      "Error: " ++ message ++ "\n" ++ hint_plain(hint)

# S9.6 (spec twin) the process exit code of a failure
def exit_of(f: Failure) -> U32:
  match f:
    case Failure{_, _, _, _, _, exit}:
      exit

# S9.8 (spec twin) no `.beads` workspace was found: NOT_INITIALIZED, exit 2
def not_initialized() -> Failure:
  Failure{"NOT_INITIALIZED", "Beads not initialized: run 'br init' first", Some{"Run: br init"}, False{}, Nil{}, 2}

# S9.6 (spec twin) a surface of the contract the port does not implement yet. Exit 1 is the
# contract's internal-error code; the message is the port's own, so every such case FAILS
# its golden, which is the truthful state of an unported command.
def unported() -> Failure:
  Failure{"INTERNAL_ERROR", "beads_bend: this command is not ported yet", None{}, False{}, Nil{}, 1}
