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

# S2.24 (spec twin) push a punctuation token, or report `expected value`
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
      Lex{MDefault{}, col, Nil{}, 0, 0, toks, ErrAt{"expected value", col}}

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

# S2.24 (spec twin) inside a literal: a delimiter ends it and is then taken as a default-mode character
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

# S2.24 (spec twin) the first token of a value: a scalar is the whole value, a bracket opens a nested one
def sp_val_first(kind: TokKind, +at: U32, key: String, kat: U32, out: List<&2, Member>) -> Sp:
  match kind:
    case KStr{text}:
      Sp{PAfter{}, 0n, key, kat, Tok{KStr{text}, at} <> Nil{}, out, NoErr{}}
    case KLit{text}:
      Sp{PAfter{}, 0n, key, kat, Tok{KLit{text}, at} <> Nil{}, out, NoErr{}}
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

