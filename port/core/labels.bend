# core/labels — `label add`, `label remove`, `label rename` and `comments add`
# (S4.370–S4.385, S5.49–S5.51, S5.183–S5.194).
# The label commands iterate LABELS in the outer loop and ISSUES in the inner
# one (S4.371), so the rows are label-major. Every named label is validated
# before any issue is touched, so an invalid one leaves no write and no output.
# Not here yet, refused with the port's own failure by the dispatcher:
# `comments add -f` (a file or stdin), the walk of S4.370 that splits more than
# two positionals, and an issue positional that resolves to nothing (S4.370
# names a message no case captures). The 64-label ceiling of S4.372 is not
# checked either (OQ-125). Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./blocked.bend as Blocked
import ./create.bend as Create
import ./status.bend as Status
import ./render.bend as Render

# S4.370–S4.377 (data) what a label or comment command answered: the refusal, or the model to write, the plain text,
# the JSON payload, the id for `.beads/last-touched` ("" when none is written) and whether a record changed
type Done is Data:
  LabelBad{failure: Failure.Failure}
  LabelOk{model: List<&2, Model.Issue>, plain: String, json: String, last: String, changed: Bool}

# S4.372 (spec twin) the refusal of a label that is empty, too long, or holds a character outside the set
def label_refusal(+label: String) -> Failure.Failure:
  Create.invalid("label", Bool.pick(String, String.is_empty(label), "cannot be empty", Bool.pick(String, Nat.is_gt(String.length(label), 50n), "exceeds 50 characters", "invalid characters (only alphanumeric, hyphen, underscore, colon allowed)")))

# S4.372 (spec twin) is one label allowed: 1–50 characters of ASCII letters, digits, `-`, `_` or `:`
def label_ok(+label: String) -> Bool:
  (Bool.not(String.is_empty(label)) && Bool.not(Nat.is_gt(String.length(label), 50n)) && Create.label_ok(label))

# S4.372 (spec twin) the first label that is not allowed, "" when every one is
def first_bad(labels: List<&2, String>) -> String:
  match labels:
    case Nil{}:
      ""
    case Con{+l, rest}:
      Bool.pick(String, label_ok(l), first_bad(rest), l)

# S4.373 S4.375 (spec twin) the issue with this label set and `updated_at` bumped
def with_labels(i: Model.Issue, labels: List<&2, String>, now: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, c, d, e, f, g}, closing, source, deletion, compaction, meta, flags, old, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, now, c, d, e, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S4.373 (spec twin) the model with one issue replaced
def replaced(model: List<&2, Model.Issue>, +new: Model.Issue) -> List<&2, Model.Issue>:
  match model:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      Bool.pick(Model.Issue, String.eq(Model.id_of(i), Model.id_of(new)), new, i) <> replaced(rest, new)

# S5.376 (spec twin) one row of the JSON array
def row(status: String, +id: String, +label: String) -> String:
  String.concat(["{\"status\":", Failure.quoted(status), ",\"issue_id\":", Failure.quoted(id), ",\"label\":", Failure.quoted(label), "}"])

# S4.373 S4.374 S5.183 (spec twin) one (issue, label) pair of `label add`: a label the issue already carries is a
# success no-op that rewrites nothing
def add_pair(+model: List<&2, Model.Issue>, +i: Model.Issue, +label: String, now: Time.Instant, held: Bool) -> Done:
  match held:
    case True{}:
      LabelOk{model, "✓ Label " ++ Render.inline(label) ++ " already exists on " ++ Render.inline(Model.id_of(i)) ++ "\n", row("exists", Model.id_of(i), label), Model.id_of(i), False{}}
    case False{}:
      LabelOk{replaced(model, with_labels(i, Model.labels_repaired(List.append(&2, String, Model.labels_of(i), label <> Nil{})), now)), "✓ Added label " ++ Render.inline(label) ++ " to " ++ Render.inline(Model.id_of(i)) ++ "\n", row("added", Model.id_of(i), label), Model.id_of(i), True{}}

# S4.375 (spec twin) keep a label that stays
def keep_put(l: String, keep: Bool, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      l <> rest
    case False{}:
      rest

# S4.375 (spec twin) the labels without this one
def without(labels: List<&2, String>, +label: String) -> List<&2, String>:
  match labels:
    case Nil{}:
      Nil{}
    case Con{+l, rest}:
      keep_put(l, Bool.not(String.eq(l, label)), without(rest, label))

# S4.375 S5.184 (spec twin) one pair of `label remove`: a label the issue does not carry is a success no-op, and its
# line carries the glyph too
def remove_pair(+model: List<&2, Model.Issue>, +i: Model.Issue, +label: String, now: Time.Instant, held: Bool) -> Done:
  match held:
    case False{}:
      LabelOk{model, "✓ Label " ++ Render.inline(label) ++ " not found on " ++ Render.inline(Model.id_of(i)) ++ " (no-op)\n", row("not_found", Model.id_of(i), label), Model.id_of(i), False{}}
    case True{}:
      LabelOk{replaced(model, with_labels(i, without(Model.labels_of(i), label), now)), "✓ Removed label " ++ Render.inline(label) ++ " from " ++ Render.inline(Model.id_of(i)) ++ "\n", row("removed", Model.id_of(i), label), Model.id_of(i), True{}}

# S4.373 (spec twin) a tombstoned issue takes no label
def tombstone_refusal(+id: String) -> Failure.Failure:
  Create.invalid("issue_id", "cannot add label to tombstone issue: " ++ id)

# ---------------------------------------------------------------- the batch (S4.371, S4.376)

# S4.371 (data) the pairs processed so far: the refusal, or the model, the lines and rows (both REVERSED), the last
# issue acted on and whether a record changed
type Batch is Data:
  BatchBad{failure: Failure.Failure}
  BatchOk{model: List<&2, Model.Issue>, plain: List<&2, String>, json: List<&2, String>, last: String, changed: Bool}

# S4.371 (spec twin) the model a batch holds; nothing once it was refused
def batch_model(b: Batch) -> List<&2, Model.Issue>:
  match b:
    case BatchBad{f}:
      Nil{}
    case BatchOk{model, plain, json, last, changed}:
      model

# S4.371 (spec twin) one pair's verdict folded into the batch
def batch_put(b: Batch, d: Done) -> Batch:
  match b d:
    case BatchBad{f} _:
      BatchBad{f}
    case BatchOk{model, plain, json, last, changed} LabelBad{f}:
      BatchBad{f}
    case BatchOk{model, plain, json, last, changed} LabelOk{m, line, entry, id, touched}:
      BatchOk{m, line <> plain, entry <> json, id, (changed || touched)}

# S4.373 (spec twin) one (issue, label) pair: a missing record is "not found", a tombstone refuses an add
def pair(+b: Batch, found: Maybe<&2, Model.Issue>, +id: String, +label: String, now: Time.Instant, adding: Bool) -> Batch:
  match found adding:
    case None{} _:
      batch_put(b, LabelBad{Create.invalid("issue_id", "issue not found: " ++ id)})
    case Some{+i} True{}:
      batch_put(b, Bool.pick(Done, String.eq(Model.status_of(i), "tombstone"), LabelBad{tombstone_refusal(Model.id_of(i))}, add_pair(batch_model(b), i, label, now, Blocked.among(Model.labels_of(i), label))))
    case Some{+i} False{}:
      batch_put(b, remove_pair(batch_model(b), i, label, now, Blocked.among(Model.labels_of(i), label)))

# S4.371 (spec twin) one label over every issue: the INNER loop
def inner(ids: List<&2, String>, +b: Batch, +label: String, +now: Time.Instant, +adding: Bool) -> Batch:
  match ids:
    case Nil{}:
      b
    case Con{+id, rest}:
      inner(rest, pair(b, Blocked.lookup(batch_model(b), id), id, label, now, adding), label, now, adding)

# S4.371 (spec twin) every label over every issue: the OUTER loop is the labels, so the rows are label-major
def outer(labels: List<&2, String>, b: Batch, +ids: List<&2, String>, +now: Time.Instant, +adding: Bool) -> Batch:
  match labels:
    case Nil{}:
      b
    case Con{label, rest}:
      outer(rest, inner(ids, b, label, now, adding), ids, now, adding)

# S4.372 (spec twin) `label add` or `label remove`: every label is validated before any issue is touched
def run(model: List<&2, Model.Issue>, +ids: List<&2, String>, +labels: List<&2, String>, now: Time.Instant, adding: Bool, +bad: String) -> Batch:
  match bad:
    case SCon{h, t}:
      BatchBad{label_refusal(SCon{h, t})}
    case SNil{}:
      outer(labels, BatchOk{model, Nil{}, Nil{}, "", False{}}, ids, now, adding)

# ---------------------------------------------------------------- rename (S4.377–S4.379)

# S4.377 (spec twin) the labels of an issue after a rename: the old name becomes the new one, and vanishes when the
# issue already carries the new one (the sort and the de-duplication of the write-back do the rest)
def renamed_labels(labels: List<&2, String>, +old: String, +new: String) -> List<&2, String>:
  match labels:
    case Nil{}:
      Nil{}
    case Con{+l, rest}:
      Bool.pick(String, String.eq(l, old), new, l) <> renamed_labels(rest, old, new)

# S4.377 (spec twin) one issue under a rename: only a non-tombstoned issue that carries the old name is rewritten
def rename_one(+i: Model.Issue, +old: String, new: String, now: Time.Instant, carries: Bool) -> Model.Issue:
  match carries:
    case False{}:
      i
    case True{}:
      with_labels(i, Model.labels_repaired(renamed_labels(Model.labels_of(i), old, new)), now)

# S4.377 (spec twin) every issue under a rename
def renamed(issues: List<&2, Model.Issue>, +old: String, +new: String, +now: Time.Instant) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      rename_one(i, old, new, now, (Blocked.among(Model.labels_of(i), old) && Bool.not(String.eq(Model.status_of(i), "tombstone")))) <> renamed(rest, old, new, now)

# S4.379 (spec twin) how many issues the rename touches: those that carry the old name and are not tombstoned
def affected(issues: List<&2, Model.Issue>, +old: String, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{+i, rest}:
      affected(rest, old, (acc + Bool.to_u32((Blocked.among(Model.labels_of(i), old) && Bool.not(String.eq(Model.status_of(i), "tombstone")))) : U32))

# S5.50 (spec twin) the three-member payload of `label rename --json`
def rename_json(+old: String, +new: String, +count: U32) -> String:
  "{\"old_name\":" ++ Failure.quoted(old) ++ ",\"new_name\":" ++ Failure.quoted(new) ++ ",\"affected_issues\":" ++ U32.show(count) ++ "}\n"

# S4.378 S5.189 (spec twin) a rename nobody carries writes nothing; otherwise every carrier is rewritten
def rename_done(+model: List<&2, Model.Issue>, +old: String, +new: String, +now: Time.Instant, +count: U32, none: Bool) -> Done:
  match none:
    case True{}:
      LabelOk{model, "Label '" ++ Render.inline(old) ++ "' not found on any issues.\n", rename_json(old, new, 0), "", False{}}
    case False{}:
      LabelOk{renamed(model, old, new, now), "✓ Renamed label '" ++ Render.inline(old) ++ "' to '" ++ Render.inline(new) ++ "' on " ++ U32.show(count) ++ Bool.pick(String, U32.is_eq(count, 1), " issue\n", " issues\n"), rename_json(old, new, count), "", True{}}

# S4.377 S4.378 S5.50 S5.189 S5.190 (spec twin) `label rename`: the same name and a name nobody carries are success
# no-ops; `.beads/last-touched` is never written by this command
def rename(+model: List<&2, Model.Issue>, +old: String, +new: String, now: Time.Instant, same: Bool, +count: U32) -> Done:
  match same:
    case True{}:
      LabelOk{model, "Label '" ++ Render.inline(old) ++ "' already has that name; no changes made.\n", rename_json(old, new, 0), "", False{}}
    case False{}:
      rename_done(model, old, new, now, count, U32.is_eq(count, 0))

# ---------------------------------------------------------------- comments add (S4.380–S4.385)

# S4.380 (spec twin) the issue with one more comment and `updated_at` bumped
def with_comment(i: Model.Issue, c: Model.Comment, now: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, x, d, e, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, now, x, d, e, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, List.append(&2, Model.Comment, comments, c <> Nil{})}

# S5.51 (spec twin) the comment object, the five members in the order of S5.15
def comment_json(c: Model.Comment) -> String:
  match c:
    case Model.Comment{id, issue_id, author, text, created_at}:
      String.concat(["{\"id\":", id, ",\"issue_id\":", Failure.quoted(issue_id), ",\"author\":", Failure.quoted(author), ",\"text\":", Failure.quoted(text), ",\"created_at\":", Failure.quoted(Time.print(created_at, "Z")), "}\n"])

# S4.380 (spec twin) the comment appended
def comment_made(+model: List<&2, Model.Issue>, +i: Model.Issue, +c: Model.Comment, now: Time.Instant) -> Done:
  LabelOk{replaced(model, with_comment(i, c, now)), "Comment added to " ++ Render.inline(Model.id_of(i)) ++ "\n", comment_json(c), Model.id_of(i), True{}}

# S4.380–S4.384 (spec twin) `comments add`: the text must not be empty; the comment's id is one past the store-wide
# greatest (S4.382); the issue's `updated_at` is bumped and `.beads/last-touched` names it
def comment(+model: List<&2, Model.Issue>, +i: Model.Issue, +author: String, +text: String, +now: Time.Instant, empty: Bool) -> Done:
  match empty:
    case True{}:
      LabelBad{Create.invalid("text", "comment text cannot be empty")}
    case False{}:
      comment_made(model, i, Model.Comment{Status.next_comment_id(model), Model.id_of(i), author, text, now}, now)

