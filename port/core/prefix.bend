# core/prefix — the prefix new ids take, and the one `where` reports (S2.10–S2.15, S2.18, S2.20).
# Inputs: the text of `.beads/config.yaml` (the shell reads it), the loaded records in file order,
# and the workspace directory. Of YAML only what the prefix keys need is read: top-level
# `key: value` lines, a plain or a quoted scalar, and a ` #` comment after it; a nested key
# (`sync:` then `  prefix: zz`) is not a top-level key and does not count (`prefix_config_nested`).
# The user-level layers (`~/.beads/config.yaml`, `~/.config/beads/config.yaml`) are not read.
# Nothing here consults the original.
import Base
import ./model.bend as Model
import ./resolve.bend as Resolve
import ./failure.bend as Failure

# S2.18 (data) one top-level `key: value` line, the key lower-cased with `-` read as `_`
type Entry is Data:
  Entry{key: String, value: String}

# S2.10 (data) the prefix new ids take, or the configured value that sanitizes to nothing (S2.14)
type Minted is Data:
  MintOk{prefix: String}
  MintBad{raw: String}

# S2.18 (spec twin) a space or a tab
def blank(+c: U32) -> Bool:
  (U32.is_eq(c, 32) || U32.is_eq(c, 9))

# S2.18 (spec twin) every `-` of a key read as `_`
def dashes(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{Bool.pick(U32, U32.is_eq(c, 45), 95, c)}, dashes(rest)}

# S2.18 (spec twin) keep one code point in front of the rest, or stop the text there
def kept_or_stop(stop: Bool, c: U32, rest: String) -> String:
  match stop:
    case True{}:
      ""
    case False{}:
      SCon{Chr{c}, rest}

# S2.18 (spec twin) a plain scalar ends where a `#` follows a blank (a YAML comment)
def before_comment(s: String, after_blank: Bool) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      kept_or_stop((U32.is_eq(c, 35) && after_blank), c, before_comment(rest, blank(c)))

# S2.18 (spec twin) the left half of a cut
def cut_left(c: Resolve.Cut) -> String:
  match c:
    case Resolve.Cut{left, right, found}:
      left

# S2.18 (spec twin) a value that opens with a quote runs to the matching quote; a plain one to its comment
def scalar(v: String) -> String:
  match v:
    case SNil{}:
      ""
    case SCon{Chr{+c}, +rest}:
      Bool.pick(String, (U32.is_eq(c, 34) || U32.is_eq(c, 39)), cut_left(Resolve.cut_first(rest, c, Nil{})), String.trim(before_comment(SCon{Chr{c}, rest}, False{})))

# S2.18 (spec twin) does a line hold a top-level key: its first code point is not a blank, `#` or `-`
def top_level(line: String) -> Bool:
  match line:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, rest}:
      Bool.not((blank(c) || U32.is_eq(c, 35) || U32.is_eq(c, 45)))

# S2.18 (spec twin) the entry of a top-level line that has a `:`
def entry_pick(top: Bool, c: Resolve.Cut) -> Maybe<&2, Entry>:
  match top c:
    case True{} Resolve.Cut{left, right, True{}}:
      Some{Entry{dashes(Resolve.lowered(String.trim(left))), scalar(String.trim(right))}}
    case _ _:
      None{}

# S2.18 (spec twin) one line of `config.yaml` as an entry, when it is one
def entry_of(+line: String) -> Maybe<&2, Entry>:
  entry_pick(top_level(line), Resolve.cut_first(line, 58, Nil{}))

# S2.18 (spec twin) keep the value of an entry under the wanted key
def better(e: Maybe<&2, Entry>, +key: String, +found: Maybe<&2, String>) -> Maybe<&2, String>:
  match e:
    case None{}:
      found
    case Some{Entry{k, v}}:
      Bool.pick(Maybe<&2, String>, String.eq(k, key), Some{v}, found)

# S2.18 (spec twin) the value of a key: a later line wins, as a later layer of the merge does
def looked(lines: List<&2, String>, +key: String, +found: Maybe<&2, String>) -> Maybe<&2, String>:
  match lines:
    case Nil{}:
      found
    case Con{l, rest}:
      looked(rest, key, better(entry_of(l), key, found))

# S2.10 (spec twin) the first of two optional values that is given
def first_given(a: Maybe<&2, String>, b: Maybe<&2, String>) -> Maybe<&2, String>:
  match a:
    case Some{v}:
      Some{v}
    case None{}:
      b

# S2.10 S2.20 (spec twin) the configured prefix, raw: `issue_prefix` (also spelled `issue-prefix`) before `prefix`
# (`prefix_config_both`)
def configured(+text: String) -> Maybe<&2, String>:
  first_given(looked(String.split(text, Chr{10}), "issue_prefix", None{}), looked(String.split(text, Chr{10}), "prefix", None{}))

# ---------------------------------------------------------------- sanitizing (S2.13) and names (S2.12)

# S2.13 (spec twin) a code point a prefix keeps: `a`–`z`, `0`–`9`, `_`, `-`, `.`, `:`, `#`
def keeps(+c: U32) -> Bool:
  (((c >= 97 : U32) && (c <= 122 : U32)) || ((c >= 48 : U32) && (c <= 57 : U32)) || U32.is_eq(c, 95) || U32.is_eq(c, 45) || U32.is_eq(c, 46) || U32.is_eq(c, 58) || U32.is_eq(c, 35))

# S2.12 S2.13 (spec twin) keep one code point in front of the rest, or drop it
def kept(keep: Bool, c: U32, rest: String) -> String:
  match keep:
    case True{}:
      SCon{Chr{c}, rest}
    case False{}:
      rest

# S2.13 (spec twin) the code points a prefix keeps, in order
def keeping(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      kept(keeps(c), c, keeping(rest))

# S2.13 (spec twin) a separator the end of a prefix sheds: `_ - . : #`
def separator(+c: U32) -> Bool:
  (U32.is_eq(c, 95) || U32.is_eq(c, 45) || U32.is_eq(c, 46) || U32.is_eq(c, 58) || U32.is_eq(c, 35))

# S2.13 (spec twin) how many separators open a (reversed) text
def leading_separators(s: String) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{Chr{+c}, rest}:
      Bool.pick(Nat, separator(c), (1n + leading_separators(rest) : Nat), 0n)

# S2.13 (spec twin) a text without its trailing separators
def shed(+s: String) -> String:
  String.take(s, Nat.sub(String.length(s), leading_separators(String.reverse(s))))

# S2.13 (spec twin) trim, lower-case with the ASCII rule, keep the allowed code points, keep at most 64, then shed
# trailing separators
def sanitized(raw: String) -> String:
  shed(String.take(keeping(Resolve.lowered(String.trim(raw))), 64n))

# S2.12 (spec twin) an ASCII letter or digit
def alnum(+c: U32) -> Bool:
  (((c >= 97 : U32) && (c <= 122 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 48 : U32) && (c <= 57 : U32)))

# S2.12 (spec twin) the first code point of every run of letters and digits
def initials(s: String, fresh: Bool) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      kept((fresh && alnum(c)), c, initials(rest, Bool.not(alnum(c))))

# S2.12 (spec twin) the letters and digits of a text, in order
def alnums(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      kept(alnum(c), c, alnums(rest))

# S2.12 (spec twin) a long name: the initials of two or more segments (`beads_bend` → `bb`), else its first three
# letters and digits (`beadsrustproject` → `bea`), else the sanitized name itself
def long_name(+s: String, +ini: String, +three: String) -> String:
  Bool.pick(String, Nat.is_lt(1n, String.length(ini)), ini, Bool.pick(String, String.is_empty(three), s, three))

# S2.12 (spec twin) a sanitized directory name of six characters or fewer is used as it is
def name_pick(+s: String) -> String:
  Bool.pick(String, Nat.is_lt(String.length(s), 7n), s, long_name(s, initials(s, True{}), String.take(alnums(s), 3n)))

# S2.12 (spec twin) the prefix a directory name gives: the name after its last `/`
def from_directory(cwd: String) -> String:
  name_pick(sanitized(Resolve.remainder_of(Resolve.cut_last(cwd, 47))))

# ---------------------------------------------------------------- the store scan (S2.11)

# S2.11 (spec twin) the prefix an id gives: everything before its LAST `-`, when both sides are non-empty
def id_prefix(c: Resolve.Cut) -> String:
  match c:
    case Resolve.Cut{+left, +right, True{}}:
      Bool.pick(String, (String.is_empty(left) || String.is_empty(right)), "", left)
    case Resolve.Cut{left, right, False{}}:
      ""

# S2.11 (spec twin) a record the scan may take: not a tombstone, and its id splits
def scan_one(+i: Model.Issue) -> String:
  Bool.pick(String, String.eq(Model.status_of(i), "tombstone"), "", id_prefix(Resolve.cut_last(Model.id_of(i), 45)))

# S2.11 (spec twin) the prefix of the first usable record in file order; "" when there is none
def scanned(issues: List<&2, Model.Issue>) -> String:
  match issues:
    case Nil{}:
      ""
    case Con{+i, rest}:
      Bool.pick(String, String.is_empty(scan_one(i)), scanned(rest), scan_one(i))

# S2.10 (spec twin) with no configured value: the store's prefix, else the directory's, else `br`
def unconfigured(+scan: String, +named: String) -> String:
  Bool.pick(String, String.is_empty(scan), Bool.pick(String, String.is_empty(named), "br", named), scan)

# S2.10 S2.14 (spec twin) the prefix new ids take: the configured value sanitized (fatal when that leaves nothing),
# else the store scan, else the directory name, else `br`
def minted(config: Maybe<&2, String>, +issues: List<&2, Model.Issue>, +cwd: String) -> Minted:
  match config:
    case None{}:
      MintOk{unconfigured(scanned(issues), from_directory(cwd))}
    case Some{+raw}:
      Bool.pick(Minted, String.is_empty(sanitized(raw)), MintBad{raw}, MintOk{sanitized(raw)})

# S2.14 (spec twin) the refusal of a configured prefix that sanitizes to nothing: `CONFIG_ERROR`, exit 7
def refusal(raw: String) -> Failure.Failure:
  Failure.Failure{"CONFIG_ERROR", "Configuration error: issue_prefix " ++ Failure.quoted(raw) ++ " contains no usable ASCII letters, digits, or separators", None{}, False{}, Nil{}, 7}

# S2.10 (spec twin) the prefix as text; the refused case never reaches a command that uses it
def text_of(m: Minted) -> String:
  match m:
    case MintOk{prefix}:
      prefix
    case MintBad{raw}:
      ""

# ---------------------------------------------------------------- what `where` reports (S2.15)

# S2.15 (spec twin) `where`'s prefix: the configured value RAW, else the store's prefix (when the records agree it
# is theirs; when they do not, the first record's, which is also what the scan answers); nothing at all for an
# unconfigured empty store (`where_empty`)
def reported(config: Maybe<&2, String>, +issues: List<&2, Model.Issue>) -> Maybe<&2, String>:
  match config:
    case Some{raw}:
      Some{raw}
    case None{}:
      Bool.pick(Maybe<&2, String>, String.is_empty(scanned(issues)), None{}, Some{scanned(issues)})
