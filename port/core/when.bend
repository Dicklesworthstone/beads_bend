# core/when — the date grammar of `--until`, `--due` and `--defer` (S4.322, S4.230).
# Tried in this order: an RFC 3339 instant; a bare date `YYYY-MM-DD` (09:00:00
# of that day); a relative offset `+<n><unit>` or `-<n><unit>` from the
# invocation instant; the keywords `today` (17:00:00), `yesterday`,
# `tomorrow`, `next-week`/`nextweek` (09:00:00). "Local" time is UTC here:
# the pinned environment sets TZ=UTC, and the port reads no time zone (the
# `+00:00:00` repair of S4.322 is not done either). Nothing here consults the original.
import Base
import ./time.bend as Time

# S4.322 S4.324 (data) the instant a text names, or why it names none: 0 not a time at all, 1 a bad unit, 2 out of range
type Named is Data:
  NoTime{why: U32}
  AtTime{at: Time.Instant}

# S4.322 (spec twin) a parsed instant as a verdict
def of_parsed(p: Time.Parsed) -> Named:
  match p:
    case Time.Bad{}:
      NoTime{0}
    case Time.Good{at}:
      AtTime{at}

# S4.322 (spec twin) the first verdict that names an instant; when neither does, the more specific reason is kept
def or_else(first: Named, second: Named) -> Named:
  match first second:
    case AtTime{at} _:
      AtTime{at}
    case NoTime{why} AtTime{at}:
      AtTime{at}
    case NoTime{a} NoTime{b}:
      NoTime{U32.max(a, b)}

# S4.322 (spec twin) ASCII lower case of one code point
def lower_char(+c: U32, up: Bool) -> U32:
  match up:
    case True{}:
      (c + 32 : U32)
    case False{}:
      c

# S4.322 (spec twin) a keyword is matched without regard to ASCII case
def lowered(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{lower_char(c, ((c >= 65 : U32) && (c <= 90 : U32)))}, lowered(rest)}

# S4.322 (spec twin) midnight of an instant's day, moved by whole days (`back` moves earlier) and then to an hour of that day
def day_at(t: Time.Instant, back: Bool, days: U32, hour: U32) -> Time.Instant:
  match t back:
    case Time.Instant{z, s, n} True{}:
      Time.Instant{(z - days : U32), (hour * 3600 : U32), 0}
    case Time.Instant{z, s, n} False{}:
      Time.Instant{(z + days : U32), (hour * 3600 : U32), 0}

# S4.322 (spec twin) the keywords: `today` is 17:00:00; `yesterday`, `tomorrow` and `next-week`/`nextweek` are 09:00:00
def keyword(+word: String, +now: Time.Instant) -> Named:
  Bool.pick(Named, String.eq(word, "today"), AtTime{day_at(now, False{}, 0, 17)}, Bool.pick(Named, String.eq(word, "yesterday"), AtTime{day_at(now, True{}, 1, 9)}, Bool.pick(Named, String.eq(word, "tomorrow"), AtTime{day_at(now, False{}, 1, 9)}, Bool.pick(Named, (String.eq(word, "next-week") || String.eq(word, "nextweek")), AtTime{day_at(now, False{}, 7, 9)}, NoTime{0}))))

# S4.322 (spec twin) the seconds of one unit; 0 for a letter that is no unit
def unit_secs(unit: U32) -> U32:
  match unit:
    case 109:
      60
    case 104:
      3600
    case 100:
      86400
    case 119:
      604800
    case _:
      0

# S4.322 (data) the digits and the unit letter of a relative offset: the number so far, whether any digit was seen,
# whether it grew past what the port's 32-bit seconds can hold, and the unit's code point (0 until it is read)
type Offset is Data:
  Offset{n: U32, seen: Bool, big: Bool, unit: U32, tail: Bool}

# S4.322 (spec twin) one code point of `<digits><unit>`: a digit before the unit grows the number (past 40,000,000
# it is "out of range" whatever the unit); the first other code point is the unit; anything after the unit spoils the text
def offset_step(+c: U32, +n: U32, seen: Bool, big: Bool, unit: U32, tail: Bool, digit: Bool, unit_free: Bool) -> Offset:
  match digit unit_free:
    case True{} _:
      Offset{((n * 10 : U32) + (c - 48 : U32) : U32), True{}, (big || (n > 40000000 : U32)), unit, tail}
    case False{} True{}:
      Offset{n, seen, big, c, tail}
    case False{} False{}:
      Offset{n, seen, big, unit, True{}}

# S4.322 (spec twin) read `<digits><unit>`: digits first, then exactly one more code point
def offset_go(cs: List<&2, U32>, o: Offset) -> Offset:
  match cs o:
    case Nil{} done:
      done
    case Con{+c, rest} Offset{n, seen, big, +unit, tail}:
      offset_go(rest, offset_step(c, n, seen, big, unit, tail, (((c >= 48 : U32) && (c <= 57 : U32)) && U32.is_eq(unit, 0)), U32.is_eq(unit, 0)))

# S4.322 S4.324 (spec twin) route a read offset: not a time; a bad unit; out of range; or the moved instant
def offset_pick(no_time: Bool, bad_unit: Bool, too_far: Bool, moved: Time.Instant) -> Named:
  match no_time bad_unit too_far:
    case True{} _ _:
      NoTime{0}
    case False{} True{} _:
      NoTime{1}
    case False{} False{} True{}:
      NoTime{2}
    case False{} False{} False{}:
      AtTime{moved}

# S4.322 S4.324 (spec twin) a read offset as a verdict: no digits, no unit or a spoiled text is "not a time"; a letter
# that is no unit is a bad unit; an offset past 4,000,000,000 seconds (about 126 years: what the port's 32-bit
# seconds hold; the original's own bound is wider) is out of range; else the invocation instant moved by it
def offset_named(o: Offset, now: Time.Instant, back: Bool) -> Named:
  match o:
    case Offset{+n, seen, big, +unit, tail}:
      offset_pick((Bool.not(seen) || tail || U32.is_eq(unit, 0)), U32.is_eq(unit_secs(unit), 0), (big || (n > (4000000000 / U32.max(unit_secs(unit), 1) : U32) : U32)), Time.shift(now, back, (n * unit_secs(unit) : U32)))

# S4.322 (spec twin) a relative offset: `+` moves later, `-` moves earlier
def relative(cs: List<&2, U32>, now: Time.Instant) -> Named:
  match cs:
    case Con{43, rest}:
      offset_named(offset_go(rest, Offset{0, False{}, False{}, 0, False{}}), now, False{})
    case Con{45, rest}:
      offset_named(offset_go(rest, Offset{0, False{}, False{}, 0, False{}}), now, True{})
    case other:
      NoTime{0}

# S4.322 (spec twin) the instant a text names, given the invocation instant: RFC 3339, then a bare date at 09:00:00,
# then a relative offset, then a keyword
def named(+text: String, +now: Time.Instant) -> Named:
  or_else(of_parsed(Time.parse(text)), or_else(of_parsed(Time.parse(text ++ "T09:00:00Z")), or_else(relative(Time.codes(text), now), keyword(lowered(text), now))))

# S4.322 S4.324 (spec twin) why a text names no instant, as the refusal's reason
def reason(why: U32) -> String:
  match why:
    case 1:
      "invalid unit (use m, h, d, w)"
    case 2:
      "relative duration is out of supported range"
    case _:
      "invalid time format (try: +1h, -7d, tomorrow, next-week, or 2025-01-15)"
