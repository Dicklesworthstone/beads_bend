# core/cli — argv to a command, or the argument parser's refusal (S1.1–S1.30, S1.68–S1.90).
# ONE structural loop over the arguments drives a state record; a refusal is
# sticky (once set, later arguments pass the state through), because Bend has
# no mutual recursion and no match on a computed value: every decision is a
# Bool or a small Data verdict handed to a routing def. The tables the loop
# reads are core/surface.bend. The refusal texts are the original's bytes and
# keep its binary name `br` (DISC-006). Nothing here consults the original.
import Base
import ./surface.bend as Surface

# S1.13 (data) one occurrence of an option, in argv order; an option without a value carries ""
type Occ is Data:
  Occ{key: String, value: String}

# S1.1 S1.25 S1.29 S1.30 (data) what the argument parser answers: a refusal (stderr, exit 2);
# a help request (stdout, exit 0); a bare command group (its long help on stderr, exit 2);
# the version flag; a command of the original outside the port's surface; or a command to run
type Parsed is Data:
  Refused{err: String}
  Helped{path: String, long: Bool}
  GroupHelp{path: String}
  Versioned{}
  Outside{word: String}
  Command{path: String, opts: List<&2, Occ>, words: List<&2, String>}

# S1.30 S1.89 (data) the sticky stop; `Helping` is the `help` subcommand, which still reads the words
# that name the level whose help is wanted (`help list`)
type Halt is Data:
  Going{}
  Halted{p: Parsed}
  Helping{}

# S1.20 (data) an option that is still waiting for its value
type Pending is Data:
  Idle{}
  Awaits{opt: Surface.Opt}

# S1.1 (data) the parser's state at one level of the command line: the level; the occurrences of
# the levels above (REVERSED) and of this one (REVERSED); the arguments present at this level in
# first-seen order (REVERSED), which the usage line echoes; the positionals (REVERSED); the waiting
# option; a refusal held until the next argument settles it; whether `--` was seen; whether this
# level has seen no argument yet; whether the rest of a short cluster was taken as a value
type St is Data:
  St{cmd: Surface.Cmd, outer: List<&2, Occ>, seen: List<&2, Occ>, used: List<&2, String>, words: List<&2, String>, pending: Pending, held: String, trailing: Bool, fresh: Bool, skip: Bool, halt: Halt}

# ---------------------------------------------------------------- text

# S1.10 (spec twin) a String as code points
def codes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{c}, rest}:
      c <> codes(rest)

# S1.10 (spec twin) code points as a String, in order
def text(cs: List<&2, U32>) -> String:
  match cs:
    case Nil{}:
      ""
    case Con{c, rest}:
      SCon{Chr{c}, text(rest)}

# S1.10 (spec twin) a REVERSED code-point list as a String, in order
def text_rev(rev: List<&2, U32>, acc: String) -> String:
  match rev:
    case Nil{}:
      acc
    case Con{c, rest}:
      text_rev(rest, SCon{Chr{c}, acc})

# S1.13 (spec twin) is this word in the list
def has(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{y, rest}:
      (String.eq(y, x) || has(rest, x))

# S1.12 (spec twin) has this option occurred at this level
def occurred(seen: List<&2, Occ>, +key: String) -> Bool:
  match seen:
    case Nil{}:
      False{}
    case Con{Occ{k, v}, rest}:
      (String.eq(k, key) || occurred(rest, key))

# ---------------------------------------------------------------- the tables

# S1.3 (spec twin) an option's fields
def key_of(o: Surface.Opt) -> String:
  match o:
    case Surface.Opt{key, short, alias, value, repeat, optional, hyphen, check}:
      key

# S1.3 (spec twin) does the option take a value
def takes_value(o: Surface.Opt) -> Bool:
  match o:
    case Surface.Opt{key, short, alias, value, repeat, optional, hyphen, check}:
      Bool.not(String.is_empty(value))

# S1.13 (spec twin) may the option be given more than once
def repeats(o: Surface.Opt) -> Bool:
  match o:
    case Surface.Opt{key, short, alias, value, repeat, optional, hyphen, check}:
      repeat

# S1.49 (spec twin) may the option stand without its value
def is_optional(o: Surface.Opt) -> Bool:
  match o:
    case Surface.Opt{key, short, alias, value, repeat, optional, hyphen, check}:
      optional

# S1.36 (spec twin) may the option's value begin with `-`
def accepts_hyphen(o: Surface.Opt) -> Bool:
  match o:
    case Surface.Opt{key, short, alias, value, repeat, optional, hyphen, check}:
      hyphen

# S1.21 (spec twin) how the parser checks the option's value
def check_of(o: Surface.Opt) -> Surface.Check:
  match o:
    case Surface.Opt{key, short, alias, value, repeat, optional, hyphen, check}:
      check

# S1.20 S1.72 (spec twin) an option as the messages print it: `--json`, `--limit <LIMIT>`, `--assignee [<ASSIGNEE>]`
def shown_pick(key: String, value: String, plain: Bool, optional: Bool) -> String:
  match plain optional:
    case True{} _:
      "--" ++ key
    case False{} False{}:
      "--" ++ key ++ " <" ++ value ++ ">"
    case False{} True{}:
      "--" ++ key ++ " [<" ++ value ++ ">]"

# S1.20 (spec twin) an option as the messages print it
def shown(o: Surface.Opt) -> String:
  match o:
    case Surface.Opt{key, short, alias, +value, repeat, optional, hyphen, check}:
      shown_pick(key, value, String.is_empty(value), optional)

# S1.3 S1.29 (spec twin) a level's fields
def path_of(c: Surface.Cmd) -> String:
  match c:
    case Surface.Cmd{path, opts, pos, clashes, subs, need_sub}:
      path

# S1.24 (spec twin) a level's positionals
def pos_of(c: Surface.Cmd) -> List<&2, Surface.Pos>:
  match c:
    case Surface.Cmd{path, opts, pos, clashes, subs, need_sub}:
      pos

# S1.74 (spec twin) a level's exclusions
def clashes_of(c: Surface.Cmd) -> List<&2, Surface.Clash>:
  match c:
    case Surface.Cmd{path, opts, pos, clashes, subs, need_sub}:
      clashes

# S1.16 (spec twin) a level's subcommand words
def subs_of(c: Surface.Cmd) -> List<&2, Surface.Name>:
  match c:
    case Surface.Cmd{path, opts, pos, clashes, subs, need_sub}:
      subs

# S1.16 (spec twin) must a subcommand follow
def needs_sub(c: Surface.Cmd) -> Bool:
  match c:
    case Surface.Cmd{path, opts, pos, clashes, subs, need_sub}:
      need_sub

# S1.29 (spec twin) `--version` exists on the top level only
def with_version(top: Bool) -> List<&2, Surface.Opt>:
  match top:
    case True{}:
      Surface.version_opt() <> Nil{}
    case False{}:
      Nil{}

# S1.3 S1.29 (spec twin) every option a level accepts, in declaration order: its own, the globals, help, (version)
def all_opts(c: Surface.Cmd) -> List<&2, Surface.Opt>:
  match c:
    case Surface.Cmd{path, opts, pos, clashes, subs, need_sub}:
      List.append(&2, Surface.Opt, opts, List.append(&2, Surface.Opt, Surface.globals(), Surface.help_opt() <> with_version(String.is_empty(path))))

# S1.11 (spec twin) does this long name spell the option: its own name, or its alias when it has one
def spells(o: Surface.Opt, +name: String) -> Bool:
  match o:
    case Surface.Opt{key, short, +alias, value, repeat, optional, hyphen, check}:
      (String.eq(key, name) || (Bool.not(String.is_empty(alias)) && String.eq(alias, name)))

# S1.11 (spec twin) keep the first hit
def first_opt(+o: Surface.Opt, hit: Bool, later: Maybe<&2, Surface.Opt>) -> Maybe<&2, Surface.Opt>:
  match hit:
    case True{}:
      Some{o}
    case False{}:
      later

# S1.11 (spec twin) the option a long name spells exactly; names are never abbreviated
def opt_named(opts: List<&2, Surface.Opt>, +name: String) -> Maybe<&2, Surface.Opt>:
  match opts:
    case Nil{}:
      None{}
    case Con{+o, rest}:
      first_opt(o, spells(o, name), opt_named(rest, name))

# S1.69 (spec twin) is this the option's short letter
def short_is(o: Surface.Opt, c: U32) -> Bool:
  match o:
    case Surface.Opt{key, short, alias, value, repeat, optional, hyphen, check}:
      U32.is_eq(short, c)

# S1.69 (spec twin) the option a short letter names
def opt_short(opts: List<&2, Surface.Opt>, +c: U32) -> Maybe<&2, Surface.Opt>:
  match opts:
    case Nil{}:
      None{}
    case Con{+o, rest}:
      first_opt(o, short_is(o, c), opt_short(rest, c))

# S1.16 (spec twin) keep the first hit
def first_name(+n: Surface.Name, hit: Bool, later: Maybe<&2, Surface.Name>) -> Maybe<&2, Surface.Name>:
  match hit:
    case True{}:
      Some{n}
    case False{}:
      later

# S1.16 (spec twin) is this the subcommand's word
def word_is(n: Surface.Name, word: String) -> Bool:
  match n:
    case Surface.Name{w, target, scope}:
      String.eq(w, word)

# S1.16 (spec twin) the subcommand a word names exactly
def sub_named(subs: List<&2, Surface.Name>, +word: String) -> Maybe<&2, Surface.Name>:
  match subs:
    case Nil{}:
      None{}
    case Con{+n, rest}:
      first_name(n, word_is(n, word), sub_named(rest, word))

# S1.24 (spec twin) keep the first hit
def first_pos(+p: Surface.Pos, hit: Bool, later: Maybe<&2, Surface.Pos>) -> Maybe<&2, Surface.Pos>:
  match hit:
    case True{}:
      Some{p}
    case False{}:
      later

# S1.24 (spec twin) is this the positional's placeholder
def pos_is(p: Surface.Pos, name: String) -> Bool:
  match p:
    case Surface.Pos{n, required, many}:
      String.eq(n, name)

# S1.24 (spec twin) the positional with this placeholder
def pos_named(ps: List<&2, Surface.Pos>, +name: String) -> Maybe<&2, Surface.Pos>:
  match ps:
    case Nil{}:
      None{}
    case Con{+p, rest}:
      first_pos(p, pos_is(p, name), pos_named(rest, name))

# ---------------------------------------------------------------- similarity (S1.80–S1.82)

# S1.80 (data) one code point of the candidate and whether a match already took it
type Slot is Data:
  Slot{c: U32, hit: Bool}

# S1.80 (data) did a search find a free equal code point inside the window, and the slots afterwards
type Marked is Data:
  Marked{found: Bool, slots: List<&2, Slot>}

# S1.80 (data) the matching so far: the candidate's slots and the typed word's matched code points (REVERSED)
type Match is Data:
  Match{slots: List<&2, Slot>, am: List<&2, U32>}

# S1.80 (spec twin) a candidate as untaken slots
def slots_of(cs: List<&2, U32>) -> List<&2, Slot>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{c, rest}:
      Slot{c, False{}} <> slots_of(rest)

# S1.80 (spec twin) take this slot, or keep looking
def mark_put(+sc: U32, hit: Bool, +rest: List<&2, Slot>, here: Bool, later: Marked) -> Marked:
  match here later:
    case True{} _:
      Marked{True{}, Slot{sc, True{}} <> rest}
    case False{} Marked{found, slots}:
      Marked{found, Slot{sc, hit} <> slots}

# S1.80 (spec twin) the FIRST free slot holding `c` whose index j satisfies lo <= j < hi
def mark(slots: List<&2, Slot>, +c: U32, +j: Nat, +lo: Nat, +hi: Nat) -> Marked:
  match slots:
    case Nil{}:
      Marked{False{}, Nil{}}
    case Con{Slot{+sc, +hit}, +rest}:
      mark_put(sc, hit, rest, (Bool.not(hit) && U32.is_eq(sc, c) && Nat.is_le(lo, j) && Nat.is_lt(j, hi)), mark(rest, c, Nat.add(j, 1n), lo, hi))

# S1.80 (spec twin) fold one search into the matching
def absorb(m: Marked, c: U32, am: List<&2, U32>) -> Match:
  match m:
    case Marked{True{}, slots}:
      Match{slots, c <> am}
    case Marked{False{}, slots}:
      Match{slots, am}

# S1.80 (spec twin) the typed word's code points, left to right; i is the index, r the window's radius
def matching(a: List<&2, U32>, m: Match, +i: Nat, +r: Nat) -> Match:
  match a m:
    case Nil{} Match{slots, am}:
      Match{slots, am}
    case Con{+c, rest} Match{slots, am}:
      matching(rest, absorb(mark(slots, c, 0n, Nat.sub(i, r), Nat.add(i, Nat.add(r, 1n))), c, am), Nat.add(i, 1n), r)

# S1.80 (spec twin) the candidate's matched code points, in the candidate's order
def taken(slots: List<&2, Slot>) -> List<&2, U32>:
  match slots:
    case Nil{}:
      Nil{}
    case Con{Slot{c, True{}}, rest}:
      c <> taken(rest)
    case Con{Slot{c, False{}}, rest}:
      taken(rest)

# S1.80 (spec twin) how many aligned pairs differ
def differing(xs: List<&2, U32>, ys: List<&2, U32>) -> Nat:
  match xs ys:
    case Con{x, xr} Con{y, yr}:
      Nat.add(Bool.pick(Nat, U32.is_eq(x, y), 0n, 1n), differing(xr, yr))
    case _ _:
      0n

# S1.80 (data) a similarity as the exact fraction num/den, the word it belongs to, and how the original's 64-bit
# arithmetic judges it when it is EXACTLY 0.7 (`tie`: above, i.e. similar)
type Cand is Data:
  Cand{num: Nat, den: Nat, word: String, tie: Bool}

# S1.80 (spec twin) the original's verdict at an exact 0.7: `(m/la + m/lb + (m-t)/m) / 3.0` in binary64 rounds to
# 0.7000000000000001, above 0.7, for every exact tie a candidate of at most 19 code points (the longest name the
# tables hold, `acceptance-criteria`) can reach, except (la, lb, m, t) = (25, 10, 10, 3), (60, 12, 11, 0), (30, 15, 11, 0),
# which round to 0.6999999999999998. Enumerated over every feasible tuple (m ≤ lb ≤ 19, la ≤ 10m, t ≤ m/2; OQ-106),
# measured on `usage_enum_tie_similar`
def tie_above(+la: Nat, +lb: Nat, +m: Nat, +t: Nat) -> Bool:
  Bool.not(((Nat.is_eq(la, 25n) && Nat.is_eq(lb, 10n) && Nat.is_eq(m, 10n) && Nat.is_eq(t, 3n)) || (Nat.is_eq(la, 60n) && Nat.is_eq(lb, 12n) && Nat.is_eq(m, 11n) && Nat.is_eq(t, 0n)) || (Nat.is_eq(la, 30n) && Nat.is_eq(lb, 15n) && Nat.is_eq(m, 11n) && Nat.is_eq(t, 0n))))

# S1.80 (spec twin) the Jaro similarity from its counts: (m/la + m/lb + (m-t)/m) / 3 as one fraction; 0 when nothing matches
def jaro_of(+m: Nat, +t: Nat, +la: Nat, +lb: Nat, word: String, none: Bool) -> Cand:
  match none:
    case True{}:
      Cand{0n, 1n, word, False{}}
    case False{}:
      Cand{Nat.add(Nat.add(Nat.mul(Nat.mul(m, m), lb), Nat.mul(Nat.mul(m, m), la)), Nat.mul(Nat.mul(Nat.sub(m, t), la), lb)), Nat.mul(Nat.mul(Nat.mul(3n, la), lb), m), word, tie_above(la, lb, m, t)}

# S1.80 (spec twin) the counts of a finished matching: m matches, t = half the out-of-order ones
def jaro_counts(done: Match, +la: Nat, +lb: Nat, word: String) -> Cand:
  match done:
    case Match{slots, +am}:
      jaro_of(List.length(&2, U32, am), Nat.div(differing(List.reverse(&2, U32, am), taken(slots)), 2n), la, lb, word, List.is_empty(&2, U32, am))

# S1.80 (spec twin) the similarity with both lengths known; the window's radius is max(la, lb)/2 - 1, never below 0
def jaro_sized(a: List<&2, U32>, +word: String, +la: Nat, +lb: Nat) -> Cand:
  jaro_counts(matching(a, Match{slots_of(codes(word)), Nil{}}, 0n, Nat.sub(Nat.div(Nat.max(la, lb), 2n), 1n)), la, lb, word)

# S1.80 (spec twin) the similarity of a typed word to one candidate
def jaro(+a: List<&2, U32>, +word: String) -> Cand:
  jaro_sized(a, word, List.length(&2, U32, a), String.length(word))

# S1.80 (spec twin) a candidate is kept when its similarity is ABOVE 0.7 as the original computes it: 10*num > 7*den,
# or exactly 0.7 where binary64 rounds above (`count --by staqq` offers `status`: (3/5 + 3/6 + 1)/3)
def close_enough(c: Cand) -> Bool:
  match c:
    case Cand{+num, +den, word, tie}:
      (Nat.is_gt(Nat.mul(10n, num), Nat.mul(7n, den)) || (Nat.is_eq(Nat.mul(10n, num), Nat.mul(7n, den)) && tie))

# S1.80 (spec twin) the order of the tip: ascending similarity; equal ones keep their declaration order
def cand_le(x: Cand, y: Cand) -> Bool:
  match x y:
    case Cand{xn, xd, xw, xt} Cand{yn, yd, yw, yt}:
      Nat.is_le(Nat.mul(xn, yd), Nat.mul(yn, xd))

# S1.80 (spec twin) keep a candidate that is close enough
def cand_keep(c: Cand, keep: Bool, rest: List<&2, Cand>) -> List<&2, Cand>:
  match keep:
    case True{}:
      c <> rest
    case False{}:
      rest

# S1.80 (spec twin) one candidate word, scored and filtered
def cand_push(+c: Cand, rest: List<&2, Cand>) -> List<&2, Cand>:
  cand_keep(c, close_enough(c), rest)

# S1.80 (spec twin) every candidate word scored, the close ones kept, in declaration order
def similar_go(+a: List<&2, U32>, words: List<&2, String>) -> List<&2, Cand>:
  match words:
    case Nil{}:
      Nil{}
    case Con{w, rest}:
      cand_push(jaro(a, w), similar_go(a, rest))

# S1.80 (spec twin) the candidates close enough to the typed word, in ascending similarity
def similar(a: List<&2, U32>, words: List<&2, String>) -> List<&2, Cand>:
  List.sort(~Cand, ~cand_le, similar_go(a, words))

# S1.80 (spec twin) a candidate's word
def cand_word(c: Cand) -> String:
  match c:
    case Cand{num, den, word, tie}:
      word

# S1.81 (spec twin) the most similar candidate: the LAST of the ascending list, "" when there is none
def best(cands: List<&2, Cand>, sofar: String) -> String:
  match cands:
    case Nil{}:
      sofar
    case Con{c, rest}:
      best(rest, cand_word(c))

# S1.82 (spec twin) the candidates quoted and separated by `, `: `'lint', 'list'`
def quoted_words(cands: List<&2, Cand>) -> List<&2, String>:
  match cands:
    case Nil{}:
      Nil{}
    case Con{c, rest}:
      ("'" ++ cand_word(c) ++ "'") <> quoted_words(rest)

# S1.81 (spec twin) an option's name, then its alias when it has one
def long_names_put(key: String, alias: String, bare: Bool, rest: List<&2, String>) -> List<&2, String>:
  match bare:
    case True{}:
      key <> rest
    case False{}:
      key <> alias <> rest

# S1.81 (spec twin) the long names a level's options answer to, in declaration order: each name, then its alias
def long_names(opts: List<&2, Surface.Opt>) -> List<&2, String>:
  match opts:
    case Nil{}:
      Nil{}
    case Con{Surface.Opt{key, short, +alias, value, repeat, optional, hyphen, check}, rest}:
      long_names_put(key, alias, String.is_empty(alias), long_names(rest))

# S1.82 (spec twin) the words of a level's subcommands, in declaration order
def sub_words(subs: List<&2, Surface.Name>) -> List<&2, String>:
  match subs:
    case Nil{}:
      Nil{}
    case Con{Surface.Name{word, target, scope}, rest}:
      word <> sub_words(rest)

# ---------------------------------------------------------------- value checks (S1.21–S1.23, S1.76–S1.79)

# S1.21 (data) what an integer's spelling is: empty, not a number, or a sign and a magnitude
# (decimal digits, leading zeros removed, so zero is the empty list)
type Num is Data:
  NumEmpty{}
  NumBad{}
  NumOk{neg: Bool, mag: List<&2, U32>}

# S1.21 (spec twin) every code point is an ASCII digit
def all_digits(cs: List<&2, U32>) -> Bool:
  match cs:
    case Nil{}:
      True{}
    case Con{+c, rest}:
      (((c >= 48 : U32) && (c <= 57 : U32)) && all_digits(rest))

# S1.21 (spec twin) leading zeros carry no magnitude
def strip_zeros(cs: List<&2, U32>) -> List<&2, U32>:
  match cs:
    case Con{48, rest}:
      strip_zeros(rest)
    case other:
      other

# S1.21 (spec twin) route on "at least one digit and nothing else"
def num_body_pick(neg: Bool, cs: List<&2, U32>, ok: Bool) -> Num:
  match ok:
    case True{}:
      NumOk{neg, strip_zeros(cs)}
    case False{}:
      NumBad{}

# S1.21 (spec twin) what follows the sign
def num_body(neg: Bool, +cs: List<&2, U32>) -> Num:
  num_body_pick(neg, cs, (Bool.not(List.is_empty(&2, U32, cs)) && all_digits(cs)))

# S1.21 (spec twin) an integer's spelling: one optional `+`, or one `-` when the type is signed, then digits
def read_signed(cs: List<&2, U32>) -> Num:
  match cs:
    case Nil{}:
      NumEmpty{}
    case Con{43, rest}:
      num_body(False{}, rest)
    case Con{45, rest}:
      num_body(True{}, rest)
    case Con{c, rest}:
      num_body(False{}, c <> rest)

# S1.21 (spec twin) the same for an unsigned type, where `-` is not a digit
def read_unsigned(cs: List<&2, U32>) -> Num:
  match cs:
    case Nil{}:
      NumEmpty{}
    case Con{43, rest}:
      num_body(False{}, rest)
    case Con{c, rest}:
      num_body(False{}, c <> rest)

# S1.22 (spec twin) compare two lengths: 0 shorter, 1 equal, 2 longer
def len_cmp(xs: List<&2, U32>, ys: List<&2, U32>) -> U32:
  match xs ys:
    case Nil{} Nil{}:
      1
    case Nil{} Con{y, yr}:
      0
    case Con{x, xr} Nil{}:
      2
    case Con{x, xr} Con{y, yr}:
      len_cmp(xr, yr)

# S1.22 (spec twin) the first differing digit decides
def lex_pick(lt: Bool, gt: Bool, later: U32) -> U32:
  match lt gt:
    case True{} _:
      0
    case False{} True{}:
      2
    case False{} False{}:
      later

# S1.22 (spec twin) compare two digit strings of equal length: 0 less, 1 equal, 2 greater
def lex_cmp(xs: List<&2, U32>, ys: List<&2, U32>) -> U32:
  match xs ys:
    case Con{+x, xr} Con{+y, yr}:
      lex_pick((x < y : U32), (x > y : U32), lex_cmp(xr, yr))
    case _ _:
      1

# S1.22 (spec twin) a longer magnitude is greater; equal lengths compare digit by digit
def mag_pick(+by_len: U32, by_lex: U32) -> U32:
  match by_len:
    case 1:
      by_lex
    case _:
      by_len

# S1.22 (spec twin) compare two magnitudes without leading zeros: 0 less, 1 equal, 2 greater
def mag_cmp(+xs: List<&2, U32>, +ys: List<&2, U32>) -> U32:
  mag_pick(len_cmp(xs, ys), lex_cmp(xs, ys))

# S1.22 (spec twin) is the magnitude above this decimal limit
def exceeds(mag: List<&2, U32>, limit: String) -> Bool:
  U32.is_eq(mag_cmp(mag, codes(limit)), 2)

# S1.21 S1.77 (spec twin) why an unsigned 64-bit value is refused, "" when it is accepted
def unsigned_why(n: Num) -> String:
  match n:
    case NumEmpty{}:
      "cannot parse integer from empty string"
    case NumBad{}:
      "invalid digit found in string"
    case NumOk{neg, mag}:
      Bool.pick(String, exceeds(mag, "18446744073709551615"), "number too large to fit in target type", "")

# S1.22 (spec twin) an integer as the range message prints it: no `+`, no leading zeros, `-0` is `0`
def canon(neg: Bool, mag: List<&2, U32>) -> String:
  match neg mag:
    case _ Nil{}:
      "0"
    case True{} Con{d, rest}:
      "-" ++ text(d <> rest)
    case False{} Con{d, rest}:
      text(d <> rest)

# S1.22 (spec twin) route on "outside 64 signed bits" and "outside the option's range"
def ranged_pick(+neg: Bool, mag: List<&2, U32>, hi_mag: String, lo_text: String, over: Bool, out: Bool) -> String:
  match over out:
    case True{} _:
      Bool.pick(String, neg, "number too small to fit in target type", "number too large to fit in target type")
    case False{} True{}:
      canon(neg, mag) ++ " is not in " ++ lo_text ++ "..=" ++ hi_mag
    case False{} False{}:
      ""

# S1.22 (spec twin) why a ranged value is refused: it is read as a signed 64-bit integer first, then held to the range
def ranged_why(n: Num, lo_mag: String, +hi_mag: String, lo_text: String) -> String:
  match n:
    case NumEmpty{}:
      "cannot parse integer from empty string"
    case NumBad{}:
      "invalid digit found in string"
    case NumOk{+neg, +mag}:
      ranged_pick(neg, mag, hi_mag, lo_text, Bool.pick(Bool, neg, exceeds(mag, "9223372036854775808"), exceeds(mag, "9223372036854775807")), Bool.pick(Bool, neg, exceeds(mag, lo_mag), exceeds(mag, hi_mag)))

# S1.20 (spec twin) the line every refusal ends with, after one blank line
def tail() -> String:
  "\nFor more information, try '--help'.\n"

# S1.21 (spec twin) the refusal of a value with a reason, "" when there is no reason
def invalid(o: Surface.Opt, v: String, why: String) -> String:
  match why:
    case SNil{}:
      ""
    case SCon{h, t}:
      "error: invalid value '" ++ v ++ "' for '" ++ shown(o) ++ "': " ++ SCon{h, t} ++ "\n" ++ tail()

# S1.79 (spec twin) the tip under the possible values, when one of them is similar to what was typed
def value_tip(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{h, t}:
      "\n  tip: a similar value exists: '" ++ SCon{h, t} ++ "'\n"

# S1.23 (spec twin) the refusal of a word outside a fixed list, "" when it is a member
def choice_error(o: Surface.Opt, +v: String, +values: List<&2, String>, member: Bool) -> String:
  match member:
    case True{}:
      ""
    case False{}:
      "error: invalid value '" ++ v ++ "' for '" ++ shown(o) ++ "'\n  [possible values: " ++ String.join(values, ", ") ++ "]\n" ++ value_tip(best(similar(codes(v), values), "")) ++ tail()

# S1.21 S1.22 S1.23 (spec twin) route on how the option's value is checked
def check_pick(o: Surface.Opt, +v: String, c: Surface.Check) -> String:
  match c:
    case Surface.Free{}:
      ""
    case Surface.Unsigned{}:
      invalid(o, v, unsigned_why(read_unsigned(codes(v))))
    case Surface.Ranged{lo_mag, hi_mag, lo_text}:
      invalid(o, v, ranged_why(read_signed(codes(v)), lo_mag, hi_mag, lo_text))
    case Surface.Choice{+values}:
      choice_error(o, v, values, has(values, v))

# S1.21 S1.22 S1.23 (spec twin) the argument parser's own refusal of a value, "" when it accepts it
def check_error(+o: Surface.Opt, v: String) -> String:
  check_pick(o, v, check_of(o))

# ---------------------------------------------------------------- the usage line (S1.70–S1.73)

# S1.71 (spec twin) a positional as usage and messages print it: `<NAME>` when required or present, else `[NAME]`; `...` when it repeats
def pos_text(name: String, angle: Bool, many: Bool) -> String:
  match angle many:
    case True{} True{}:
      "<" ++ name ++ ">..."
    case True{} False{}:
      "<" ++ name ++ ">"
    case False{} True{}:
      "[" ++ name ++ "]..."
    case False{} False{}:
      "[" ++ name ++ "]"

# S1.71 (spec twin) a positional, forced into angle brackets when it is present
def pos_shown(p: Surface.Pos, forced: Bool) -> String:
  match p:
    case Surface.Pos{name, required, many}:
      pos_text(name, (required || forced), many)

# S1.71 (spec twin) every positional of the level, each preceded by a space
def usage_pos(ps: List<&2, Surface.Pos>, +used: List<&2, String>) -> List<&2, String>:
  match ps:
    case Nil{}:
      Nil{}
    case Con{Surface.Pos{+name, required, many}, rest}:
      " " <> pos_text(name, (required || has(used, name)), many) <> usage_pos(rest, used)

# S1.70 (spec twin) one present option, preceded by a space; a positional's placeholder answers nothing here
def usage_opt(found: Maybe<&2, Surface.Opt>) -> String:
  match found:
    case None{}:
      ""
    case Some{o}:
      " " ++ shown(o)

# S1.70 (spec twin) the options present at this level, in first-seen order
def usage_opts(used: List<&2, String>, +all: List<&2, Surface.Opt>) -> List<&2, String>:
  match used:
    case Nil{}:
      Nil{}
    case Con{id, rest}:
      usage_opt(opt_named(all, id)) <> usage_opts(rest, all)

# S1.72 (spec twin) the subcommand tag: none, `<COMMAND>` when one must follow, `[COMMAND]` when one may
def usage_sub(none: Bool, need: Bool) -> String:
  match none need:
    case True{} _:
      ""
    case False{} True{}:
      " <COMMAND>"
    case False{} False{}:
      " [COMMAND]"

# S1.70 (spec twin) `[OPTIONS]` stands only when no argument of this level is named
def usage_tag(bare: Bool) -> String:
  match bare:
    case True{}:
      " [OPTIONS]"
    case False{}:
      ""

# S1.70 (spec twin) the words that lead to the level, each preceded by a space
def usage_path(path: String) -> String:
  match path:
    case SNil{}:
      ""
    case SCon{h, t}:
      " " ++ SCon{h, t}

# S1.70–S1.73 (spec twin) the usage line for a level, given the arguments to name (in first-seen order)
def usage(+c: Surface.Cmd, +used: List<&2, String>) -> String:
  "Usage: br" ++ usage_path(path_of(c)) ++ usage_tag(List.is_empty(&2, String, used)) ++ String.concat(usage_opts(used, all_opts(c))) ++ String.concat(usage_pos(pos_of(c), used)) ++ usage_sub(List.is_empty(&2, Surface.Name, subs_of(c)), needs_sub(c))

# ---------------------------------------------------------------- the refusals (S1.12, S1.15–S1.24, S1.68–S1.75)

# S1.15 S1.19 (spec twin) the tip under an unexpected argument: the similar option wins over the `--` advice
def arg_tip(+arg: String, similar_name: String, dd: Bool) -> String:
  match similar_name dd:
    case SCon{h, t} _:
      "\n  tip: a similar argument exists: '--" ++ SCon{h, t} ++ "'\n"
    case SNil{} True{}:
      "\n  tip: to pass '" ++ arg ++ "' as a value, use '-- " ++ arg ++ "'\n"
    case SNil{} False{}:
      ""

# S1.15 S1.19 (spec twin) an argument the level does not know
def unknown_arg(c: Surface.Cmd, used: List<&2, String>, +arg: String, similar_name: String, dd: Bool) -> String:
  "error: unexpected argument '" ++ arg ++ "' found\n" ++ arg_tip(arg, similar_name, dd) ++ "\n" ++ usage(c, used) ++ "\n" ++ tail()

# S1.12 (spec twin) an option given twice that may be given once
def repeated(c: Surface.Cmd, o: Surface.Opt) -> String:
  "error: the argument '" ++ shown(o) ++ "' cannot be used multiple times\n\n" ++ usage(c, Nil{}) ++ "\n" ++ tail()

# S1.20 (spec twin) an option left without its value
def missing_value(o: Surface.Opt) -> String:
  "error: a value is required for '" ++ shown(o) ++ "' but none was supplied\n" ++ tail()

# S1.75 (spec twin) a value handed to an option that takes none
def unexpected_value(c: Surface.Cmd, used: List<&2, String>, o: Surface.Opt, v: String) -> String:
  "error: unexpected value '" ++ v ++ "' for '" ++ shown(o) ++ "' found; no more were expected\n\n" ++ usage(c, used) ++ "\n" ++ tail()

# S1.82 (spec twin) the tip under an unrecognized subcommand: nothing, one word, or several
def sub_tip(quoted: List<&2, String>) -> String:
  match quoted:
    case Nil{}:
      ""
    case Con{q, Nil{}}:
      "\n  tip: a similar subcommand exists: " ++ q ++ "\n"
    case Con{q, more}:
      "\n  tip: some similar subcommands exist: " ++ String.join(q <> more, ", ") ++ "\n"

# S1.17 S1.82 (spec twin) a word that is no subcommand of the level
def unknown_sub(c: Surface.Cmd, word: String, cands: List<&2, Cand>) -> String:
  "error: unrecognized subcommand '" ++ word ++ "'\n" ++ sub_tip(quoted_words(cands)) ++ "\n" ++ usage(c, Nil{}) ++ "\n" ++ tail()

# S1.16 S1.83 (spec twin) the program as the message names it: `br`, `br dep`
def bin_name(path: String) -> String:
  match path:
    case SNil{}:
      "br"
    case SCon{h, t}:
      "br " ++ SCon{h, t}

# S1.16 S1.83 (spec twin) a level that must be followed by a subcommand and was not
def sub_required(+c: Surface.Cmd, used: List<&2, String>) -> String:
  "error: '" ++ bin_name(path_of(c)) ++ "' requires a subcommand but one was not provided\n  [subcommands: " ++ String.join(sub_words(subs_of(c)), ", ") ++ "]\n\n" ++ usage(c, used) ++ "\n" ++ tail()

# S1.74 (spec twin) an argument as the exclusion message names it: a positional by its placeholder, an option by its spelling
def id_shown_pick(found: Maybe<&2, Surface.Pos>, o: Maybe<&2, Surface.Opt>, id: String) -> String:
  match found o:
    case Some{p} _:
      pos_shown(p, False{})
    case None{} Some{opt}:
      shown(opt)
    case None{} None{}:
      id

# S1.74 (spec twin) an argument as the exclusion message names it
def id_shown(+c: Surface.Cmd, +id: String) -> String:
  id_shown_pick(pos_named(pos_of(c), id), opt_named(all_opts(c), id), id)

# S1.74 (spec twin) keep a word unless it is the one to drop
def without_put(y: String, drop: Bool, rest: List<&2, String>) -> List<&2, String>:
  match drop:
    case True{}:
      rest
    case False{}:
      y <> rest

# S1.74 (spec twin) drop one word from a list
def without(xs: List<&2, String>, +x: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+y, rest}:
      without_put(y, String.eq(y, x), without(rest, x))

# S1.74 (spec twin) two arguments that exclude each other; the usage names what is present except the second
def clash_text(+c: Surface.Cmd, used: List<&2, String>, x: String, +y: String) -> String:
  "error: the argument '" ++ id_shown(c, x) ++ "' cannot be used with '" ++ id_shown(c, y) ++ "'\n\n" ++ usage(c, without(used, y)) ++ "\n" ++ tail()

# S1.24 (spec twin) the placeholders of the missing positionals, one per line
def missing_lines(names: List<&2, String>) -> List<&2, String>:
  match names:
    case Nil{}:
      Nil{}
    case Con{n, rest}:
      ("  <" ++ n ++ ">\n") <> missing_lines(rest)

# S1.24 (spec twin) required positionals that were not given; the usage names what is present and what is missing
def missing_text(c: Surface.Cmd, used: List<&2, String>, +names: List<&2, String>) -> String:
  "error: the following required arguments were not provided:\n" ++ String.concat(missing_lines(names)) ++ "\n" ++ usage(c, List.append(&2, String, used, names)) ++ "\n" ++ tail()

# ---------------------------------------------------------------- the state

# S1.1 (spec twin) the level being parsed
def cmd_of(st: St) -> Surface.Cmd:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      cmd

# S1.12 (spec twin) the occurrences at this level (REVERSED)
def seen_of(st: St) -> List<&2, Occ>:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      seen

# S1.70 (spec twin) the arguments present at this level, in first-seen order
def used_of(st: St) -> List<&2, String>:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      List.reverse(&2, String, used)

# S1.24 (spec twin) how many positionals this level has taken
def word_count(st: St) -> Nat:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      List.length(&2, String, words)

# S1.20 (spec twin) the option waiting for its value
def pending_of(st: St) -> Pending:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      pending

# S1.84 (spec twin) the refusal held back until the next argument
def held_of(st: St) -> String:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      held

# S1.14 (spec twin) was `--` seen
def trailing_of(st: St) -> Bool:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      trailing

# S1.25 (spec twin) has this level seen no argument
def fresh_of(st: St) -> Bool:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      fresh

# S1.69 (spec twin) was the rest of the short cluster taken as a value
def skip_of(st: St) -> Bool:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      skip

# S1.30 (spec twin) the sticky stop
def halt_of(st: St) -> Halt:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      halt

# S1.30 (spec twin) is the parse still running
def is_going(st: St) -> Bool:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Going{}}:
      True{}
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Halted{p}}:
      False{}
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Helping{}}:
      False{}

# S1.30 (spec twin) stop with this answer; the first stop wins
def halted(st: St, p: Parsed) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Going{}}:
      St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Halted{p}}
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Halted{first}}:
      St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Halted{first}}
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Helping{}}:
      St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Helping{}}

# S1.89 (spec twin) the `help` subcommand was read at this level: from here on only level words are followed
def helping(st: St) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, Helping{}}

# S1.89 (spec twin) `help dep add`: go down a level, still helping
def help_into(st: St, target: U32) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{Surface.cmd_at(target), outer, seen, used, words, pending, held, trailing, fresh, skip, Helping{}}

# S1.89 (spec twin) only a word of the port's surface is followed
def help_down(st: St, target: U32, scope: U32) -> St:
  match scope:
    case 0:
      help_into(st, target)
    case _:
      st

# S1.89 (spec twin) a word after `help`: a subcommand word of the level is followed, anything else is passed over
def help_word(st: St, found: Maybe<&2, Surface.Name>) -> St:
  match found:
    case None{}:
      st
    case Some{Surface.Name{w, target, scope}}:
      help_down(st, target, scope)

# S1.84 (spec twin) hold a refusal until the next argument settles it; nothing waits any more
def hold(st: St, err: String) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{cmd, outer, seen, used, words, Idle{}, err, trailing, fresh, skip, halt}

# S1.20 (spec twin) an option now waits for its value
def await(st: St, o: Surface.Opt) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{cmd, outer, seen, used, words, Awaits{o}, held, trailing, fresh, skip, halt}

# S1.70 (spec twin) remember an argument as present, once, in first-seen order (REVERSED)
def add_used_pick(used: List<&2, String>, id: String, known: Bool) -> List<&2, String>:
  match known:
    case True{}:
      used
    case False{}:
      id <> used

# S1.70 (spec twin) remember an argument as present
def add_used(+used: List<&2, String>, +id: String) -> List<&2, String>:
  add_used_pick(used, id, has(used, id))

# S1.13 (spec twin) record one occurrence; nothing waits any more
def record(st: St, +key: String, value: String) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{cmd, outer, Occ{key, value} <> seen, add_used(used, key), words, Idle{}, held, trailing, fresh, skip, halt}

# S1.24 (spec twin) take one positional; `name` is its placeholder
def push_word(st: St, word: String, name: String) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{cmd, outer, seen, add_used(used, name), word <> words, pending, held, trailing, fresh, skip, halt}

# S1.14 (spec twin) `--` was seen: every later word is a positional
def set_trailing(st: St) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{cmd, outer, seen, used, words, pending, held, True{}, fresh, skip, halt}

# S1.25 (spec twin) this level has now seen an argument
def unfresh(st: St) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{cmd, outer, seen, used, words, pending, held, trailing, False{}, skip, halt}

# S1.69 (spec twin) the rest of the short cluster was (or was not) taken as a value
def set_skip(st: St, to: Bool) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{cmd, outer, seen, used, words, pending, held, trailing, fresh, to, halt}

# S1.3 S1.85 (spec twin) go down one level: this level's occurrences join the outer ones, everything else starts over
def descend(st: St, target: U32) -> St:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      St{Surface.cmd_at(target), List.append(&2, Occ, seen, outer), Nil{}, Nil{}, Nil{}, Idle{}, "", False{}, True{}, False{}, Going{}}

# S1.1 S1.15 (spec twin) the top level before any argument. The contract is `br --no-db <argv>`: `--no-db`
# is already present, which the usage line echoes (S1.15). It is NOT counted as an occurrence, so typing
# `--no-db` oneself is accepted (DISC-007).
def start() -> St:
  St{Surface.cmd_at(0), Nil{}, Nil{}, "no-db" <> Nil{}, Nil{}, Idle{}, "", False{}, True{}, False{}, Going{}}

# ---------------------------------------------------------------- settling (S1.20, S1.84)

# S1.49 (spec twin) a waiting option that may stand alone is present without a value; any other is refused
def settle_awaiting(st: St, +o: Surface.Opt, optional: Bool) -> St:
  match optional:
    case True{}:
      record(st, key_of(o), "")
    case False{}:
      halted(st, Refused{missing_value(o)})

# S1.20 (spec twin) nothing may wait across a known argument
def settle_pending(st: St, p: Pending) -> St:
  match p:
    case Idle{}:
      st
    case Awaits{+o}:
      settle_awaiting(st, o, is_optional(o))

# S1.84 (spec twin) a held refusal fires now
def settle_held(+st: St, held: String) -> St:
  match held:
    case SNil{}:
      settle_pending(st, pending_of(st))
    case SCon{h, t}:
      halted(st, Refused{SCon{h, t}})

# S1.20 S1.84 (spec twin) before a KNOWN argument, a positional, a subcommand or the end: a held refusal
# fires, and an option still waiting for its value is refused. An UNKNOWN argument never settles: its own
# refusal wins (goldens usage_value_pending_then_unknown, usage_value_negative).
def settle(+st: St) -> St:
  settle_held(st, held_of(st))

# ---------------------------------------------------------------- options

# S1.12 S1.21 (spec twin) a value's refusal: the option was already given and may not repeat, or the parser rejects the value
def value_error_pick(c: Surface.Cmd, +o: Surface.Opt, v: String, again: Bool) -> String:
  match again:
    case True{}:
      repeated(c, o)
    case False{}:
      check_error(o, v)

# S1.12 S1.21 (spec twin) a value's refusal, "" when it is accepted
def value_error(+st: St, +o: Surface.Opt, v: String) -> String:
  value_error_pick(cmd_of(st), o, v, (Bool.not(repeats(o)) && occurred(seen_of(st), key_of(o))))

# S1.84 (spec twin) an accepted value is recorded; a refusal fires now when the value was attached
# (`--limit=x`, `-px`), and is held when the value was the next word
def take_value_pick(st: St, o: Surface.Opt, v: String, err: String, now: Bool) -> St:
  match err now:
    case SNil{} _:
      record(st, key_of(o), v)
    case SCon{h, t} True{}:
      halted(st, Refused{SCon{h, t}})
    case SCon{h, t} False{}:
      hold(st, SCon{h, t})

# S1.10 S1.84 (spec twin) give an option its value
def take_value(+st: St, +o: Surface.Opt, +v: String, now: Bool) -> St:
  take_value_pick(st, o, v, value_error(st, o, v), now)

# S1.12 S1.29 (spec twin) an option without a value: help and version stop the parse; a second
# occurrence of a once-only option is refused; anything else is recorded
def take_flag_pick(+st: St, +o: Surface.Opt, long: Bool, help: Bool, version: Bool, again: Bool) -> St:
  match help version again:
    case True{} _ _:
      halted(st, Helped{path_of(cmd_of(st)), long})
    case False{} True{} _:
      halted(st, Versioned{})
    case False{} False{} True{}:
      halted(st, Refused{repeated(cmd_of(st), o)})
    case False{} False{} False{}:
      record(st, key_of(o), "")

# S1.12 S1.29 (spec twin) an option without a value; `long` says whether it was spelled `--name`
def take_flag(+st: St, +o: Surface.Opt, long: Bool) -> St:
  take_flag_pick(st, o, long, String.eq(key_of(o), "help"), String.eq(key_of(o), "version"), (Bool.not(repeats(o)) && occurred(seen_of(st), key_of(o))))

# S1.81 (spec twin) the option's own name, given a name or alias that spells it; "" when nothing is spelled
def canon_key(found: Maybe<&2, Surface.Opt>) -> String:
  match found:
    case None{}:
      ""
    case Some{o}:
      key_of(o)

# S1.81 (spec twin) name the suggested option on the usage line, after what is present; "" names nothing
def add_last_pick(used: List<&2, String>, id: String, skip: Bool) -> List<&2, String>:
  match skip:
    case True{}:
      used
    case False{}:
      List.append(&2, String, used, id <> Nil{})

# S1.81 (spec twin) name the suggested option on the usage line
def add_last(+used: List<&2, String>, +id: String) -> List<&2, String>:
  add_last_pick(used, id, (String.is_empty(id) || has(used, id)))

# S1.15 S1.19 S1.81 (spec twin) an unknown long option, given the most similar long name of the level ("" = none).
# The `--` advice needs a level with positionals
def unknown_long_text(+c: Surface.Cmd, used: List<&2, String>, name: String, +best_name: String) -> String:
  unknown_arg(c, add_last(used, canon_key(opt_named(all_opts(c), best_name))), "--" ++ name, best_name, Bool.not(List.is_empty(&2, Surface.Pos, pos_of(c))))

# S1.15 S1.19 S1.81 (spec twin) an unknown long option
def unknown_long(+st: St, +name: String) -> String:
  unknown_long_text(cmd_of(st), used_of(st), name, best(similar(codes(name), long_names(all_opts(cmd_of(st)))), ""))

# S1.68 (spec twin) an unknown short option: no similarity tip, and the usage line names nothing
def unknown_short(+c: Surface.Cmd, letter: U32) -> String:
  unknown_arg(c, Nil{}, SCon{Chr{45}, SCon{Chr{letter}, SNil{}}}, "", Bool.not(List.is_empty(&2, Surface.Pos, pos_of(c))))

# S1.10 S1.12 S1.20 S1.75 (spec twin) a known long option, after settling
def long_known(+st: St, +o: Surface.Opt, v: String, going: Bool, takes: Bool, attached: Bool) -> St:
  match going takes attached:
    case False{} _ _:
      st
    case True{} True{} True{}:
      take_value(st, o, v, True{})
    case True{} True{} False{}:
      await(st, o)
    case True{} False{} True{}:
      halted(st, Refused{unexpected_value(cmd_of(st), add_last(used_of(st), key_of(o)), o, v)})
    case True{} False{} False{}:
      take_flag(st, o, True{})

# S1.10 S1.20 (spec twin) a known long option once whatever waited has been settled
def long_settled(+st: St, +o: Surface.Opt, v: String, attached: Bool) -> St:
  long_known(st, o, v, is_going(st), takes_value(o), attached)

# S1.11 S1.15 (spec twin) route on whether the level knows the long name
def long_found(+st: St, name: String, attached: Bool, v: String, found: Maybe<&2, Surface.Opt>) -> St:
  match found:
    case None{}:
      halted(st, Refused{unknown_long(st, name)})
    case Some{+o}:
      long_settled(settle(st), o, v, attached)

# S1.10 S1.11 (spec twin) `--name` or `--name=value`
def on_long(+st: St, +name: String, attached: Bool, v: String) -> St:
  long_found(st, name, attached, v, opt_named(all_opts(cmd_of(st)), name))

# S1.69 (spec twin) an attached short value may be written `-p=1`: one leading `=` is not part of it
def strip_eq(cs: List<&2, U32>) -> List<&2, U32>:
  match cs:
    case Con{61, rest}:
      rest
    case other:
      other

# S1.69 (spec twin) a known short option: a flag lets the cluster go on; an option with a value takes the
# rest of the cluster as that value (`-p1`), or waits for the next word when the cluster ends there (`-rs open`)
def short_known(+st: St, +o: Surface.Opt, rest: List<&2, U32>, going: Bool, takes: Bool, last: Bool) -> St:
  match going takes last:
    case False{} _ _:
      st
    case True{} False{} _:
      take_flag(st, o, False{})
    case True{} True{} True{}:
      await(st, o)
    case True{} True{} False{}:
      set_skip(take_value(st, o, text(strip_eq(rest)), True{}), True{})

# S1.69 (spec twin) a known short option once whatever waited has been settled
def short_settled(+st: St, +o: Surface.Opt, +rest: List<&2, U32>) -> St:
  short_known(st, o, rest, is_going(st), takes_value(o), List.is_empty(&2, U32, rest))

# S1.68 S1.69 (spec twin) route on whether the level knows the short letter
def short_found(+st: St, letter: U32, rest: List<&2, U32>, found: Maybe<&2, Surface.Opt>) -> St:
  match found:
    case None{}:
      halted(st, Refused{unknown_short(cmd_of(st), letter)})
    case Some{o}:
      short_settled(settle(st), o, rest)

# S1.69 (spec twin) one letter of a cluster; a stopped parse, or a cluster whose rest was a value, passes through
def short_step(+st: St, +letter: U32, rest: List<&2, U32>, live: Bool) -> St:
  match live:
    case False{}:
      st
    case True{}:
      short_found(st, letter, rest, opt_short(all_opts(cmd_of(st)), letter))

# S1.69 (spec twin) a cluster of short options, letter by letter
def cluster_go(cs: List<&2, U32>, +st: St) -> St:
  match cs:
    case Nil{}:
      set_skip(st, False{})
    case Con{letter, +rest}:
      cluster_go(rest, short_step(st, letter, rest, (is_going(st) && Bool.not(skip_of(st)))))

# ---------------------------------------------------------------- words

# S1.24 (spec twin) the positional a word at this index fills: the one at the index, or the last when it repeats
def slot_at(ps: List<&2, Surface.Pos>, index: Nat) -> Maybe<&2, Surface.Pos>:
  match ps index:
    case Nil{} _:
      None{}
    case Con{p, rest} 0n:
      Some{p}
    case Con{Surface.Pos{name, required, True{}}, Nil{}} 1n+k:
      Some{Surface.Pos{name, required, True{}}}
    case Con{p, rest} 1n+k:
      slot_at(rest, k)

# S1.24 (spec twin) take the word unless settling stopped the parse
def positional_take(st: St, word: String, name: String, going: Bool) -> St:
  match going:
    case False{}:
      st
    case True{}:
      push_word(st, word, name)

# S1.24 (spec twin) a positional once whatever waited has been settled
def positional_settled(+st: St, word: String, name: String) -> St:
  positional_take(st, word, name, is_going(st))

# S1.24 S1.73 (spec twin) a word as a positional: taken when the level has room for it, refused otherwise.
# The refusal settles nothing and names nothing on its usage line
def positional_pick(+st: St, +word: String, slot: Maybe<&2, Surface.Pos>) -> St:
  match slot:
    case None{}:
      halted(st, Refused{unknown_arg(cmd_of(st), Nil{}, word, "", False{})})
    case Some{Surface.Pos{name, required, many}}:
      positional_settled(settle(st), word, name)

# S1.24 (spec twin) a word as a positional
def on_positional(+st: St, word: String) -> St:
  positional_pick(st, word, slot_at(pos_of(cmd_of(st)), word_count(st)))

# S1.16 S1.85 (spec twin) a subcommand word: go down a level, stop at a command outside the port's
# surface, or answer `help`
def enter_scope(+st: St, target: U32, scope: U32, word: String) -> St:
  match scope:
    case 0:
      descend(st, target)
    case 1:
      halted(st, Outside{word})
    case _:
      helping(st)

# S1.16 (spec twin) a subcommand word, after settling
def enter_live(+st: St, going: Bool, n: Surface.Name, word: String) -> St:
  match going n:
    case False{} _:
      st
    case True{} Surface.Name{w, target, scope}:
      enter_scope(st, target, scope, word)

# S1.17 S1.82 S1.86 (spec twin) a word that is no subcommand: at a level that takes positionals it is a
# positional, however similar to a subcommand it is (`comments lis` looks for the issue `lis`); anywhere
# else it is refused, with a tip when a subcommand is similar
def not_sub(+st: St, +word: String, cands: List<&2, Cand>, has_subs: Bool, has_pos: Bool) -> St:
  match has_subs has_pos:
    case False{} _:
      on_positional(st, word)
    case True{} True{}:
      on_positional(st, word)
    case True{} False{}:
      halted(st, Refused{unknown_sub(cmd_of(st), word, cands)})

# S1.16 S1.17 (spec twin) route a plain word: after `--` it is a positional; a subcommand word goes down a level
def word_pick(+st: St, +word: String, trailing: Bool, found: Maybe<&2, Surface.Name>) -> St:
  match trailing found:
    case True{} _:
      on_positional(st, word)
    case False{} Some{+n}:
      enter_live(settle(st), is_going(settle(st)), n, word)
    case False{} None{}:
      not_sub(st, word, similar(codes(word), sub_words(subs_of(cmd_of(st)))), Bool.not(List.is_empty(&2, Surface.Name, subs_of(cmd_of(st)))), Bool.not(List.is_empty(&2, Surface.Pos, pos_of(cmd_of(st)))))

# S1.16 S1.24 (spec twin) a plain word
def on_word(+st: St, +word: String) -> St:
  word_pick(st, word, trailing_of(st), sub_named(subs_of(cmd_of(st)), word))

# ---------------------------------------------------------------- one argument

# S1.10 S1.14 S1.69 (data) what an argument looks like: exactly `--`; `--name` or `--name=value`;
# `-` followed by at least one letter; anything else, including `-` alone and the empty string
type Shape is Data:
  Escape{}
  Long{name: String, attached: Bool, value: String}
  Short{cluster: List<&2, U32>}
  Word{}

# S1.10 (spec twin) a long option's name ends at the first `=`; what follows is its attached value
def long_split(s: String, acc: List<&2, U32>) -> Shape:
  match s:
    case SNil{}:
      Long{text_rev(acc, ""), False{}, ""}
    case SCon{Chr{61}, rest}:
      Long{text_rev(acc, ""), True{}, rest}
    case SCon{Chr{c}, rest}:
      long_split(rest, c <> acc)

# S1.10 S1.14 S1.69 (spec twin) what an argument looks like
def shape_of(s: String) -> Shape:
  match s:
    case SCon{Chr{45}, SCon{Chr{45}, SNil{}}}:
      Escape{}
    case SCon{Chr{45}, SCon{Chr{45}, rest}}:
      long_split(rest, Nil{})
    case SCon{Chr{45}, SNil{}}:
      Word{}
    case SCon{Chr{45}, rest}:
      Short{codes(rest)}
    case other:
      Word{}

# S1.14 (spec twin) `--`: whatever waited is settled, and every later argument is a positional
def on_escape(+st: St) -> St:
  set_trailing(settle(st))

# S1.14 (spec twin) route on the argument's shape; after `--` every argument is a positional
def step_shape(+st: St, +arg: String, sh: Shape, trailing: Bool) -> St:
  match sh trailing:
    case _ True{}:
      on_positional(st, arg)
    case Escape{} False{}:
      on_escape(st)
    case Long{name, attached, value} False{}:
      on_long(st, name, attached, value)
    case Short{cluster} False{}:
      cluster_go(cluster, st)
    case Word{} False{}:
      on_word(st, arg)

# S1.36 S1.87 (spec twin) an option waits for its value and the argument looks like an option: it IS the
# value when the waiting option accepts a leading `-`; otherwise it is read as an option
def step_dashed(+st: St, +arg: String, +o: Surface.Opt, sh: Shape, hyphen: Bool) -> St:
  match hyphen:
    case True{}:
      take_value(st, o, arg, False{})
    case False{}:
      step_shape(st, arg, sh, trailing_of(st))

# S1.20 S1.87 (spec twin) route on what waits: a plain word is the waiting option's value
def step_pending(+st: St, +arg: String, p: Pending, sh: Shape) -> St:
  match p sh:
    case Idle{} shape:
      step_shape(st, arg, shape, trailing_of(st))
    case Awaits{o} Word{}:
      take_value(st, o, arg, False{})
    case Awaits{+o} shape:
      step_dashed(st, arg, o, shape, accepts_hyphen(o))

# S1.30 S1.89 (spec twin) a stopped parse passes every later argument through, except that the `help`
# subcommand follows the words that name a level
def step_stopped(+st: St, arg: String, h: Halt) -> St:
  match h:
    case Helping{}:
      help_word(st, sub_named(subs_of(cmd_of(st)), arg))
    case other:
      st

# S1.30 (spec twin) route on whether the parse is still running
def step_live(+st: St, +arg: String, going: Bool) -> St:
  match going:
    case False{}:
      step_stopped(st, arg, halt_of(st))
    case True{}:
      step_pending(unfresh(st), arg, pending_of(st), shape_of(arg))

# S1.1 (spec twin) one argument
def step(+st: St, arg: String) -> St:
  step_live(st, arg, is_going(st))

# S1.1 (spec twin) the loop over argv
def walk(args: List<&2, String>, st: St) -> St:
  match args:
    case Nil{}:
      st
    case Con{arg, rest}:
      walk(rest, step(st, arg))

# ---------------------------------------------------------------- the verdict (S1.24, S1.25, S1.74, S1.83)

# S1.74 (spec twin) the first exclusion that names `x` and a partner that is present; "" when there is none
def partner_pick(ab: Bool, ba: Bool, a: String, b: String, later: String) -> String:
  match ab ba:
    case True{} _:
      b
    case False{} True{}:
      a
    case False{} False{}:
      later

# S1.74 (spec twin) the present argument that excludes `x`
def partner(clashes: List<&2, Surface.Clash>, +x: String, +used: List<&2, String>) -> String:
  match clashes:
    case Nil{}:
      ""
    case Con{Surface.Clash{+a, +b}, rest}:
      partner_pick((String.eq(a, x) && has(used, b)), (String.eq(b, x) && has(used, a)), a, b, partner(rest, x, used))

# S1.74 (spec twin) keep the first pair
def clash_pick(x: String, y: String, later: Maybe<&2, Surface.Clash>) -> Maybe<&2, Surface.Clash>:
  match y:
    case SNil{}:
      later
    case SCon{h, t}:
      Some{Surface.Clash{x, SCon{h, t}}}

# S1.74 (spec twin) the first present argument, in first-seen order, that a present partner excludes
def clash_in(order: List<&2, String>, +used: List<&2, String>, +clashes: List<&2, Surface.Clash>) -> Maybe<&2, Surface.Clash>:
  match order:
    case Nil{}:
      None{}
    case Con{+x, rest}:
      clash_pick(x, partner(clashes, x, used), clash_in(rest, used, clashes))

# S1.24 (spec twin) keep a required placeholder
def missing_keep(name: String, required: Bool, rest: List<&2, String>) -> List<&2, String>:
  match required:
    case True{}:
      name <> rest
    case False{}:
      rest

# S1.24 (spec twin) the required positionals beyond the ones given, in declaration order
def missing_go(ps: List<&2, Surface.Pos>, have: Nat) -> List<&2, String>:
  match ps have:
    case Nil{} _:
      Nil{}
    case Con{Surface.Pos{name, required, many}, rest} 0n:
      missing_keep(name, required, missing_go(rest, 0n))
    case Con{p, rest} 1n+k:
      missing_go(rest, k)

# S1.1 (spec twin) the command to run: every occurrence in argv order (outer levels first), the positionals in order
def command_of(st: St) -> Parsed:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      Command{path_of(cmd), List.reverse(&2, Occ, List.append(&2, Occ, seen, outer)), List.reverse(&2, String, words)}

# S1.16 S1.25 S1.83 (spec twin) a level that needs a subcommand and got none: a bare group prints its
# long help; the top level, or a group that was given options only, is refused
def verdict_sub(+st: St, need: Bool, bare_group: Bool) -> Parsed:
  match need bare_group:
    case False{} _:
      command_of(st)
    case True{} True{}:
      GroupHelp{path_of(cmd_of(st))}
    case True{} False{}:
      Refused{sub_required(cmd_of(st), Nil{})}

# S1.24 (spec twin) required positionals that were not given
def verdict_missing(+st: St, +names: List<&2, String>, none: Bool) -> Parsed:
  match none:
    case True{}:
      verdict_sub(st, needs_sub(cmd_of(st)), (fresh_of(st) && Bool.not(String.is_empty(path_of(cmd_of(st))))))
    case False{}:
      Refused{missing_text(cmd_of(st), used_of(st), names)}

# S1.74 (spec twin) exclusions are judged before missing positionals
def verdict_clash(+st: St, found: Maybe<&2, Surface.Clash>) -> Parsed:
  match found:
    case Some{Surface.Clash{x, y}}:
      Refused{clash_text(cmd_of(st), used_of(st), x, y)}
    case None{}:
      verdict_missing(st, missing_go(pos_of(cmd_of(st)), word_count(st)), List.is_empty(&2, String, missing_go(pos_of(cmd_of(st)), word_count(st))))

# S1.30 (spec twin) a stopped parse answers what stopped it
def verdict_halt(+st: St, h: Halt) -> Parsed:
  match h:
    case Halted{p}:
      p
    case Helping{}:
      Helped{path_of(cmd_of(st)), True{}}
    case Going{}:
      verdict_clash(st, clash_in(used_of(st), used_of(st), clashes_of(cmd_of(st))))

# S1.20 S1.24 S1.74 (spec twin) the end of argv: whatever waits is settled, then exclusions, then
# missing positionals, then the missing subcommand
def verdict(+st: St) -> Parsed:
  verdict_halt(st, halt_of(st))

# S1.1–S1.30 (spec twin) argv to a command, or the argument parser's answer
def parse(argv: List<&2, String>) -> Parsed:
  verdict(settle(walk(argv, start())))

# S1.2 (data) one argument as the shell read it: its text (an invalid UTF-8 sequence already replaced by U+FFFD, as
# the original prints it) and whether its bytes were valid UTF-8 (OQ-012)
type Arg is Data:
  Arg{text: String, ok: Bool}

# S1.2 (spec twin) the occurrences that carry a value, counted onto acc
def valued(occs: List<&2, Occ>, +acc: Nat) -> Nat:
  match occs:
    case Nil{}:
      acc
    case Con{Occ{k, v}, rest}:
      valued(rest, Bool.pick(Nat, String.is_empty(v), acc, Nat.add(acc, 1n)))

# S1.2 (spec twin) how much of argv the level has taken as values: recorded values, positional words, a held refusal
def consumed(st: St) -> Nat:
  match st:
    case St{cmd, outer, seen, used, words, pending, held, trailing, fresh, skip, halt}:
      Nat.add(Nat.add(valued(seen, 0n), List.length(&2, String, words)), Bool.pick(Nat, String.is_empty(held), 0n, 1n))

# S1.2 (spec twin) the refusal of a value that is not valid UTF-8: the level's bare usage line
def utf8_text(c: Surface.Cmd) -> String:
  "error: invalid UTF-8 was detected in one or more arguments\n\n" ++ usage(c, Nil{}) ++ "\n" ++ tail()

# S1.2 (spec twin) after an invalid argument's step: when the step took it as a value (a value recorded or refused,
# a positional word), the parse stops with the UTF-8 refusal at that level; taken as a name (an option, a
# subcommand), its U+FFFD text stands in the ordinary refusals (`unrecognized subcommand '�'`)
def utf8_check(ok: Bool, +before: Nat, +st: St) -> St:
  match ok:
    case True{}:
      st
    case False{}:
      Bool.pick(St, Nat.is_gt(consumed(st), before), halted(st, Refused{utf8_text(cmd_of(st))}), st)

# S1.2 (spec twin) an invalid argument of the form `--name=value` is refused before its value is judged
def attached_value(sh: Shape) -> Bool:
  match sh:
    case Long{name, attached, value}:
      attached
    case other:
      False{}

# S1.2 (spec twin) one argument: an invalid attached value stops the parse at once; otherwise the ordinary step
def step_pre(bad: Bool, +st: St, arg: String) -> St:
  match bad:
    case True{}:
      halted(st, Refused{utf8_text(cmd_of(st))})
    case False{}:
      step(st, arg)

# S1.2 (spec twin) one argument with its validity
def step_arg(+st: St, +arg: String, +ok: Bool) -> St:
  utf8_check(ok, consumed(st), step_pre((Bool.not(ok) && is_going(st) && attached_value(shape_of(arg))), st, arg))

# S1.2 (spec twin) the loop over argv with each argument's validity
def walk_args(args: List<&2, Arg>, st: St) -> St:
  match args:
    case Nil{}:
      st
    case Con{Arg{arg, ok}, rest}:
      walk_args(rest, step_arg(st, arg, ok))

# S1.2 (spec twin) argv with a validity flag per argument (`1` valid, `0` not, in order; a missing flag reads valid)
def flagged(argv: List<&2, String>, flags: String) -> List<&2, Arg>:
  match argv flags:
    case Nil{} _:
      Nil{}
    case Con{a, rest} SCon{Chr{+c}, more}:
      Arg{a, Bool.not(U32.is_eq(c, 48))} <> flagged(rest, more)
    case Con{a, rest} SNil{}:
      Arg{a, True{}} <> flagged(rest, "")

# S1.1–S1.30 S1.2 (spec twin) `parse` with each argument's validity (OQ-012)
def parse_flagged(args: List<&2, Arg>) -> Parsed:
  verdict(settle(walk_args(args, start())))

# ---------------------------------------------------------------- reading the occurrences

# S1.6 (spec twin) was this option given, at any level
def given(opts: List<&2, Occ>, +key: String) -> Bool:
  match opts:
    case Nil{}:
      False{}
    case Con{Occ{k, v}, rest}:
      (String.eq(k, key) || given(rest, key))

# S1.13 (spec twin) keep a value when its key is the one asked for
def values_put(v: String, hit: Bool, rest: List<&2, String>) -> List<&2, String>:
  match hit:
    case True{}:
      v <> rest
    case False{}:
      rest

# S1.13 (spec twin) every value an option was given, in argv order
def values(opts: List<&2, Occ>, +key: String) -> List<&2, String>:
  match opts:
    case Nil{}:
      Nil{}
    case Con{Occ{k, v}, rest}:
      values_put(v, String.eq(k, key), values(rest, key))

# S1.85 (spec twin) the value of a once-only option: the LAST one given, so a command-level value beats a top-level one
def value(opts: List<&2, Occ>, key: String) -> Maybe<&2, String>:
  List.last(&2, String, values(opts, key))


