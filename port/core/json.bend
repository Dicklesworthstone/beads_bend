# core/json — the JSON lexer for one line of .beads/issues.jsonl (S2.24, S2.27).
# ONE structural loop over the line's code points drives a state record: Bend
# has no mutual recursion and no match on a computed value, so every decision
# is a Bool handed to a small routing def, and an error is sticky (once set,
# later steps pass the state through). The byte column is carried because the
# original's refusal quotes serde_json's message WITH its column
# (`EOF while parsing a string at line 1 column 40`, goldens/error_malformed_jsonl).
# Nothing here consults the original: docs/EXISTING_BEADS_RUST_STRUCTURE.md.
import Base

# S2.24 (data) what a token is (`Kind` is a Bend keyword, hence TokKind); a literal is a number or a word, classified by the reader
type TokKind is Data:
  KLBrace{}
  KRBrace{}
  KLBrack{}
  KRBrack{}
  KColon{}
  KComma{}
  KStr{text: String}
  KLit{text: String}

# S2.27 (data) a token and the byte column of its first byte
type Tok is Data:
  Tok{kind: TokKind, at: U32}

# S2.27 (data) the sticky error: serde_json's message and its byte column
type LexErr is Data:
  NoErr{}
  ErrAt{msg: String, at: U32}

# S2.24 (data) the lexer's mode
type Mode is Data:
  MDefault{}
  MStr{}
  MEsc{}
  MUni{left: Nat, acc: U32}
  MLit{}

# S2.24 (data) the lexer's state: mode, bytes consumed, the current text
# (code points, REVERSED), a pending high surrogate (0 = none), the column the
# current token began at, the tokens so far (REVERSED), the sticky error
type Lex is Data:
  Lex{mode: Mode, col: U32, cur: List<&2, U32>, hi: U32, began: U32, toks: List<&2, Tok>, err: LexErr}

# S2.27 (data) the result of lexing a line
type Lexed is Data:
  LexBad{msg: String, at: U32}
  LexOk{toks: List<&2, Tok>}

# S2.24 (spec twin) a reversed code-point list as a String, in order
def text_of(rev: List<&2, U32>, acc: String) -> String:
  match rev:
    case Nil{}:
      acc
    case Con{c, rest}:
      text_of(rest, SCon{Chr{c}, acc})

# S2.27 (spec twin) the UTF-8 width of a code point: serde_json's column counts BYTES
def width_pick(one: Bool, two: Bool, three: Bool) -> U32:
  match one two three:
    case True{} _ _:
      1
    case False{} True{} _:
      2
    case False{} False{} True{}:
      3
    case False{} False{} False{}:
      4

# S2.27 (spec twin) the UTF-8 width of a code point
def width(+c: U32) -> U32:
  width_pick((c < 128 : U32), (c < 2048 : U32), (c < 65536 : U32))

# S2.24 (spec twin) JSON whitespace: space, tab, line feed, carriage return
def is_ws(+c: U32) -> Bool:
  (U32.is_eq(c, 32) || U32.is_eq(c, 9) || U32.is_eq(c, 10) || U32.is_eq(c, 13))

# S2.24 (spec twin) what ends a literal: whitespace or `,` `}` `]` `:`
def is_delim(+c: U32) -> Bool:
  (is_ws(c) || U32.is_eq(c, 44) || U32.is_eq(c, 125) || U32.is_eq(c, 93) || U32.is_eq(c, 58))

# S2.24 (spec twin) what may begin a literal: `-`, a digit, or a lower-case letter
def is_lit_start(+c: U32) -> Bool:
  (U32.is_eq(c, 45) || ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)))

# S2.27 (spec twin) how many leading code points two texts share
def diff_at(a: String, b: String) -> Nat:
  match a b:
    case SCon{Chr{+x}, ra} SCon{Chr{+y}, rb}:
      Bool.pick(Nat, U32.is_eq(x, y), Nat.add(diff_at(ra, rb), 1n), 0n)
    case _ _:
      0n

# S2.27 (spec twin) a literal against the keyword its first letter starts: a mismatch inside it is `expected ident` at
# that byte; a proper prefix (`tru`) is `expected ident` at the delimiter, or `EOF while parsing a value` at the end
# of the input (`error_jsonl_ident`); a keyword followed by more letters is left to the parser after it
def keyword_error(+text: String, +kw: String, +began: U32, eof: Bool) -> LexErr:
  Bool.pick(LexErr, (Nat.is_lt(diff_at(text, kw), String.length(text)) && Nat.is_lt(diff_at(text, kw), String.length(kw))), ErrAt{"expected ident", (began + U32.from_nat(diff_at(text, kw)) : U32)}, Bool.pick(LexErr, Nat.is_lt(String.length(text), String.length(kw)), Bool.pick(LexErr, eof, ErrAt{"EOF while parsing a value", 0}, ErrAt{"expected ident", (began + U32.from_nat(String.length(text)) : U32)}), NoErr{}))

# S2.24 (spec twin) does a text start with an ASCII digit
def digit_first(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, rest}:
      ((c >= 48 : U32) && (c <= 57 : U32))

# S2.27 (spec twin) a finished literal: `t`, `f` and `n` start a keyword; any other letter cannot start a value
# (`expected value` at its first byte); `-` and a digit start a number, judged by the reader
def lit_error(+text: String, +began: U32, +eof: Bool) -> LexErr:
  Bool.pick(LexErr, String.starts_with(text, "t"), keyword_error(text, "true", began, eof), Bool.pick(LexErr, String.starts_with(text, "f"), keyword_error(text, "false", began, eof), Bool.pick(LexErr, String.starts_with(text, "n"), keyword_error(text, "null", began, eof), Bool.pick(LexErr, (String.starts_with(text, "-") || digit_first(text)), NoErr{}, ErrAt{"expected value", began}))))

# S2.24 (spec twin) the value of a hex digit, or 16 when it is not one
def hex_pick(+c: U32, num: Bool, low: Bool, up: Bool) -> U32:
  match num low up:
    case True{} _ _:
      (c - 48 : U32)
    case False{} True{} _:
      (c - 87 : U32)
    case False{} False{} True{}:
      (c - 55 : U32)
    case False{} False{} False{}:
      16

# S2.24 (spec twin) the value of a hex digit, or 16 when it is not one
def hex_val(+c: U32) -> U32:
  hex_pick(c, ((c >= 48 : U32) && (c <= 57 : U32)), ((c >= 97 : U32) && (c <= 102 : U32)), ((c >= 65 : U32) && (c <= 70 : U32)))

# S2.24 S2.25 (spec twin) push a punctuation token, or report `expected value` at the column of the character's FIRST
# byte (`col` is past its last: a BOM, three bytes, is reported at column 1, `error_jsonl_bom`)
def punct(+c: U32, +col: U32, toks: List<&2, Tok>, lb: Bool, rb: Bool, lk: Bool, rk: Bool, co: Bool, cm: Bool) -> Lex:
  match lb rb lk rk co cm:
    case True{} _ _ _ _ _:
      Lex{MDefault{}, col, Nil{}, 0, 0, Tok{KLBrace{}, col} <> toks, NoErr{}}
    case False{} True{} _ _ _ _:
      Lex{MDefault{}, col, Nil{}, 0, 0, Tok{KRBrace{}, col} <> toks, NoErr{}}
    case False{} False{} True{} _ _ _:
      Lex{MDefault{}, col, Nil{}, 0, 0, Tok{KLBrack{}, col} <> toks, NoErr{}}
    case False{} False{} False{} True{} _ _:
      Lex{MDefault{}, col, Nil{}, 0, 0, Tok{KRBrack{}, col} <> toks, NoErr{}}
    case False{} False{} False{} False{} True{} _:
      Lex{MDefault{}, col, Nil{}, 0, 0, Tok{KColon{}, col} <> toks, NoErr{}}
    case False{} False{} False{} False{} False{} True{}:
      Lex{MDefault{}, col, Nil{}, 0, 0, Tok{KComma{}, col} <> toks, NoErr{}}
    case False{} False{} False{} False{} False{} False{}:
      Lex{MDefault{}, col, Nil{}, 0, 0, toks, ErrAt{"expected value", ((col - width(c) : U32) + 1 : U32)}}

# S2.24 (spec twin) between tokens: skip whitespace, open a string or a literal, or take punctuation
def in_default(+c: U32, +col: U32, toks: List<&2, Tok>, ws: Bool, quote: Bool, lit: Bool) -> Lex:
  match ws quote lit:
    case True{} _ _:
      Lex{MDefault{}, col, Nil{}, 0, 0, toks, NoErr{}}
    case False{} True{} _:
      Lex{MStr{}, col, Nil{}, 0, col, toks, NoErr{}}
    case False{} False{} True{}:
      Lex{MLit{}, col, c <> Nil{}, 0, col, toks, NoErr{}}
    case False{} False{} False{}:
      punct(c, col, toks, U32.is_eq(c, 123), U32.is_eq(c, 125), U32.is_eq(c, 91), U32.is_eq(c, 93), U32.is_eq(c, 58), U32.is_eq(c, 44))

# S2.24 (spec twin) the default-mode step for one code point
def step_default(+c: U32, col: U32, toks: List<&2, Tok>) -> Lex:
  in_default(c, col, toks, is_ws(c), U32.is_eq(c, 34), is_lit_start(c))

# S2.24 (spec twin) inside a string: the closing quote, a backslash, a raw control character, or text.
# A pending high surrogate must be followed by a `\u` escape, so plain text after one is an error.
def in_str(+c: U32, +col: U32, cur: List<&2, U32>, +hi: U32, began: U32, toks: List<&2, Tok>, quote: Bool, slash: Bool, ctl: Bool, pending: Bool) -> Lex:
  match quote slash ctl pending:
    case False{} True{} _ _:
      Lex{MEsc{}, col, cur, hi, began, toks, NoErr{}}
    case _ _ _ True{}:
      Lex{MStr{}, col, cur, hi, began, toks, ErrAt{"unexpected end of hex escape", col}}
    case True{} _ _ False{}:
      Lex{MDefault{}, col, Nil{}, 0, 0, Tok{KStr{text_of(cur, "")}, began} <> toks, NoErr{}}
    case False{} False{} True{} False{}:
      Lex{MStr{}, col, cur, hi, began, toks, ErrAt{"control character (\\u0000-\\u001F) found while parsing a string", col}}
    case False{} False{} False{} False{}:
      Lex{MStr{}, col, c <> cur, 0, began, toks, NoErr{}}

# S2.24 (spec twin) the code point a one-letter escape stands for, or 0 for `u`, or 1 when it is no escape
def esc_pick(q: Bool, b: Bool, s: Bool, eb: Bool, ef: Bool, en: Bool, er: Bool, et: Bool, eu: Bool) -> U32:
  match q b s eb ef en er et eu:
    case True{} _ _ _ _ _ _ _ _:
      34
    case False{} True{} _ _ _ _ _ _ _:
      92
    case False{} False{} True{} _ _ _ _ _ _:
      47
    case False{} False{} False{} True{} _ _ _ _ _:
      8
    case False{} False{} False{} False{} True{} _ _ _ _:
      12
    case False{} False{} False{} False{} False{} True{} _ _ _:
      10
    case False{} False{} False{} False{} False{} False{} True{} _ _:
      13
    case False{} False{} False{} False{} False{} False{} False{} True{} _:
      9
    case False{} False{} False{} False{} False{} False{} False{} False{} True{}:
      0
    case False{} False{} False{} False{} False{} False{} False{} False{} False{}:
      1

# S2.24 (spec twin) after a backslash: route on the escape's meaning
def in_esc(+col: U32, cur: List<&2, U32>, hi: U32, began: U32, toks: List<&2, Tok>, +got: U32, is_u: Bool, bad: Bool) -> Lex:
  match is_u bad:
    case True{} _:
      Lex{MUni{4n, 0}, col, cur, hi, began, toks, NoErr{}}
    case False{} True{}:
      Lex{MStr{}, col, cur, hi, began, toks, ErrAt{"invalid escape", col}}
    case False{} False{}:
      Lex{MStr{}, col, got <> cur, 0, began, toks, NoErr{}}

# S2.24 (spec twin) the escape-mode step for one code point
def step_esc(+c: U32, col: U32, cur: List<&2, U32>, hi: U32, began: U32, toks: List<&2, Tok>) -> Lex:
  in_esc(col, cur, hi, began, toks, esc_pick(U32.is_eq(c, 34), U32.is_eq(c, 92), U32.is_eq(c, 47), U32.is_eq(c, 98), U32.is_eq(c, 102), U32.is_eq(c, 110), U32.is_eq(c, 114), U32.is_eq(c, 116), U32.is_eq(c, 117)), U32.is_eq(c, 117), U32.is_eq(esc_pick(U32.is_eq(c, 34), U32.is_eq(c, 92), U32.is_eq(c, 47), U32.is_eq(c, 98), U32.is_eq(c, 102), U32.is_eq(c, 110), U32.is_eq(c, 114), U32.is_eq(c, 116), U32.is_eq(c, 117)), 1))

# S2.24 (spec twin) a finished `\uXXXX` unit: a high surrogate waits for its low half,
# a low surrogate joins a pending high one, anything else is a scalar. A lone half is an error.
def uni_done(+col: U32, cur: List<&2, U32>, +hi: U32, began: U32, toks: List<&2, Tok>, +unit: U32, is_hi: Bool, is_lo: Bool, pending: Bool) -> Lex:
  match is_hi is_lo pending:
    case True{} _ False{}:
      Lex{MStr{}, col, cur, unit, began, toks, NoErr{}}
    case True{} _ True{}:
      Lex{MStr{}, col, cur, hi, began, toks, ErrAt{"lone leading surrogate in hex escape", col}}
    case False{} True{} True{}:
      Lex{MStr{}, col, ((65536 + (((hi - 55296 : U32) << 10n : U32)) : U32) + (unit - 56320 : U32) : U32) <> cur, 0, began, toks, NoErr{}}
    case False{} True{} False{}:
      Lex{MStr{}, col, cur, hi, began, toks, ErrAt{"lone leading surrogate in hex escape", col}}
    case False{} False{} True{}:
      Lex{MStr{}, col, cur, hi, began, toks, ErrAt{"lone leading surrogate in hex escape", col}}
    case False{} False{} False{}:
      Lex{MStr{}, col, unit <> cur, 0, began, toks, NoErr{}}

# S2.24 (spec twin) one hex digit of a `\uXXXX` escape; the fourth finishes the unit.
# The scrutinees lead the parameter list: a match reads its scrutinees in binder order.
def in_uni(bad: Bool, left: Nat, +col: U32, cur: List<&2, U32>, +hi: U32, began: U32, toks: List<&2, Tok>, +acc: U32) -> Lex:
  match bad left:
    case True{} _:
      Lex{MStr{}, col, cur, hi, began, toks, ErrAt{"invalid escape", col}}
    case False{} 0n:
      Lex{MStr{}, col, cur, hi, began, toks, ErrAt{"invalid escape", col}}
    case False{} 1n+0n:
      uni_done(col, cur, hi, began, toks, acc, ((acc >= 55296 : U32) && (acc <= 56319 : U32)), ((acc >= 56320 : U32) && (acc <= 57343 : U32)), U32.is_ne(hi, 0))
    case False{} 1n+p:
      Lex{MUni{p, acc}, col, cur, hi, began, toks, NoErr{}}

# S2.24 (spec twin) inside a literal: a delimiter ends it and is then taken as a default-mode character (the literal
# is judged where it stands, by the parser: `lit_error`)
def in_lit(+c: U32, +col: U32, cur: List<&2, U32>, began: U32, toks: List<&2, Tok>, ends: Bool) -> Lex:
  match ends:
    case True{}:
      step_default(c, col, Tok{KLit{text_of(cur, "")}, began} <> toks)
    case False{}:
      Lex{MLit{}, col, c <> cur, 0, began, toks, NoErr{}}

# S2.24 (spec twin) route one code point by the mode
def step_mode(mode: Mode, +c: U32, +col: U32, cur: List<&2, U32>, +hi: U32, began: U32, toks: List<&2, Tok>) -> Lex:
  match mode:
    case MDefault{}:
      step_default(c, col, toks)
    case MStr{}:
      in_str(c, col, cur, hi, began, toks, U32.is_eq(c, 34), U32.is_eq(c, 92), (c < 32 : U32), U32.is_ne(hi, 0))
    case MEsc{}:
      step_esc(c, col, cur, hi, began, toks)
    case MUni{left, acc}:
      in_uni(U32.is_eq(hex_val(c), 16), left, col, cur, hi, began, toks, (((acc * 16 : U32)) + hex_val(c) : U32))
    case MLit{}:
      in_lit(c, col, cur, began, toks, is_delim(c))

# S2.27 (spec twin) a set error is sticky: the state passes through unchanged
def step_err(err: LexErr, mode: Mode, c: U32, col: U32, cur: List<&2, U32>, hi: U32, began: U32, toks: List<&2, Tok>) -> Lex:
  match err:
    case ErrAt{msg, at}:
      Lex{mode, col, cur, hi, began, toks, ErrAt{msg, at}}
    case NoErr{}:
      step_mode(mode, c, col, cur, hi, began, toks)

# S2.24 S2.27 (spec twin) one code point: the column advances by its UTF-8 width first
def step(st: Lex, +c: U32) -> Lex:
  match st:
    case Lex{mode, col, cur, hi, began, toks, err}:
      step_err(err, mode, c, (col + width(c) : U32), cur, hi, began, toks)

# S2.24 (spec twin) the loop: the code-point list is the measure
def lex_go(cs: List<&2, U32>, st: Lex) -> Lex:
  match cs:
    case Nil{}:
      st
    case Con{c, rest}:
      lex_go(rest, step(st, c))

# S2.27 (spec twin) the end of the line: an open string is serde_json's
# `EOF while parsing a string`, an open literal is flushed
def finish_mode(mode: Mode, +col: U32, cur: List<&2, U32>, began: U32, toks: List<&2, Tok>) -> Lexed:
  match mode:
    case MDefault{}:
      LexOk{List.reverse(&2, Tok, toks)}
    case MLit{}:
      LexOk{List.reverse(&2, Tok, Tok{KLit{text_of(cur, "")}, began} <> toks)}
    case MStr{}:
      LexBad{"EOF while parsing a string", col}
    case MEsc{}:
      LexBad{"EOF while parsing a string", col}
    case MUni{left, acc}:
      LexBad{"EOF while parsing a string", col}

# S2.27 (spec twin) a sticky error wins over the end-of-line verdict
def finish(st: Lex) -> Lexed:
  match st:
    case Lex{mode, col, cur, hi, began, toks, ErrAt{msg, at}}:
      LexBad{msg, at}
    case Lex{mode, col, cur, hi, began, toks, NoErr{}}:
      finish_mode(mode, col, cur, began, toks)

# S2.24 S2.27 (spec twin) the tokens of one line, or serde_json's message and byte column
def lex(cs: List<&2, U32>) -> Lexed:
  finish(lex_go(cs, Lex{MDefault{}, 0, Nil{}, 0, 0, Nil{}, NoErr{}}))

# ------------------------------------------------------------------ members
# The second pass: the tokens of ONE object become (key, value tokens) pairs.
# It is reused at each nesting level (issue, dependency, comment) by plain
# calls, so no def here recurses into another. A value's own tokens are
# collected with a depth counter; they are interpreted by whoever knows the
# member's shape (core/decode), and an unknown member's value is never
# interpreted at all (S2.29: unknown members are accepted and dropped).

# S2.24 (data) one member of an object: its key, its value's tokens in order, the key's byte column
type Member is Data:
  Member{key: String, value: List<&2, Tok>, at: U32}

# S2.27 (data) the members of an object, or serde_json's message and byte column
type Split is Data:
  SplitBad{msg: String, at: U32}
  SplitOk{members: List<&2, Member>}

# S2.24 (data) where the splitter stands in `{ "k" : v , "k" : v }`
type Phase is Data:
  PStart{}
  PKeyFirst{}
  PKey{}
  PColon{}
  PVal{}
  PAfter{}
  PDone{}

# S2.24 (data) the splitter's state: phase, nesting depth inside the current value, the current key and
# its column, the current value's tokens (REVERSED), the members so far (REVERSED), the sticky error
type Sp is Data:
  Sp{phase: Phase, depth: Nat, key: String, kat: U32, cur: List<&2, Tok>, out: List<&2, Member>, err: LexErr}

# S2.27 (spec twin) the state with an error set
def sp_fail(msg: String, at: U32) -> Sp:
  Sp{PDone{}, 0n, "", 0, Nil{}, Nil{}, ErrAt{msg, at}}

# S2.24 (spec twin) before anything: the object must open with `{`
def sp_start(kind: TokKind, at: U32) -> Sp:
  match kind:
    case KLBrace{}:
      Sp{PKeyFirst{}, 0n, "", 0, Nil{}, Nil{}, NoErr{}}
    case _:
      sp_fail("expected value", at)

# S2.24 (spec twin) where a key may stand: a string opens a member; `}` closes an EMPTY object only
def sp_key(kind: TokKind, at: U32, out: List<&2, Member>, may_close: Bool) -> Sp:
  match kind may_close:
    case KStr{text} _:
      Sp{PColon{}, 0n, text, at, Nil{}, out, NoErr{}}
    case KRBrace{} True{}:
      Sp{PDone{}, 0n, "", 0, Nil{}, out, NoErr{}}
    case KRBrace{} False{}:
      sp_fail("trailing comma", at)
    case _ _:
      sp_fail("key must be a string", at)

# S2.24 (spec twin) after a key: `:`
def sp_colon(kind: TokKind, at: U32, key: String, kat: U32, out: List<&2, Member>) -> Sp:
  match kind:
    case KColon{}:
      Sp{PVal{}, 0n, key, kat, Nil{}, out, NoErr{}}
    case _:
      sp_fail("expected `:`", at)

# S2.27 (spec twin) a literal in a value position: the state goes on, or the literal's refusal (`lit_error`) ends it
def sp_lit(e: LexErr, st: Sp) -> Sp:
  match e:
    case NoErr{}:
      st
    case ErrAt{msg, at}:
      sp_fail(msg, at)

# S2.24 (spec twin) the first token of a value: a scalar is the whole value, a bracket opens a nested one
def sp_val_first(kind: TokKind, +at: U32, key: String, kat: U32, out: List<&2, Member>) -> Sp:
  match kind:
    case KStr{text}:
      Sp{PAfter{}, 0n, key, kat, Tok{KStr{text}, at} <> Nil{}, out, NoErr{}}
    case KLit{+text}:
      sp_lit(lit_error(text, at, False{}), Sp{PAfter{}, 0n, key, kat, Tok{KLit{text}, at} <> Nil{}, out, NoErr{}})
    case KLBrace{}:
      Sp{PVal{}, 1n, key, kat, Tok{KLBrace{}, at} <> Nil{}, out, NoErr{}}
    case KLBrack{}:
      Sp{PVal{}, 1n, key, kat, Tok{KLBrack{}, at} <> Nil{}, out, NoErr{}}
    case _:
      sp_fail("expected value", at)

# S2.24 (spec twin) inside a nested value: brackets move the depth, and the bracket that returns it to zero ends the value
def sp_val_deep(kind: TokKind, +at: U32, depth: Nat, key: String, kat: U32, cur: List<&2, Tok>, out: List<&2, Member>) -> Sp:
  match kind depth:
    case KLBrace{} d:
      Sp{PVal{}, 1n+d, key, kat, Tok{KLBrace{}, at} <> cur, out, NoErr{}}
    case KLBrack{} d:
      Sp{PVal{}, 1n+d, key, kat, Tok{KLBrack{}, at} <> cur, out, NoErr{}}
    case KRBrace{} 1n+0n:
      Sp{PAfter{}, 0n, key, kat, Tok{KRBrace{}, at} <> cur, out, NoErr{}}
    case KRBrack{} 1n+0n:
      Sp{PAfter{}, 0n, key, kat, Tok{KRBrack{}, at} <> cur, out, NoErr{}}
    case KRBrace{} 1n+d:
      Sp{PVal{}, d, key, kat, Tok{KRBrace{}, at} <> cur, out, NoErr{}}
    case KRBrack{} 1n+d:
      Sp{PVal{}, d, key, kat, Tok{KRBrack{}, at} <> cur, out, NoErr{}}
    case KLit{+text} d:
      sp_lit(lit_error(text, at, False{}), Sp{PVal{}, d, key, kat, Tok{KLit{text}, at} <> cur, out, NoErr{}})
    case other d:
      Sp{PVal{}, d, key, kat, Tok{other, at} <> cur, out, NoErr{}}

# S2.24 (spec twin) a value position: its first token, or one more token of a nested value
def sp_val(kind: TokKind, at: U32, depth: Nat, key: String, kat: U32, cur: List<&2, Tok>, out: List<&2, Member>) -> Sp:
  match depth:
    case 0n:
      sp_val_first(kind, at, key, kat, out)
    case 1n+d:
      sp_val_deep(kind, at, 1n+d, key, kat, cur, out)

# S2.24 (spec twin) after a complete value: `,` continues, `}` closes; the member is recorded either way
def sp_after(kind: TokKind, at: U32, key: String, kat: U32, cur: List<&2, Tok>, out: List<&2, Member>) -> Sp:
  match kind:
    case KComma{}:
      Sp{PKey{}, 0n, "", 0, Nil{}, Member{key, List.reverse(&2, Tok, cur), kat} <> out, NoErr{}}
    case KRBrace{}:
      Sp{PDone{}, 0n, "", 0, Nil{}, Member{key, List.reverse(&2, Tok, cur), kat} <> out, NoErr{}}
    case _:
      sp_fail("expected `,` or `}`", at)

# S2.24 (spec twin) route one token by the phase
def sp_phase(phase: Phase, kind: TokKind, at: U32, depth: Nat, key: String, kat: U32, cur: List<&2, Tok>, out: List<&2, Member>) -> Sp:
  match phase:
    case PStart{}:
      sp_start(kind, at)
    case PKeyFirst{}:
      sp_key(kind, at, out, True{})
    case PKey{}:
      sp_key(kind, at, out, False{})
    case PColon{}:
      sp_colon(kind, at, key, kat, out)
    case PVal{}:
      sp_val(kind, at, depth, key, kat, cur, out)
    case PAfter{}:
      sp_after(kind, at, key, kat, cur, out)
    case PDone{}:
      sp_fail("trailing characters", at)

# S2.27 (spec twin) a set error is sticky
def sp_step(st: Sp, tok: Tok) -> Sp:
  match st tok:
    case Sp{phase, depth, key, kat, cur, out, ErrAt{msg, at}} _:
      Sp{phase, depth, key, kat, cur, out, ErrAt{msg, at}}
    case Sp{phase, depth, key, kat, cur, out, NoErr{}} Tok{kind, at}:
      sp_phase(phase, kind, at, depth, key, kat, cur, out)

# S2.24 (spec twin) the loop: the token list is the measure
def sp_go(toks: List<&2, Tok>, st: Sp) -> Sp:
  match toks:
    case Nil{}:
      st
    case Con{tok, rest}:
      sp_go(rest, sp_step(st, tok))

# S2.27 (spec twin) the end of the tokens: only a closed object is complete. `eof` is the line's byte length,
# the column serde_json reports for an input that ends too early
def sp_end(phase: Phase, out: List<&2, Member>, eof: U32) -> Split:
  match phase:
    case PDone{}:
      SplitOk{List.reverse(&2, Member, out)}
    case PStart{}:
      SplitBad{"EOF while parsing a value", eof}
    case _:
      SplitBad{"EOF while parsing an object", eof}

# S2.27 (spec twin) a sticky error wins over the end-of-input verdict
def sp_finish(st: Sp, eof: U32) -> Split:
  match st:
    case Sp{phase, depth, key, kat, cur, out, ErrAt{msg, at}}:
      SplitBad{msg, at}
    case Sp{phase, depth, key, kat, cur, out, NoErr{}}:
      sp_end(phase, out, eof)

# S2.24 S2.27 (spec twin) the members of the object these tokens spell
def members(toks: List<&2, Tok>, eof: U32) -> Split:
  sp_finish(sp_go(toks, Sp{PStart{}, 0n, "", 0, Nil{}, Nil{}, NoErr{}}), eof)

# ------------------------------------------------------------------ values
# A whole JSON text from the command line (`dep add --metadata`, S4.350; `--agent-context`, S4.232) is judged
# as ONE value of any shape: serde_json's structural message with its column, or the value's tokens as
# serde_json prints them back (keys in input order, numbers in serde_json's spelling). The port prints only
# what it can print exactly: a literal that is not `true`, `false`, `null` or a JSON number, an integer outside
# i64/u64, a float with more than 15 significant digits or outside ryu's plain notation, and a repeated key
# make the verdict `CheckOdd` (the port's "not ported yet" failure), never a guess.

# S4.232 (data) an open container: a list, or an object with the keys it has so far
type Frame is Data:
  FArr{}
  FObj{keys: List<&2, String>}

# S4.232 (data) what comes next: a value (`open` right after `[`, `comma` right after `,` in a list); a key
# (`first` right after `{`); the `:`; or, after a complete value, `,` or the innermost closing bracket
type Want is Data:
  WValue{open: Bool, comma: Bool}
  WKey{first: Bool}
  WColon{}
  WAfter{}

# S4.232 (data) the checker's state: what comes next, the open containers (innermost first), the canonical
# tokens so far (REVERSED), the sticky error, and whether something the port does not print was seen
type Vs is Data:
  Vs{want: Want, stack: List<&2, Frame>, out: List<&2, Tok>, err: LexErr, odd: Bool}

# S4.232 (data) the verdict on a whole text
type Checked is Data:
  CheckBad{msg: String, at: U32}
  CheckOdd{}
  CheckOk{toks: List<&2, Tok>}

# S4.232 (data) a literal: its canonical spelling, or one the port does not print
type Lit is Data:
  LitOk{text: String}
  LitOdd{}

# S4.232 (spec twin) a String's code points
def codes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{c}, rest}:
      c <> codes(rest)

# S2.27 (spec twin) the byte length of code points: serde_json's column at the end of the input
def byte_len(cs: List<&2, U32>) -> U32:
  match cs:
    case Nil{}:
      0
    case Con{+c, rest}:
      (width(c) + byte_len(rest) : U32)

# S4.232 (spec twin) is every code point an ASCII digit (and there is at least one)
def digits_go(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      ((c >= 48 : U32) && (c <= 57 : U32) && digits_go(rest))

# S4.232 (spec twin) a non-empty run of ASCII digits
def all_digits(+s: String) -> Bool:
  Bool.not(String.is_empty(s)) && digits_go(s)

# S4.232 (spec twin) JSON's integer part: `0`, or digits without a leading zero
def int_part(+s: String) -> Bool:
  all_digits(s) && (String.eq(s, "0") || Bool.not(String.starts_with(s, "0")))

# S4.232 (spec twin) the leading zeros of a digit string, counted
def zeros_of(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{Chr{+c}, rest}:
      Bool.pick(Nat, U32.is_eq(c, 48), Nat.add(zeros_of(rest), 1n), 0n)

# S4.232 (spec twin) a digit string without its trailing zeros
def trimmed_zeros(+s: String) -> String:
  String.reverse(String.drop(String.reverse(s), zeros_of(String.reverse(s))))

# S4.232 (spec twin) an integer serde_json keeps as an integer: within u64 when positive, within i64 when negative
def int_fits(+digits: String, neg: Bool) -> Bool:
  match neg:
    case False{}:
      (Nat.is_lt(String.length(digits), 20n) || (Nat.is_eq(String.length(digits), 20n) && String.is_le(digits, "18446744073709551615")))
    case True{}:
      (Nat.is_lt(String.length(digits), 19n) || (Nat.is_eq(String.length(digits), 19n) && String.is_le(digits, "9223372036854775808")))

# S4.232 (spec twin) an integer literal: `-0` is serde_json's float `-0.0`; an integer outside i64/u64 is a
# float the port does not print
def int_canon(+text: String, +digits: String, +neg: Bool) -> Lit:
  Bool.pick(Lit, (neg && String.eq(digits, "0")), LitOk{"-0.0"}, Bool.pick(Lit, int_fits(digits, neg), LitOk{text}, LitOdd{}))

# S4.232 (spec twin) significant digits `d` whose decimal point sits at `p` - 1000 (so `0.d` times ten to that power),
# as ryu writes a float: `d000.0`, `d.dd`, or `0.00d`. Only -3 <= p - 1000 <= 15 and at most 15 digits are printed
def float_place(+d: String, +p: Nat, neg: Bool) -> Lit:
  Bool.pick(Lit, (Nat.is_gt(String.length(d), 15n) || Nat.is_lt(p, 997n) || Nat.is_gt(p, 1015n)), LitOdd{}, LitOk{Bool.pick(String, neg, "-", "") ++ Bool.pick(String, Nat.is_ge(p, Nat.add(1000n, String.length(d))), d ++ String.repeat("0", Nat.sub(Nat.sub(p, 1000n), String.length(d))) ++ ".0", Bool.pick(String, Nat.is_gt(p, 1000n), String.take(d, Nat.sub(p, 1000n)) ++ "." ++ String.drop(d, Nat.sub(p, 1000n)), "0." ++ String.repeat("0", Nat.sub(1000n, p)) ++ d))})

# S4.232 (spec twin) a float from all its digits and the biased position of its decimal point: leading zeros move
# the point left, trailing zeros go; no digit left is zero, `0.0` or `-0.0`
def float_digits(+all: String, +p: Nat, +neg: Bool) -> Lit:
  Bool.pick(Lit, String.is_empty(trimmed_zeros(String.drop(all, zeros_of(all)))), LitOk{Bool.pick(String, neg, "-0.0", "0.0")}, float_place(trimmed_zeros(String.drop(all, zeros_of(all))), Nat.sub(p, zeros_of(all)), neg))

# S4.232 (spec twin) the exponent's sign and digits: at most three digits are taken, a longer one is not printed
def float_exp(+ip: String, +fp: String, +exp: String, +neg: Bool) -> Lit:
  Bool.pick(Lit, (all_digits(String.drop(exp, Bool.pick(Nat, (String.starts_with(exp, "-") || String.starts_with(exp, "+")), 1n, 0n))) && Nat.is_lt(String.length(exp), 5n)), float_digits(ip ++ fp, Bool.pick(Nat, String.starts_with(exp, "-"), Nat.sub(Nat.add(String.length(ip), 1000n), Maybe.default(&2, Nat, Nat.read(String.drop(exp, 1n)), 0n)), Nat.add(Nat.add(String.length(ip), 1000n), Maybe.default(&2, Nat, Nat.read(String.drop(exp, Bool.pick(Nat, String.starts_with(exp, "+"), 1n, 0n))), 0n))), neg), LitOdd{})

# S4.232 (spec twin) the mantissa split at `.`: an integer part, then a non-empty fraction when there is a point
def mantissa(parts: List<&2, String>, +exp: String, +text: String, neg: Bool, has_exp: Bool) -> Lit:
  match parts has_exp:
    case Con{+ip, Nil{}} False{}:
      Bool.pick(Lit, int_part(ip), int_canon(text, ip, neg), LitOdd{})
    case Con{+ip, Nil{}} True{}:
      Bool.pick(Lit, int_part(ip), float_exp(ip, "", exp, neg), LitOdd{})
    case Con{+ip, Con{+fp, Nil{}}} _:
      Bool.pick(Lit, (int_part(ip) && all_digits(fp)), float_exp(ip, fp, exp, neg), LitOdd{})
    case _ _:
      LitOdd{}

# S4.232 (spec twin) a number split at the exponent marker (`e` or `E`)
def number_parts(parts: List<&2, String>, +text: String, neg: Bool) -> Lit:
  match parts:
    case Con{m, Nil{}}:
      mantissa(String.split(m, Chr{46}), "0", text, neg, False{})
    case Con{m, Con{e, Nil{}}}:
      mantissa(String.split(m, Chr{46}), e, text, neg, True{})
    case _:
      LitOdd{}

# S4.232 (spec twin) a literal as serde_json prints it back
def lit_canon(+text: String) -> Lit:
  Bool.pick(Lit, (String.eq(text, "true") || String.eq(text, "false") || String.eq(text, "null")), LitOk{text}, number_parts(String.split(String.to_lower(String.drop(text,Bool.pick(Nat, String.starts_with(text, "-"), 1n, 0n))), Chr{101}), text, String.starts_with(text, "-")))

# S4.232 (spec twin) the state with an error set
def vs_fail(msg: String, at: U32) -> Vs:
  Vs{WAfter{}, Nil{}, Nil{}, ErrAt{msg, at}, False{}}

# S4.232 (spec twin) the open containers without the innermost
def popped(stack: List<&2, Frame>) -> List<&2, Frame>:
  match stack:
    case Nil{}:
      Nil{}
    case Con{f, rest}:
      rest

# S4.232 (spec twin) is this key among these
def has_key(keys: List<&2, String>, +key: String) -> Bool:
  match keys:
    case Nil{}:
      False{}
    case Con{k, rest}:
      (String.eq(k, key) || has_key(rest, key))

# S4.232 (spec twin) is this key already in the innermost object
def repeated(stack: List<&2, Frame>, +key: String) -> Bool:
  match stack:
    case Con{FObj{keys}, rest}:
      has_key(keys, key)
    case _:
      False{}

# S4.232 (spec twin) the innermost object with one more key
def keyed(stack: List<&2, Frame>, +key: String) -> List<&2, Frame>:
  match stack:
    case Con{FObj{keys}, rest}:
      FObj{key <> keys} <> rest
    case other:
      other

# S4.232 (spec twin) a literal in a value position
def v_lit(l: Lit, +at: U32, stack: List<&2, Frame>, out: List<&2, Tok>, odd: Bool) -> Vs:
  match l:
    case LitOk{text}:
      Vs{WAfter{}, stack, Tok{KLit{text}, at} <> out, NoErr{}, odd}
    case LitOdd{}:
      Vs{WAfter{}, stack, out, NoErr{}, True{}}

# S4.232 S2.27 (spec twin) a literal in a value position once judged: its refusal (`lit_error`), or the literal
def v_checked(e: LexErr, l: Lit, +at: U32, stack: List<&2, Frame>, out: List<&2, Tok>, odd: Bool) -> Vs:
  match e:
    case NoErr{}:
      v_lit(l, at, stack, out, odd)
    case ErrAt{msg, col}:
      vs_fail(msg, col)

# S4.232 (spec twin) `]` in a value position: it closes an empty list; after `,` it is a trailing comma
def v_close_list(open: Bool, comma: Bool, +at: U32, stack: List<&2, Frame>, out: List<&2, Tok>, odd: Bool) -> Vs:
  match open comma:
    case True{} _:
      Vs{WAfter{}, popped(stack), Tok{KRBrack{}, at} <> out, NoErr{}, odd}
    case False{} True{}:
      vs_fail("trailing comma", at)
    case False{} False{}:
      vs_fail("expected value", at)

# S4.232 (spec twin) a value position: a scalar completes a value, a bracket opens a container
def v_value(kind: TokKind, +at: U32, open: Bool, comma: Bool, stack: List<&2, Frame>, out: List<&2, Tok>, odd: Bool) -> Vs:
  match kind:
    case KStr{text}:
      Vs{WAfter{}, stack, Tok{KStr{text}, at} <> out, NoErr{}, odd}
    case KLit{+text}:
      v_checked(lit_error(text, at, False{}), lit_canon(text), at, stack, out, odd)
    case KLBrace{}:
      Vs{WKey{True{}}, FObj{Nil{}} <> stack, Tok{KLBrace{}, at} <> out, NoErr{}, odd}
    case KLBrack{}:
      Vs{WValue{True{}, False{}}, FArr{} <> stack, Tok{KLBrack{}, at} <> out, NoErr{}, odd}
    case KRBrack{}:
      v_close_list(open, comma, at, stack, out, odd)
    case _:
      vs_fail("expected value", at)

# S4.232 (spec twin) a key position: a string names a member; `}` closes an EMPTY object only
def v_key(kind: TokKind, +at: U32, first: Bool, +stack: List<&2, Frame>, out: List<&2, Tok>, odd: Bool) -> Vs:
  match kind first:
    case KStr{+text} _:
      Vs{WColon{}, keyed(stack, text), Tok{KStr{text}, at} <> out, NoErr{}, (odd || repeated(stack, text))}
    case KRBrace{} True{}:
      Vs{WAfter{}, popped(stack), Tok{KRBrace{}, at} <> out, NoErr{}, odd}
    case KRBrace{} False{}:
      vs_fail("trailing comma", at)
    case _ _:
      vs_fail("key must be a string", at)

# S4.232 (spec twin) after a key: `:`
def v_colon(kind: TokKind, +at: U32, stack: List<&2, Frame>, out: List<&2, Tok>, odd: Bool) -> Vs:
  match kind:
    case KColon{}:
      Vs{WValue{False{}, False{}}, stack, Tok{KColon{}, at} <> out, NoErr{}, odd}
    case _:
      vs_fail("expected `:`", at)

# S4.232 (spec twin) after a complete value: `,` or the innermost closing bracket; nothing more at the top
def v_after(stack: List<&2, Frame>, kind: TokKind, +at: U32, out: List<&2, Tok>, odd: Bool) -> Vs:
  match stack kind:
    case Nil{} _:
      vs_fail("trailing characters", at)
    case Con{FArr{}, rest} KComma{}:
      Vs{WValue{False{}, True{}}, FArr{} <> rest, Tok{KComma{}, at} <> out, NoErr{}, odd}
    case Con{FArr{}, rest} KRBrack{}:
      Vs{WAfter{}, rest, Tok{KRBrack{}, at} <> out, NoErr{}, odd}
    case Con{FArr{}, rest} _:
      vs_fail("expected `,` or `]`", at)
    case Con{FObj{keys}, rest} KComma{}:
      Vs{WKey{False{}}, FObj{keys} <> rest, Tok{KComma{}, at} <> out, NoErr{}, odd}
    case Con{FObj{keys}, rest} KRBrace{}:
      Vs{WAfter{}, rest, Tok{KRBrace{}, at} <> out, NoErr{}, odd}
    case Con{FObj{keys}, rest} _:
      vs_fail("expected `,` or `}`", at)

# S4.232 (spec twin) route one token by what comes next
def vs_want(want: Want, kind: TokKind, at: U32, stack: List<&2, Frame>, out: List<&2, Tok>, odd: Bool) -> Vs:
  match want:
    case WValue{open, comma}:
      v_value(kind, at, open, comma, stack, out, odd)
    case WKey{first}:
      v_key(kind, at, first, stack, out, odd)
    case WColon{}:
      v_colon(kind, at, stack, out, odd)
    case WAfter{}:
      v_after(stack, kind, at, out, odd)

# S4.232 (spec twin) a set error is sticky
def vs_step(st: Vs, tok: Tok) -> Vs:
  match st tok:
    case Vs{want, stack, out, ErrAt{msg, at}, odd} _:
      Vs{want, stack, out, ErrAt{msg, at}, odd}
    case Vs{want, stack, out, NoErr{}, odd} Tok{kind, at}:
      vs_want(want, kind, at, stack, out, odd)

# S4.232 (spec twin) the loop: the token list is the measure
def vs_go(toks: List<&2, Tok>, st: Vs) -> Vs:
  match toks:
    case Nil{}:
      st
    case Con{tok, rest}:
      vs_go(rest, vs_step(st, tok))

# S4.232 (spec twin) a complete value: its tokens, unless something the port does not print was seen
def vs_ok(out: List<&2, Tok>, odd: Bool) -> Checked:
  match odd:
    case True{}:
      CheckOdd{}
    case False{}:
      CheckOk{List.reverse(&2, Tok, out)}

# S4.232 (spec twin) the end of the input: only a complete top-level value is accepted; otherwise serde_json's
# end-of-input message for the innermost container, at the input's byte length
def vs_end(want: Want, stack: List<&2, Frame>, out: List<&2, Tok>, odd: Bool, eof: U32) -> Checked:
  match want stack:
    case WAfter{} Nil{}:
      vs_ok(out, odd)
    case WAfter{} Con{FArr{}, rest}:
      CheckBad{"EOF while parsing a list", eof}
    case WAfter{} Con{FObj{keys}, rest}:
      CheckBad{"EOF while parsing an object", eof}
    case WValue{True{}, comma} _:
      CheckBad{"EOF while parsing a list", eof}
    case WValue{False{}, comma} _:
      CheckBad{"EOF while parsing a value", eof}
    case WKey{first} _:
      CheckBad{"EOF while parsing an object", eof}
    case WColon{} _:
      CheckBad{"EOF while parsing an object", eof}

# S4.232 (spec twin) a sticky error wins over the end-of-input verdict
def vs_finish(st: Vs, eof: U32) -> Checked:
  match st:
    case Vs{want, stack, out, ErrAt{msg, at}, odd}:
      CheckBad{msg, at}
    case Vs{want, stack, out, NoErr{}, odd}:
      vs_end(want, stack, out, odd, eof)

# S4.232 (spec twin) the tokens of a lexed text judged as one value
def checked_lexed(l: Lexed, eof: U32) -> Checked:
  match l:
    case LexBad{msg, at}:
      CheckBad{msg, at}
    case LexOk{toks}:
      vs_finish(vs_go(toks, Vs{WValue{False{}, False{}}, Nil{}, Nil{}, NoErr{}, False{}}), eof)

# S4.350 S4.232 (spec twin) a whole text judged as ONE JSON value
def value(+s: String) -> Checked:
  checked_lexed(lex(codes(s)), byte_len(codes(s)))

