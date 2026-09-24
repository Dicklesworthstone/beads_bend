# core/time — instants: RFC 3339 parsing, UTC normalization, ordering and
# printing (S4.54, S4.55, S4.57; S3.11). An instant is a day count and a
# second of the day in U32, never epoch nanoseconds (about 1.8e18, past Nat's
# 2^48) and never a large Nat (a law over a Peano numeral of 700 000 would not
# check): docs/NUMERIC_PLAN.md S7.14. Days count from 0000-03-01 (proleptic
# Gregorian), which keeps every intermediate non-negative.
# Nothing here consults the original: docs/EXISTING_BEADS_RUST_STRUCTURE.md.
import Base

# S3.11 (data) an instant in UTC: days since 0000-03-01, second of the day, nanoseconds
type Instant is Data:
  Instant{days: U32, sod: U32, nanos: U32}

# S4.57 (data) the verdict of a parse: a malformed spelling is a verdict, never a default
type Parsed is Data:
  Bad{}
  Good{at: Instant}

# S4.57 (data) a calendar date, validated
type Civil is Data:
  Civil{year: U32, month: U32, day: U32}

# S4.57 (data) the digits of a fraction: value, remaining width (from 9), all-digits verdict
type Frac is Data:
  Frac{value: U32, ok: Bool}

# S4.57 (spec twin) is this code point an ASCII digit
def is_dig(+c: U32) -> Bool:
  ((c >= 48 : U32) && (c <= 57 : U32))

# S4.57 (spec twin) the value of two digit code points
def two(a: U32, b: U32) -> U32:
  (((a - 48 : U32) * 10 : U32) + (b - 48 : U32) : U32)

# S4.57 (spec twin) a year is a leap year in the proleptic Gregorian calendar
def is_leap(+y: U32) -> Bool:
  ((U32.is_eq((y % 4 : U32), 0) && U32.is_ne((y % 100 : U32), 0)) || U32.is_eq((y % 400 : U32), 0))

# S4.57 (spec twin) days in February
def feb(leap: Bool) -> U32:
  match leap:
    case True{}:
      29
    case False{}:
      28

# S4.57 (spec twin) 30-day months are 4, 6, 9, 11
def thirty(+m: U32) -> Bool:
  (U32.is_eq(m, 4) || U32.is_eq(m, 6) || U32.is_eq(m, 9) || U32.is_eq(m, 11))

# S4.57 (spec twin) pick the month length from two verdicts
def dim_pick(is_feb: Bool, is_thirty: Bool, feb_len: U32) -> U32:
  match is_feb is_thirty:
    case True{} _:
      feb_len
    case False{} True{}:
      30
    case False{} False{}:
      31

# S4.57 (spec twin) days in a month
def dim(+y: U32, +m: U32) -> U32:
  dim_pick(U32.is_eq(m, 2), thirty(m), feb(is_leap(y)))

# S4.55 (spec twin) days since 0000-03-01 of a valid date, year >= 1 (Hinnant's
# days_from_civil with its era shift folded in: every term is non-negative)
def to_days_shifted(+yy: U32, +mp: U32, d: U32) -> U32:
  +era = (yy / 400 : U32)
  +yoe = (yy - (era * 400 : U32) : U32)
  doy = ((((153 * mp : U32) + 2 : U32) / 5 : U32) + (d - 1 : U32) : U32)
  doe = ((((yoe * 365 : U32) + (yoe / 4 : U32) : U32) - (yoe / 100 : U32) : U32) + doy : U32)
  ((era * 146097 : U32) + doe : U32)

# S4.55 (spec twin) January and February belong to the previous March-based year
def to_days_pick(+y: U32, +m: U32, d: U32, early: Bool) -> U32:
  match early:
    case True{}:
      to_days_shifted((y - 1 : U32), (m + 9 : U32), d)
    case False{}:
      to_days_shifted(y, (m - 3 : U32), d)

# S4.55 (spec twin) days since 0000-03-01 of a calendar date
def to_days(c: Civil) -> U32:
  match c:
    case Civil{y, +m, d}:
      to_days_pick(y, m, d, (m <= 2 : U32))

# S4.54 (spec twin) the month number and the year carry from a March-based month index
def civil_pick(y: U32, +mp: U32, d: U32, late: Bool) -> Civil:
  match late:
    case True{}:
      Civil{(y + 1 : U32), (mp - 9 : U32), d}
    case False{}:
      Civil{y, (mp + 3 : U32), d}

# S4.54 (spec twin) the calendar date of a day count (Hinnant's civil_from_days)
def civil(+z: U32) -> Civil:
  +era = (z / 146097 : U32)
  +doe = (z - (era * 146097 : U32) : U32)
  +yoe = (((((doe - (doe / 1460 : U32) : U32) + (doe / 36524 : U32) : U32) - (doe / 146096 : U32) : U32)) / 365 : U32)
  +doy = (doe - ((((365 * yoe : U32) + (yoe / 4 : U32) : U32) - (yoe / 100 : U32) : U32)) : U32)
  +mp = ((((5 * doy : U32) + 2 : U32)) / 153 : U32)
  d = ((doy - ((((153 * mp : U32) + 2 : U32)) / 5 : U32) : U32) + 1 : U32)
  civil_pick((yoe + (era * 400 : U32) : U32), mp, d, (mp >= 10 : U32))

# S4.54 (spec twin) the last k decimal digits of n, most significant first, zero padded
def digits(k: Nat, +n: U32, acc: String) -> String:
  match k:
    case 0n:
      acc
    case 1n+p:
      digits(p, (n / 10 : U32), SCon{Char.from_u32(((n % 10 : U32) + 48 : U32)), acc})

# S4.54 (spec twin) the fraction: 0, 3, 6 or 9 digits, the smallest width that loses nothing
def frac_pick(+n: U32, none: Bool, milli: Bool, micro: Bool) -> String:
  match none milli micro:
    case True{} _ _:
      ""
    case False{} True{} _:
      "." ++ digits(3n, (n / 1000000 : U32), "")
    case False{} False{} True{}:
      "." ++ digits(6n, (n / 1000 : U32), "")
    case False{} False{} False{}:
      "." ++ digits(9n, n, "")

# S4.54 (spec twin) the fraction text of a nanosecond count
def frac_text(+n: U32) -> String:
  frac_pick(n, U32.is_eq(n, 0), U32.is_eq((n % 1000000 : U32), 0), U32.is_eq((n % 1000 : U32), 0))

# S4.54 (spec twin) YYYY-MM-DD
def date_text(c: Civil) -> String:
  match c:
    case Civil{y, m, d}:
      digits(4n, y, "") ++ "-" ++ digits(2n, m, "") ++ "-" ++ digits(2n, d, "")

# S4.54 S4.64 (spec twin) RFC 3339 in UTC; the suffix is `Z` for the store and
# every record, `+00:00` for the two payloads S4.64 names
def print(t: Instant, suffix: String) -> String:
  match t:
    case Instant{z, +s, n}:
      date_text(civil(z)) ++ "T" ++ digits(2n, (s / 3600 : U32), "") ++ ":" ++ digits(2n, ((s / 60 : U32) % 60 : U32), "") ++ ":" ++ digits(2n, (s % 60 : U32), "") ++ frac_text(n) ++ suffix

# S6.8 S6.12 (spec twin) a <= b as instants: chronological, never textual (OQ-001)
def le(a: Instant, b: Instant) -> Bool:
  match a b:
    case Instant{+d1, +s1, n1} Instant{+d2, +s2, n2}:
      ((d1 < d2 : U32) || (U32.is_eq(d1, d2) && ((s1 < s2 : U32) || (U32.is_eq(s1, s2) && (n1 <= n2 : U32)))))

# S6.8 (spec twin) a == b as instants
def eq(a: Instant, b: Instant) -> Bool:
  match a b:
    case Instant{d1, s1, n1} Instant{d2, s2, n2}:
      (U32.is_eq(d1, d2) && U32.is_eq(s1, s2) && U32.is_eq(n1, n2))

# S4.55 (spec twin) move an instant EARLIER by secs < 86400 * 2, borrowing days when needed
def earlier_pick(+z: U32, +s: U32, n: U32, +secs: U32, fits: Bool) -> Instant:
  match fits:
    case True{}:
      Instant{z, (s - secs : U32), n}
    case False{}:
      Instant{(z - (((((secs - s : U32) + 86399 : U32)) / 86400 : U32)) : U32), ((((((secs - s : U32) + 86399 : U32)) / 86400 : U32) * 86400 : U32) - (secs - s : U32) : U32), n}

# S4.55 (spec twin) an instant moved by a zone offset: a `+HH:MM` local time is EARLIER in UTC
def shift(t: Instant, ahead: Bool, +secs: U32) -> Instant:
  match t ahead:
    case Instant{z, +s, n} True{}:
      earlier_pick(z, s, n, secs, (secs <= s : U32))
    case Instant{z, s, n} False{}:
      Instant{(z + (((s + secs : U32)) / 86400 : U32) : U32), (((s + secs : U32)) % 86400 : U32), n}

# S4.57 (spec twin) fraction digits, most significant first: value scaled to
# nanoseconds by the width that is left; a tenth digit or a non-digit is a verdict
def frac_go(cs: List<&2, U32>, left: Nat, +value: U32, ok: Bool) -> Frac:
  match cs left:
    case Nil{} 0n:
      Frac{value, ok}
    case Nil{} 1n+p:
      frac_go(Nil{}, p, (value * 10 : U32), ok)
    case Con{c, rest} 0n:
      Frac{value, False{}}
    case Con{+c, rest} 1n+p:
      frac_go(rest, p, ((value * 10 : U32) + (c - 48 : U32) : U32), (ok && is_dig(c)))

# S4.57 (spec twin) `.` then one to nine digits, or nothing at all
def frac_of(cs: List<&2, U32>) -> Frac:
  match cs:
    case Nil{}:
      Frac{0, True{}}
    case Con{+dot, Nil{}}:
      Frac{0, False{}}
    case Con{+dot, rest}:
      frac_go(rest, 9n, 0, U32.is_eq(dot, 46))

# S4.57 (data) a zone: valid, ahead of UTC, offset seconds, and the text before it (reversed)
type Zone is Data:
  Zone{ok: Bool, ahead: Bool, secs: U32, before: List<&2, U32>}

# S4.57 (spec twin) the zone at the END of the text (the text arrives REVERSED):
# `Z` or `z`, or sign HH `:` MM
def zone_of(rev: List<&2, U32>) -> Zone:
  match rev:
    case Con{+m2, Con{+m1, Con{+colon, Con{+h2, Con{+h1, Con{+sign, before}}}}}}:
      Zone{(U32.is_eq(colon, 58) && is_dig(h1) && is_dig(h2) && is_dig(m1) && is_dig(m2) && (U32.is_eq(sign, 43) || U32.is_eq(sign, 45)) && (two(h1, h2) <= 23 : U32) && (two(m1, m2) <= 59 : U32)), U32.is_eq(sign, 43), (((two(h1, h2) * 3600 : U32)) + (two(m1, m2) * 60 : U32) : U32), before}
    case _:
      Zone{False{}, False{}, 0, Nil{}}

# S4.57 (spec twin) route on the verdict computed by zone_pick
def zone_z(is_z: Bool, rev: List<&2, U32>) -> Zone:
  match is_z rev:
    case True{} Con{_, before}:
      Zone{True{}, False{}, 0, before}
    case True{} Nil{}:
      Zone{False{}, False{}, 0, Nil{}}
    case False{} rest:
      zone_of(rest)

# S4.57 (spec twin) a trailing `Z` (90) or `z` (122) is the zero offset
def zone_pick(rev: List<&2, U32>) -> Zone:
  match rev:
    case Con{+last, before}:
      zone_z(U32.is_eq(last, 90) || U32.is_eq(last, 122), last <> before)
    case Nil{}:
      Zone{False{}, False{}, 0, Nil{}}

# S4.57 (spec twin) the code points of a string, in order (a timestamp is short: depth <= 40)
def codes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{c}, rest}:
      c <> codes(rest)

# S4.55 S4.57 (spec twin) the instant, once every verdict is in
def build(ok: Bool, y: U32, m: U32, d: U32, sod: U32, nanos: U32, ahead: Bool, secs: U32) -> Parsed:
  match ok:
    case True{}:
      Good{shift(Instant{to_days(Civil{y, m, d}), sod, nanos}, ahead, secs)}
    case False{}:
      Bad{}

# S4.57 (spec twin) fold the fraction's verdict in
def finish(ok: Bool, y: U32, m: U32, d: U32, sod: U32, ahead: Bool, secs: U32, fr: Frac) -> Parsed:
  match fr:
    case Frac{value, fok}:
      build((ok && fok), y, m, d, sod, value, ahead, secs)

# S4.57 (spec twin) fold the zone's verdict in; the text between the seconds and the zone is the fraction
def assemble(ok: Bool, y: U32, m: U32, d: U32, sod: U32, zone: Zone) -> Parsed:
  match zone:
    case Zone{zok, ahead, secs, before}:
      finish((ok && zok), y, m, d, sod, ahead, secs, frac_of(List.reverse(&2, U32, before)))

# S4.57 (spec twin) field ranges: year >= 1, month 1..12, day 1..its month's length, 23:59:59 at most
def in_range(+y: U32, +m: U32, +d: U32, hh: U32, mm: U32, ss: U32) -> Bool:
  ((y >= 1 : U32) && (m >= 1 : U32) && (m <= 12 : U32) && (d >= 1 : U32) && (d <= dim(y, m) : U32) && (hh <= 23 : U32) && (mm <= 59 : U32) && (ss <= 59 : U32))

# S4.57 (spec twin) the fields of the nineteen fixed positions, validated together
def fields(ok: Bool, +y: U32, +m: U32, +d: U32, +hh: U32, +mm: U32, +ss: U32, zone: Zone) -> Parsed:
  assemble((ok && in_range(y, m, d, hh, mm, ss)), y, m, d, ((((hh * 3600 : U32)) + (mm * 60 : U32) : U32) + ss : U32), zone)

# S4.57 (spec twin) `YYYY-MM-DDTHH:MM:SS`, then an optional fraction, then the zone.
# `T`, `t` or a space separates date and time (`edge_time_spellings`: `2026-01-01 10:00:00Z` loads, OQ-099).
# 45 is `-`, 58 is `:`, 84 is `T`, 116 is `t`, 32 is the space.
def parse_codes(cs: List<&2, U32>) -> Parsed:
  match cs:
    case Con{+y1, Con{+y2, Con{+y3, Con{+y4, Con{+k1, Con{+m1, Con{+m2, Con{+k2, Con{+d1, Con{+d2, Con{+tt, Con{+h1, Con{+h2, Con{+k3, Con{+n1, Con{+n2, Con{+k4, Con{+s1, Con{+s2, rest}}}}}}}}}}}}}}}}}}}:
      fields((is_dig(y1) && is_dig(y2) && is_dig(y3) && is_dig(y4) && is_dig(m1) && is_dig(m2) && is_dig(d1) && is_dig(d2) && is_dig(h1) && is_dig(h2) && is_dig(n1) && is_dig(n2) && is_dig(s1) && is_dig(s2) && U32.is_eq(k1, 45) && U32.is_eq(k2, 45) && (U32.is_eq(tt, 84) || U32.is_eq(tt, 116) || U32.is_eq(tt, 32)) && U32.is_eq(k3, 58) && U32.is_eq(k4, 58)), (((two(y1, y2) * 100 : U32)) + two(y3, y4) : U32), two(m1, m2), two(d1, d2), two(h1, h2), two(n1, n2), two(s1, s2), zone_pick(List.reverse(&2, U32, rest)))
    case _:
      Bad{}

# S4.54 S4.55 S4.57 (spec twin) an RFC 3339 timestamp as an instant in UTC
def parse(s: String) -> Parsed:
  parse_codes(codes(s))

# ---------------------------------------------------------------- chrono's words for a refused spelling (S2.35)
# A stored timestamp that `parse` refuses is reported with the words chrono's RFC 3339 parser uses, measured by the
# `error_jsonl_ts_*` cases: the text walked against `YYYY-MM-DD?HH:MM:SS`, an optional `.fraction`, then `Z` or
# `±HH:MM`; running out first is `premature end of input`, a character of the wrong class is `input contains invalid
# characters`, text after a complete zone is `trailing input`, and a well-formed spelling with a field out of range
# (month 13, February 30, hour 25) is `input is out of range`.

# S2.35 (data) the verdict of one step of the walk: still going (at this index), or the words
type Walk is Data:
  WalkAt{next: Nat}
  WalkEnd{words: String}

# S2.35 (spec twin) the class a position of `YYYY-MM-DD?HH:MM:SS` wants: 0 a digit, 1 `-`, 2 the separator, 3 `:`
def class_at(+i: Nat) -> U32:
  Bool.pick(U32, (Nat.is_eq(i, 4n) || Nat.is_eq(i, 7n)), 1, Bool.pick(U32, Nat.is_eq(i, 10n), 2, Bool.pick(U32, (Nat.is_eq(i, 13n) || Nat.is_eq(i, 16n)), 3, 0)))

# S2.35 (spec twin) does a code point belong to a class
def fits(+c: U32, +class: U32) -> Bool:
  match class:
    case 0:
      is_dig(c)
    case 1:
      U32.is_eq(c, 45)
    case 2:
      (U32.is_eq(c, 84) || U32.is_eq(c, 116) || U32.is_eq(c, 32))
    case _:
      U32.is_eq(c, 58)

# S2.35 (spec twin) the fixed part, position by position: the 19 code points of `YYYY-MM-DD?HH:MM:SS`
def fixed_go(cs: List<&2, U32>, +i: Nat) -> Walk:
  match cs:
    case Nil{}:
      Bool.pick(Walk, Nat.is_lt(i, 19n), WalkEnd{"premature end of input"}, WalkAt{i})
    case Con{+c, rest}:
      Bool.pick(Walk, Nat.is_ge(i, 19n), WalkAt{i}, Bool.pick(Walk, fits(c, class_at(i)), fixed_go(rest, Nat.add(i, 1n)), WalkEnd{"input contains invalid characters"}))

# S2.35 (spec twin) the digits of a fraction, counted
def digit_run(cs: List<&2, U32>) -> Nat:
  match cs:
    case Nil{}:
      0n
    case Con{+c, rest}:
      Bool.pick(Nat, is_dig(c), Nat.add(digit_run(rest), 1n), 0n)

# S2.35 (spec twin) an offset `±HH:MM` after its sign: two digits, `:`, two digits
def offset_ok(cs: List<&2, U32>) -> Walk:
  match cs:
    case Con{+a, Con{+b, Con{+k, Con{+d, Con{+e, +rest}}}}}:
      Bool.pick(Walk, (is_dig(a) && is_dig(b) && U32.is_eq(k, 58) && is_dig(d) && is_dig(e)), Bool.pick(Walk, List.is_empty(&2, U32, rest), WalkEnd{""}, WalkEnd{"trailing input"}), WalkEnd{"input contains invalid characters"})
    case _:
      WalkEnd{"premature end of input"}

# S2.35 (spec twin) the zone: `Z`/`z` and nothing after, or a signed offset
def zone_walk(cs: List<&2, U32>) -> Walk:
  match cs:
    case Nil{}:
      WalkEnd{"premature end of input"}
    case Con{+c, +rest}:
      Bool.pick(Walk, (U32.is_eq(c, 90) || U32.is_eq(c, 122)), Bool.pick(Walk, List.is_empty(&2, U32, rest), WalkEnd{""}, WalkEnd{"trailing input"}), Bool.pick(Walk, (U32.is_eq(c, 43) || U32.is_eq(c, 45)), offset_ok(rest), WalkEnd{"input contains invalid characters"}))

# S2.35 (spec twin) after the seconds: an optional `.` with at least one digit, then the zone
def after_seconds(cs: List<&2, U32>) -> Walk:
  match cs:
    case Con{46, +rest}:
      Bool.pick(Walk, Nat.is_eq(digit_run(rest), 0n), Bool.pick(Walk, List.is_empty(&2, U32, rest), WalkEnd{"premature end of input"}, WalkEnd{"input contains invalid characters"}), zone_walk(List.drop(&2, U32, rest, digit_run(rest))))
    case other:
      zone_walk(other)

# S2.35 (spec twin) the tail's verdict: its words, or `input is out of range` when every part was well formed
def failure_tail(w: Walk) -> String:
  match w:
    case WalkEnd{SNil{}}:
      "input is out of range"
    case WalkEnd{SCon{h, t}}:
      SCon{h, t}
    case WalkAt{i}:
      "input is out of range"

# S2.35 (spec twin) the walk's verdict once the fixed part passed; a clean walk means a field was out of range
def walked(w: Walk, +cs: List<&2, U32>) -> String:
  match w:
    case WalkEnd{words}:
      words
    case WalkAt{i}:
      failure_tail(after_seconds(List.drop(&2, U32, cs, 19n)))

# S2.35 (spec twin) chrono's words for a spelling `parse` refused
def failure(+s: String) -> String:
  walked(fixed_go(codes(s), 0n), codes(s))

# S4.54 (spec twin) re-serialize a stored spelling; a malformed one is reported as the empty string
def reprint(p: Parsed, suffix: String) -> String:
  match p:
    case Good{at}:
      print(at, suffix)
    case Bad{}:
      ""
