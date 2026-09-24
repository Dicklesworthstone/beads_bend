# core/store — the text of .beads/issues.jsonl as records, and back (S2.24–S2.27, S5.2–S5.3).
# Loading: split into lines, trim each, refuse the whole file on a git
# conflict marker (before any JSON is parsed) or on a line that is not a
# record, skip blank lines while still counting them. Writing: one
# Model.line per record, by id in byte order, each ended by one newline.
# `load` answers the file's records AS THEY ARE (what `show` reads, S2.38–S2.39);
# `model` answers the loaded model: every record through the repairs of S2.31–
# S2.36 and S5.9 (core/model `repaired`), ephemeral records dropped (S2.42).
# The import path (every command but `show`) also validates each record (S2.43–S2.54), refuses a duplicate id
# (S2.40, `show` too) and runs the import check (S2.57). Not here yet, and stated so nothing is assumed: the
# comment and dependency rules of S2.55–S2.56. Nothing here consults the original.
import Base
import ./json.bend as Json
import ./time.bend as Time
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

# S9.23 (spec twin) a report line joins the kept ones unless it is empty (not a marker)
def report_put(+l: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(l), rest, l <> rest)

# S9.23 (spec twin) the report lines that are markers (a line that is not one reports as the empty text)
def reported(lines: List<&2, String>) -> List<&2, String>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{l, rest}:
      report_put(l, reported(rest))

# S2.26 S9.23 (spec twin) the report lines of the markers in the file, in file order, the first FIVE only
# (`error_conflict_markers_many`: six markers, five lines); n is the 1-based line number. The report lines are
# collected REVERSED and concatenated once (appending to a growing string re-walks it).
def markers_go(ls: List<&2, List<&2, U32>>, +path: String, +n: U32, acc: List<&2, String>) -> String:
  match ls:
    case Nil{}:
      String.concat(List.take(&2, String, reported(List.reverse(&2, String, acc)), 5n))
    case Con{l, rest}:
      markers_go(rest, path, (n + 1 : U32), marker_line(marker_of(trim(l)), path, n) <> acc)

# S2.26 S9 (spec twin) the refusal for conflict markers: CONFIG_ERROR, exit 7, no hint, no context
def conflict(path: String, report: String) -> Failure.Failure:
  Failure.Failure{"CONFIG_ERROR", "Configuration error: Merge conflict markers detected in " ++ path ++ ".\n" ++ report ++ "Resolve conflicts before importing.", None{}, False{}, Nil{}, 7}

# S2.27 S9 (spec twin) the refusal for a line that is not a record: CONFIG_ERROR, exit 7
def invalid_json(n: U32, msg: String, col: U32) -> Failure.Failure:
  Failure.Failure{"CONFIG_ERROR", "Configuration error: Invalid JSON at line " ++ U32.show(n) ++ ": " ++ msg ++ " at line 1 column " ++ U32.show(col), None{}, False{}, Nil{}, 7}

# ---------------------------------------------------------------- the validation of a loaded record (S2.43–S2.54)
# Every rule is judged on the record as the file spells it, before the repairs of S2.36; the messages of one
# record are joined by `, ` in the order the rules are listed here, which is the order `error_load_all_a` and
# `error_load_all_b` measured.

# S2.44 (spec twin) a lower-case ASCII letter or digit
def id_char(+c: U32) -> Bool:
  (((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)))

# S2.44 (spec twin) every code point is a lower-case ASCII letter or digit
def id_chars(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      (id_char(c) && id_chars(rest))

# S2.44 (spec twin) a non-empty run of lower-case ASCII letters and digits
def id_word(+s: String) -> Bool:
  Bool.not(String.is_empty(s)) && id_chars(s)

# S2.44 (spec twin) a code point of the part before the hash: a lower-case letter, a digit, `_`, `.` or `-`
def head_char(+c: U32) -> Bool:
  (id_char(c) || U32.is_eq(c, 95) || U32.is_eq(c, 46) || U32.is_eq(c, 45))

# S2.44 (spec twin) every code point of the part before the hash is allowed
def head_chars(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      (head_char(c) && head_chars(rest))

# S2.44 (spec twin) a non-empty run of ASCII digits
def child_number(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{h, t}:
      Json.all_digits(SCon{h, t})

# S2.44 (spec twin) every dotted suffix is a child number
def child_numbers(parts: List<&2, String>) -> Bool:
  match parts:
    case Nil{}:
      True{}
    case Con{p, rest}:
      (child_number(p) && child_numbers(rest))

# S2.44 (spec twin) the last hyphen-separated word of an id
def last_word(words: List<&2, String>) -> String:
  match words:
    case Nil{}:
      ""
    case Con{w, Nil{}}:
      w
    case Con{w, rest}:
      last_word(rest)

# S2.44 (spec twin) the hash and its child numbers: a lower-case alphanumeric word of at most 40 characters (the
# dotted suffixes not counted), then digits after each `.`
def hash_parts(parts: List<&2, String>) -> Bool:
  match parts:
    case Nil{}:
      False{}
    case Con{+h, suffixes}:
      (id_word(h) && Nat.is_le(String.length(h), 40n) && child_numbers(suffixes))

# S2.44 (spec twin) the part before the last hyphen: not empty, at most 64 characters, lower-case letters, digits, `_`,
# `.` and `-` (`edge_load_id_prefix_*`: `my_proj`, `_proj`, `a.b`, `p_1` load; `MyProj` is refused)
def head_ok(+h: String) -> Bool:
  (Bool.not(String.is_empty(h)) && Nat.is_le(String.length(h), 64n) && head_chars(h))

# S2.44 (spec twin) `prefix-hash`: split at the LAST hyphen. The hash is measured by `edge_load_id_hash*` (40 loads,
# 41 is refused) and the prefix by `edge_load_id_head*` (64 loads, 65 is refused); refused shapes also include a
# trailing or leading hyphen, `_` or a space in the hash, and a word after a dot (`error_load_id_*`)
def id_split(+words: List<&2, String>, +id: String) -> Bool:
  (Nat.is_gt(List.length(&2, String, words), 1n) && hash_parts(String.split(last_word(words), Chr{46})) && head_ok(String.take(id, Nat.sub(String.length(id), Nat.add(String.length(last_word(words)), 1n)))))

# S2.44 (spec twin) a message when a rule holds
def msg_if(cond: Bool, +msg: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, cond, [msg], Nil{})

# S2.44 (spec twin) `id`: empty; else longer than 105 characters, and not `prefix-hash` shaped (both may be reported)
def id_msgs(+id: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(id), ["id: cannot be empty"], List.append(&2, String, msg_if(Nat.is_gt(String.length(id), 105n), "id: exceeds 105 characters"), msg_if(Bool.not(id_split(String.split(id, Chr{45}), id)), "id: invalid format (expected prefix-hash)")))

# S2.51 (spec twin) does a text hold a NUL, or was one found already. An accumulator, not `hit || has_nul(rest)`:
# the operator waits for the recursion, and a member as long as a real store holds made the JS lane fault (bb-rvt)
def nul_go(s: String, found: Bool) -> Bool:
  match s:
    case SNil{}:
      found
    case SCon{Chr{+c}, rest}:
      nul_go(rest, (found || U32.is_eq(c, 0)))

# S2.51 (spec twin) does a text hold a NUL
def has_nul(s: String) -> Bool:
  nul_go(s, False{})

# S2.51 (spec twin) the NUL rule of one member
def nul_msg(+field: String, s: String) -> List<&2, String>:
  msg_if(has_nul(s), field ++ ": cannot contain NUL bytes")

# S2.51 (spec twin) the NUL rule of an optional member
def nul_opt(+field: String, v: Maybe<&2, String>) -> List<&2, String>:
  match v:
    case None{}:
      Nil{}
    case Some{s}:
      nul_msg(field, s)

# S2.49 S2.51 (spec twin) an optional short member: more than 200 characters, then a NUL
def person_msgs(+field: String, v: Maybe<&2, String>) -> List<&2, String>:
  match v:
    case None{}:
      Nil{}
    case Some{+s}:
      List.append(&2, String, msg_if(Nat.is_gt(String.length(s), 200n), field ++ ": exceeds 200 characters"), nul_msg(field, s))

# S2.50 (spec twin) Unicode white space, as Rust's `char::is_whitespace` reads it
def is_space(+c: U32) -> Bool:
  (((c >= 9 : U32) && (c <= 13 : U32)) || U32.is_eq(c, 32) || U32.is_eq(c, 133) || U32.is_eq(c, 160) || U32.is_eq(c, 5760) || ((c >= 8192 : U32) && (c <= 8202 : U32)) || U32.is_eq(c, 8232) || U32.is_eq(c, 8233) || U32.is_eq(c, 8239) || U32.is_eq(c, 8287) || U32.is_eq(c, 12288))

# S2.50 (spec twin) does a text hold white space, or was some found already (an accumulator, as `nul_go`)
def space_go(s: String, found: Bool) -> Bool:
  match s:
    case SNil{}:
      found
    case SCon{Chr{+c}, rest}:
      space_go(rest, (found || is_space(c)))

# S2.50 (spec twin) does a text hold white space
def has_space(s: String) -> Bool:
  space_go(s, False{})

# S2.50 S2.51 (spec twin) `external_ref`: more than 200 BYTES, white space, a NUL
def ref_msgs(v: Maybe<&2, String>) -> List<&2, String>:
  match v:
    case None{}:
      Nil{}
    case Some{+s}:
      List.concat(&2, String, [msg_if((Json.byte_len(Json.codes(s)) > 200 : U32), "external_ref: exceeds 200 characters"), msg_if(has_space(s), "external_ref: cannot contain whitespace"), nul_msg("external_ref", s)])

# S2.52 S2.51 (spec twin) `status` and `issue_type`: a custom word longer than 50 characters, then a NUL (the
# built-in words are all shorter)
def word_msgs(+field: String, +noun: String, +s: String) -> List<&2, String>:
  List.append(&2, String, msg_if(Nat.is_gt(String.length(s), 50n), field ++ ": custom " ++ noun ++ " exceeds 50 characters"), nul_msg(field, s))

# S2.54 (spec twin) is every code point of a label allowed
def label_chars(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      ((id_char(c) || ((c >= 65 : U32) && (c <= 90 : U32)) || U32.is_eq(c, 45) || U32.is_eq(c, 95) || U32.is_eq(c, 58)) && label_chars(rest))

# S2.54 (spec twin) the first rule one label breaks: empty, more than 50 bytes, a character outside the set
def label_msg(+s: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(s), ["cannot be empty"], Bool.pick(List<&2, String>, (Json.byte_len(Json.codes(s)) > 50 : U32), ["exceeds 50 characters"], msg_if(Bool.not(label_chars(s)), "invalid characters (only alphanumeric, hyphen, underscore, colon allowed)")))

# S2.53 (spec twin) each label's message wrapped with its 0-based index
def label_wrapped(msgs: List<&2, String>, +index: U32) -> List<&2, String>:
  match msgs:
    case Nil{}:
      Nil{}
    case Con{m, rest}:
      ("labels: label at index " ++ U32.show(index) ++ ": " ++ m) <> label_wrapped(rest, index)

# S2.53 (spec twin) the labels left to right
def label_msgs(ls: List<&2, String>, +index: U32) -> List<&2, String>:
  match ls:
    case Nil{}:
      Nil{}
    case Con{+l, rest}:
      List.append(&2, String, label_wrapped(label_msg(l), index), label_msgs(rest, (index + 1 : U32)))

# S2.53 (spec twin) `labels`: more than 64, then each label in byte order (`error_load_label_bad`: `["ok", "bad
# label"]` reports index 0)
def labels_msgs(+ls: List<&2, String>) -> List<&2, String>:
  List.append(&2, String, msg_if(Nat.is_gt(List.length(&2, String, ls), 64n), "labels: exceeds 64 labels"), label_msgs(List.sort(~String, ~String.is_le, ls), 0))

# S2.45 (spec twin) `priority`: anything but 0 to 4
def priority_msgs(+p: String) -> List<&2, String>:
  msg_if(Bool.not(String.eq(p, "0") || String.eq(p, "1") || String.eq(p, "2") || String.eq(p, "3") || String.eq(p, "4")), "priority: must be 0-4")

# S2.47 (spec twin) `estimated_minutes`: negative, or above 525960 (the digits compared as a word, never as a `Nat`)
def estimate_msgs(v: Maybe<&2, String>) -> List<&2, String>:
  match v:
    case None{}:
      Nil{}
    case Some{+d}:
      Bool.pick(List<&2, String>, String.starts_with(d, "-"), ["estimated_minutes: cannot be negative"], msg_if((Nat.is_gt(String.length(d), 6n) || (Maybe.default(&2, U32, U32.read(d), 0) > 525960 : U32)), "estimated_minutes: exceeds maximum (525960 minutes / ~1 year)"))

# S2.48 (spec twin) `closed_at` earlier than `created_at`
def closed_msgs(closed: Maybe<&2, Time.Instant>, +created: Time.Instant) -> List<&2, String>:
  match closed:
    case None{}:
      Nil{}
    case Some{at}:
      msg_if(Bool.not(Time.le(created, at)), "closed_at: cannot be before created_at")

# S2.43–S2.54 (spec twin) every message of one record, in the measured order
def violations(+i: Model.Issue) -> List<&2, String>:
  List.concat(&2, String, [id_msgs(Model.id_of(i)), msg_if(String.is_empty(String.trim(Model.title_of(i))), "title: cannot be empty"), msg_if(Nat.is_gt(String.length(Model.title_of(i)), 500n), "title: exceeds 500 characters"), nul_msg("title", Model.title_of(i)), nul_opt("description", Model.description_of(i)), nul_opt("design", Model.design_of(i)), nul_opt("acceptance_criteria", Model.acceptance_of(i)), nul_opt("prerequisites", Model.prerequisites_of(i)), nul_opt("notes", Model.notes_of(i)), word_msgs("status", "status", Model.status_of(i)), word_msgs("issue_type", "issue type", Model.type_of(i)), person_msgs("assignee", Model.assignee_of(i)), person_msgs("owner", Model.owner_of(i)), person_msgs("created_by", Model.created_by_of(i)), ref_msgs(Model.external_ref_of(i)), person_msgs("source_system", Model.source_system_of(i)), labels_msgs(Model.labels_of(i)), priority_msgs(Model.priority_of(i)), estimate_msgs(Model.estimate_of(i)), closed_msgs(Model.closed_of(i), Model.created_of(i))])

# S2.30 S9 (spec twin) a record that parses but breaks a rule: CONFIG_ERROR, exit 7 (S2.30's exit 4 was measured
# wrong: `error_jsonl_bad_id_format`)
def invalid_record(+id: String, n: U32, msgs: List<&2, String>) -> Failure.Failure:
  Failure.Failure{"CONFIG_ERROR", "Configuration error: Validation failed for issue " ++ id ++ " at line " ++ U32.show(n) ++ ": " ++ String.join(msgs, ", "), None{}, False{}, Nil{}, 7}

# S2.40 S9 (spec twin) a second line with an id already loaded: CONFIG_ERROR, exit 7, naming the second line
def duplicate(+id: String, path: String, n: U32) -> Failure.Failure:
  Failure.Failure{"CONFIG_ERROR", "Configuration error: Duplicate issue id '" ++ id ++ "' in " ++ path ++ " at line " ++ U32.show(n), None{}, False{}, Nil{}, 7}

# S2.40 (spec twin) is an id among the records loaded so far
def has_id(issues: List<&2, Model.Issue>, +id: String) -> Bool:
  match issues:
    case Nil{}:
      False{}
    case Con{i, rest}:
      (String.eq(Model.id_of(i), id) || has_id(rest, id))

# ---------------------------------------------------------------- the import check (S2.57)

# S2.24 (data) the records of a store, or the refusal of the whole load
type Loaded is Data:
  LoadBad{failure: Failure.Failure}
  LoadOk{issues: List<&2, Model.Issue>}

# S2.57 (spec twin) themembers whose `""` the import does not carry through, in alphabetical order: the import
# refuses a record that holds `""` in any of them (`edge_empty_optionals_*`, `edge_empty_source_repo`)
def empty_put(+name: String, v: Maybe<&2, String>, rest: List<&2, String>) -> List<&2, String>:
  match v:
    case Some{SNil{}}:
      name <> rest
    case _:
      rest

# S2.57 (data) the ids of the store as the import asks "is this target stored": the records scanned (the spec
# twin, `load`) or a set built once (the fast twin, `load_fast`)
type Ids is Data:
  IdScan{issues: List<&2, Model.Issue>}
  IdSet{set: Map<&2, Bool>}

# S2.57 (fast twin) the set of the stored ids
def id_set_go(issues: List<&2, Model.Issue>, m: Map<&2, Bool>) -> Map<&2, Bool>:
  match issues:
    case Nil{}:
      m
    case Con{+i, rest}:
      id_set_go(rest, Map.set(&2, Bool, m, Model.id_of(i), True{}))

# S2.57 (spec twin) the ids the import asks: the scan for the spec loop, the set for the fast one
def ids_of(fast: Bool, +issues: List<&2, Model.Issue>) -> Ids:
  match fast:
    case False{}:
      IdScan{issues}
    case True{}:
      IdSet{id_set_go(issues, Map.new(&2, Bool))}

# S2.57 (fast twin) the answer half of a set lookup
def id_answer(mb: Map<&2, Bool> & Bool) -> Bool:
  (m, b) = mb
  b

# S2.57 (spec twin) is this id one of a stored record
def stored(+ids: Ids, +id: String) -> Bool:
  match ids:
    case IdScan{issues}:
      has_id(issues, id)
    case IdSet{set}:
      id_answer(Map.has(&2, Bool, set, id))

# S2.57 (spec twin) does any dependency name a target that is neither `external:…` nor stored (a tombstone is stored);
# an accumulator, as `nul_go`
def dangling_go(ds: List<&2, Model.Dependency>, +ids: Ids, found: Bool) -> Bool:
  match ds:
    case Nil{}:
      found
    case Con{+d, rest}:
      dangling_go(rest, ids, (found || (Bool.not(String.starts_with(Model.target_of(d), "external:")) && Bool.not(stored(ids, Model.target_of(d))))))

# S2.57 (spec twin) a member name put in front when the verdict says so
def name_if(hit: Bool, +name: String, rest: List<&2, String>) -> List<&2, String>:
  match hit:
    case True{}:
      name <> rest
    case False{}:
      rest

# S2.57 (spec twin) the differing members of one record, in alphabetical order: the four members whose `""` the import
# does not carry through, and `dependencies` when one of them has no stored target (OQ-131)
def differing(i: Model.Issue, +ids: Ids) -> List<&2, String>:
  match i:
    case Model.Issue{head, texts, people, times, Model.Closing{a, b, c, bypass_reason, e}, Model.Source{f, g, source_repo, source_repo_path, agent_context}, deletion, compaction, meta, flags, labels, dependencies, comments}:
      empty_put("agent_context", agent_context, empty_put("bypass_reason", bypass_reason, name_if(dangling_go(dependencies, ids, False{}), "dependencies", empty_put("source_repo", source_repo, empty_put("source_repo_path", source_repo_path, Nil{})))))

# S2.57 S9 (spec twin) the import's refusal: SYNC_CONFLICT, exit 6, the message again as the context
def sync_failure(+inner: String) -> Failure.Failure:
  Failure.Failure{"SYNC_CONFLICT", "Sync conflict: " ++ inner, None{}, False{}, [Failure.CtxMember{"message", Failure.CStr{inner}}], 6}

# S2.57 (spec twin) the import check's words for one record and its differing members
def sync_conflict(id: String, fields: List<&2, String>) -> Failure.Failure:
  sync_failure("Import semantic verification failed: issue " ++ id ++ " does not match its normalized JSONL payload (differing fields: " ++ String.join(fields, ", ") ++ "); rolling back the import")

# S2.57 (spec twin) one record's refusal, if it has differing members
def conflict_of(fields: List<&2, String>, +i: Model.Issue) -> Maybe<&2, Failure.Failure>:
  match fields:
    case Nil{}:
      None{}
    case Con{h, t}:
      Some{sync_conflict(Model.id_of(i), h <> t)}

# S2.57 S2.58 (spec twin) a refusal found already is kept; otherwise this record is asked
def conflict_keep(found: Maybe<&2, Failure.Failure>, +i: Model.Issue, +ids: Ids) -> Maybe<&2, Failure.Failure>:
  match found:
    case Some{f}:
      Some{f}
    case None{}:
      conflict_of(differing(i, ids), i)

# S2.57 (spec twin) the first record, in file order, the import refuses (with several, the original names one at
# random: DISC-012); an accumulator, so a store of thousands of records does not recurse once per record
def first_conflict(issues: List<&2, Model.Issue>, +ids: Ids, found: Maybe<&2, Failure.Failure>) -> Maybe<&2, Failure.Failure>:
  match issues:
    case Nil{}:
      found
    case Con{+i, rest}:
      first_conflict(rest, ids, conflict_keep(found, i, ids))

# S2.58 (spec twin) a dependency whose `issue_id` is another record's: VALIDATION_FAILED, exit 4
def dep_other(+issue: String, +id: String) -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: dependency.issue_id: dependency issue_id '" ++ issue ++ "' does not match import issue '" ++ id ++ "'", None{}, True{}, [Failure.CtxMember{"field", Failure.CStr{"dependency.issue_id"}}, Failure.CtxMember{"reason", Failure.CStr{"dependency issue_id '" ++ issue ++ "' does not match import issue '" ++ id ++ "'"}}], 4}

# S2.58 (spec twin) a dependency on the record itself: SELF_DEPENDENCY, exit 5 (the words of S4.356)
def dep_self(+id: String) -> Failure.Failure:
  Failure.Failure{"SELF_DEPENDENCY", "Issue cannot depend on itself: " ++ id, Some{"An issue cannot depend on itself"}, False{}, [Failure.CtxMember{"id", Failure.CStr{id}}], 5}

# S2.58 (spec twin) the rule one dependency breaks: the `issue_id` first, then the target
def dep_pick(other: Bool, self: Bool, +issue: String, +id: String) -> Maybe<&2, Failure.Failure>:
  match other self:
    case True{} _:
      Some{dep_other(issue, id)}
    case False{} True{}:
      Some{dep_self(id)}
    case False{} False{}:
      None{}

# S2.58 (spec twin) a refusal found already is kept; otherwise this dependency is asked
def dep_keep(found: Maybe<&2, Failure.Failure>, +d: Model.Dependency, +id: String) -> Maybe<&2, Failure.Failure>:
  match found:
    case Some{f}:
      Some{f}
    case None{}:
      dep_pick(Bool.not(String.eq(Model.dep_issue_of(d), id)), String.eq(Model.target_of(d), id), Model.dep_issue_of(d), id)

# S2.58 (spec twin) the first dependency of a record that breaks a rule, in order
def deps_rule(ds: List<&2, Model.Dependency>, +id: String, found: Maybe<&2, Failure.Failure>) -> Maybe<&2, Failure.Failure>:
  match ds:
    case Nil{}:
      found
    case Con{+d, rest}:
      deps_rule(rest, id, dep_keep(found, d, id))

# S2.58 (spec twin) a refusal found already is kept; otherwise this record's dependencies are asked
def record_keep(found: Maybe<&2, Failure.Failure>, +i: Model.Issue) -> Maybe<&2, Failure.Failure>:
  match found:
    case Some{f}:
      Some{f}
    case None{}:
      deps_rule(Model.deps_of(i), Model.id_of(i), None{})

# S2.58 (spec twin) the first record, in file order, with a dependency that breaks a rule
def records_rule(issues: List<&2, Model.Issue>, found: Maybe<&2, Failure.Failure>) -> Maybe<&2, Failure.Failure>:
  match issues:
    case Nil{}:
      found
    case Con{+i, rest}:
      records_rule(rest, record_keep(found, i))

# S2.57 S2.58 (spec twin) the store, or the refusal the import found
def verdict_of(found: Maybe<&2, Failure.Failure>, +issues: List<&2, Model.Issue>) -> Loaded:
  match found:
    case Some{f}:
      LoadBad{f}
    case None{}:
      LoadOk{issues}

# S2.57 S2.58 (spec twin) the import's checks in their order: every record's dependency edges (S2.58), then the
# members each record would not carry through (S2.57)
def checked(edges: Maybe<&2, Failure.Failure>, +issues: List<&2, Model.Issue>, +ids: Ids) -> Loaded:
  match edges:
    case Some{f}:
      LoadBad{f}
    case None{}:
      verdict_of(first_conflict(issues, ids, None{}), issues)

# S2.57 S2.58 (spec twin) a loaded store through the import; `show` reads the file directly and skips it. `fast`
# picks the id set over the scan (`load_fast` against `load`)
def imported(st: Loaded, strict: Bool, +fast: Bool) -> Loaded:
  match st strict:
    case LoadBad{f} _:
      LoadBad{f}
    case LoadOk{issues} False{}:
      LoadOk{issues}
    case LoadOk{+issues} True{}:
      checked(records_rule(issues, None{}), issues, ids_of(fast, issues))

# ---------------------------------------------------------------- the record loop

# S2.30 S2.40 (spec twin) a decoded record joins the store unless it breaks a rule (the import path only) or repeats
# an id; acc is REVERSED
def accepted(+sofar: List<&2, Model.Issue>, +i: Model.Issue, n: U32, path: String, msgs: List<&2, String>) -> Loaded:
  match msgs:
    case Con{m, rest}:
      LoadBad{invalid_record(Model.id_of(i), n, m <> rest)}
    case Nil{}:
      Bool.pick(Loaded, has_id(sofar, Model.id_of(i)), LoadBad{duplicate(Model.id_of(i), path, n)}, LoadOk{i <> sofar})

# S2.27 S2.30 S2.40 (spec twin) fold one decoded line in; a refusal is sticky, and the first failing line wins;
# `strict` is the import path (every command but `show`)
def keep(st: Loaded, d: Decode.Dec, +n: U32, path: String, +strict: Bool) -> Loaded:
  match st d:
    case LoadBad{f} _:
      LoadBad{f}
    case LoadOk{sofar} Decode.DecOk{+i}:
      accepted(sofar, i, n, path, Bool.pick(List<&2, String>, strict, violations(i), Nil{}))
    case LoadOk{sofar} Decode.DecBad{msg, col}:
      LoadBad{invalid_json(n, msg, col)}

# S2.24 (spec twin) a line that is empty after trimming is skipped but still counted
def line_step(st: Loaded, +l: List<&2, U32>, n: U32, path: String, strict: Bool) -> Loaded:
  match l:
    case Nil{}:
      st
    case Con{c, rest}:
      keep(st, Decode.issue_of(l, byte_len(l, 0)), n, path, strict)

# S2.24 S2.27 (spec twin) the loop over the lines; n is the 1-based line number
def records_go(ls: List<&2, List<&2, U32>>, +n: U32, st: Loaded, +path: String, +strict: Bool) -> Loaded:
  match ls:
    case Nil{}:
      st
    case Con{l, rest}:
      records_go(rest, (n + 1 : U32), line_step(st, trim(l), n, path, strict), path, strict)

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

# S2.40 (data) the fast fold's state: the spec fold's, and the ids loaded so far as a Map (a crit-bit trie), so a
# repeated id is found by one lookup instead of a scan of every earlier record
type Held is Data:
  Held{st: Loaded, ids: Map<&2, Bool>}

# S2.40 (fast twin) `accepted`'s duplicate verdict from the lookup's answer
def seen_pick(seen: Bool, ids: Map<&2, Bool>, +sofar: List<&2, Model.Issue>, +i: Model.Issue, n: U32, path: String) -> Held:
  match seen:
    case True{}:
      Held{LoadBad{duplicate(Model.id_of(i), path, n)}, ids}
    case False{}:
      Held{LoadOk{i <> sofar}, Map.set(&2, Bool, ids, Model.id_of(i), True{})}

# S2.40 (fast twin) the lookup's pair taken apart
def seen_of(r: Map<&2, Bool> & Bool, +sofar: List<&2, Model.Issue>, +i: Model.Issue, n: U32, path: String) -> Held:
  (ids, seen) = r
  seen_pick(seen, ids, sofar, i, n, path)

# S2.30 S2.40 (fast twin) `accepted` with the id index
def accepted_held(+sofar: List<&2, Model.Issue>, +i: Model.Issue, n: U32, path: String, msgs: List<&2, String>, ids: Map<&2, Bool>) -> Held:
  match msgs:
    case Con{m, rest}:
      Held{LoadBad{invalid_record(Model.id_of(i), n, m <> rest)}, ids}
    case Nil{}:
      seen_of(Map.has(&2, Bool, ids, Model.id_of(i)), sofar, i, n, path)

# S2.27 S2.30 S2.40 (fast twin) `keep` with the id index
def keep_held(st: Loaded, d: Decode.Dec, +n: U32, path: String, +strict: Bool, ids: Map<&2, Bool>) -> Held:
  match st d:
    case LoadBad{f} _:
      Held{LoadBad{f}, ids}
    case LoadOk{sofar} Decode.DecOk{+i}:
      accepted_held(sofar, i, n, path, Bool.pick(List<&2, String>, strict, violations(i), Nil{}), ids)
    case LoadOk{sofar} Decode.DecBad{msg, col}:
      Held{LoadBad{invalid_json(n, msg, col)}, ids}

# S2.24 S2.27 (fast twin) one decoded line folded in: a blank line counts but adds nothing
def step_keep(h: Held, s: Step, n: U32, path: String, strict: Bool) -> Held:
  match h s:
    case Held{st, ids} Blank{}:
      Held{st, ids}
    case Held{st, ids} Line{d}:
      keep_held(st, d, n, path, strict, ids)

# S2.24 S2.27 (fast twin) the fold over the decoded lines, exactly the spec loop's: a refusal is sticky and names
# its 1-based line
def fold_steps(steps: List<&2, Step>, +n: U32, h: Held, +path: String, +strict: Bool) -> Held:
  match steps:
    case Nil{}:
      h
    case Con{s, rest}:
      fold_steps(rest, (n + 1 : U32), step_keep(h, s, n, path, strict), path, strict)

# S2.24 (fast twin) the fold's records, without the index
def held_st(h: Held) -> Loaded:
  match h:
    case Held{st, ids}:
      st

# S2.26 S2.57 (fast twin) as `guarded`, the lines decoded in parallel before the fold (16 tasks)
def guarded_fast(+ls: List<&2, List<&2, U32>>, +path: String, report: String, +strict: Bool) -> Loaded:
  match report:
    case SNil{}:
      imported(in_file_order(held_st(fold_steps(steps_par(4n, ls, List.length(&2, List<&2, U32>, ls)), 1, Held{LoadOk{Nil{}}, Map.new(&2, Bool)}, path, strict))), strict, True{})
    case SCon{h, t}:
      LoadBad{conflict(path, SCon{h, t})}

# S2.26 (fast twin) the lines split once and read twice, as in `load_lines`
def load_fast_lines(+ls: List<&2, List<&2, U32>>, +path: String, strict: Bool) -> Loaded:
  guarded_fast(ls, path, markers_go(ls, path, 1, Nil{}), strict)

# S2.24 S2.26 S2.27 (fast twin) `load` with the parallel decode; bound to `load` by the closed laws
# `store_load_fast_basic`, `store_load_fast_precision` and `store_load_fast_refusal`; `BEADS_RUST_SPEC=1` selects `load`
def load_fast(cs: List<&2, U32>, +path: String) -> Loaded:
  load_fast_lines(lines_go(cs, Nil{}, Nil{}), path, True{})

# S2.26 S2.57 (spec twin) markers refuse the load before any line is parsed as JSON; the import path then checks
# the loaded records (S2.57)
def guarded(+ls: List<&2, List<&2, U32>>, +path: String, report: String, +strict: Bool) -> Loaded:
  match report:
    case SNil{}:
      imported(in_file_order(records_go(ls, 1, LoadOk{Nil{}}, path, strict)), strict, False{})
    case SCon{h, t}:
      LoadBad{conflict(path, SCon{h, t})}

# S2.26 (spec twin) the lines are split once and read twice: by the marker scan, then by the record loop
def load_lines(+ls: List<&2, List<&2, U32>>, +path: String, strict: Bool) -> Loaded:
  guarded(ls, path, markers_go(ls, path, 1, Nil{}), strict)

# S2.38 S2.40 (spec twin) what `show` reads: the file directly, with the duplicate-id refusal but neither the record
# validation nor the import check (`error_load_bad_id_show`, `edge_empty_optionals_show`, `error_jsonl_duplicate_id_show`)
def load_read(cs: List<&2, U32>, +path: String) -> Loaded:
  load_lines(lines_go(cs, Nil{}, Nil{}), path, False{})

# S2.24 S2.26 S2.27 (spec twin) the store from the file's code points; `path` is the absolute store path the messages quote
def load(cs: List<&2, U32>, path: String) -> Loaded:
  load_lines(lines_go(cs, Nil{}, Nil{}), path, True{})

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

# S2.24 (spec twin) the model of a load, none for a refused one (the laws' way into a fixture's records)
def issues_of(l: Loaded) -> List<&2, Model.Issue>:
  match l:
    case LoadBad{f}:
      Nil{}
    case LoadOk{issues}:
      model(issues)

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
