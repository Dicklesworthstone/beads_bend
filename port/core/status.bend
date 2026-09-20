# core/status — `close`, `reopen`, `defer`, `undefer`: status transitions over a batch of ids
# (S4.290–S4.300, S4.310–S4.315, S4.320–S4.326, S5.40–S5.43).
# Every id is judged against the store as it was BEFORE the batch (S4.290: the
# precondition pass comes first), a precondition that fails is a per-id SKIP
# and the batch goes on (S4.213), and the survivors are written back once.
# Not here yet, each refused with the port's own failure by the dispatcher:
# `--transition-comment`, `--session`, `--bypass-policy`, the dot-notation
# child check of `close` (S4.292). Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./blocked.bend as Blocked
import ./work.bend as Work
import ./render.bend as Render

# S4.213 (data) one skipped id and its reason
type Skip is Data:
  Skip{id: String, reason: String}

# S4.213 (data) what happened to one id: skipped with a reason, or acted on, with the issue afterwards, its plain
# success line and its JSON element
type Verdict is Data:
  Skipped{reason: String}
  Acted{issue: Model.Issue, plain: String, json: String}

# S4.291 S4.311 S4.321 S4.325 (spec twin) an issue with its status and the members a transition owns rewritten:
# `closed_at`, `close_reason`, `defer_until`; `deleted` false also clears the deletion members (reopen, S4.311)
def moved(i: Model.Issue, status: String, now: Time.Instant, closed_at: Maybe<&2, Time.Instant>, reason: Maybe<&2, String>, defer_until: Maybe<&2, Time.Instant>, keep_deleted: Bool) -> Model.Issue:
  match i keep_deleted:
    case Model.Issue{Model.Head{id, title, old, priority, kind}, texts, people, Model.Times{created_at, updated_at, c, due_at, d, deleted_at, compacted_at}, Model.Closing{r, session, bypassed, bypass_reason, gates}, source, deletion, compaction, meta, flags, labels, dependencies, comments} True{}:
      Model.Issue{Model.Head{id, title, status, priority, kind}, texts, people, Model.Times{created_at, now, closed_at, due_at, defer_until, deleted_at, compacted_at}, Model.Closing{reason, session, bypassed, bypass_reason, gates}, source, deletion, compaction, meta, flags, labels, dependencies, comments}
    case Model.Issue{Model.Head{id, title, old, priority, kind}, texts, people, Model.Times{created_at, updated_at, c, due_at, d, deleted_at, compacted_at}, Model.Closing{r, session, bypassed, bypass_reason, gates}, source, Model.Deletion{deleted_by, delete_reason, original_type}, compaction, meta, flags, labels, dependencies, comments} False{}:
      Model.Issue{Model.Head{id, title, status, priority, kind}, texts, people, Model.Times{created_at, now, closed_at, due_at, defer_until, None{}, compacted_at}, Model.Closing{reason, None{}, bypassed, bypass_reason, gates}, source, Model.Deletion{None{}, None{}, original_type}, compaction, meta, flags, labels, dependencies, comments}

# S5.41 (spec twin) an instant as the `close` and `defer` payloads spell it: `+00:00`, not `Z`
def offset_text(at: Time.Instant) -> String:
  Time.print(at, "+00:00")

# ---------------------------------------------------------------- close (S4.290–S4.298)

# S4.292 (spec twin) keep a blocker id unless its ref is one `close` does not name
def blocker_put(id: String, drop: Bool, rest: List<&2, String>) -> List<&2, String>:
  match drop:
    case True{}:
      rest
    case False{}:
      id <> rest

# S4.164 S4.165 S4.292 (spec twin) the blockers `close` names: the blocker refs without the parent propagation and
# without the epic rollup (open children have their own reason), as ids
def close_blockers(refs: List<&2, String>) -> List<&2, String>:
  match refs:
    case Nil{}:
      Nil{}
    case Con{+r, rest}:
      blocker_put(Blocked.ref_id(r), (String.ends_with(r, ":child-open") || String.ends_with(r, ":parent-blocked")), close_blockers(rest))

# S4.292 (spec twin) the open-children reason: `epic` or `parent issue`, then `<open>/<total> open children`
def children_reason(epic: Bool, +total: U32, done: U32) -> String:
  Bool.pick(String, epic, "epic", "parent issue") ++ " has " ++ U32.show((total - done : U32)) ++ "/" ++ U32.show(total) ++ " open children (use --force to close anyway)"

# S4.292 (spec twin) the blocked reason
def blocked_reason(blockers: List<&2, String>) -> String:
  "blocked by: " ++ String.join(blockers, ", ") ++ " — close the open blocker(s) first, or use --force to close anyway"

# S4.291 S4.298 (spec twin) a closed issue with its success line and its JSON element (`closed_at` with `+00:00`)
def closed_verdict(+i: Model.Issue, +now: Time.Instant, +reason: String) -> Verdict:
  Acted{moved(i, "closed", now, Some{now}, Some{reason}, Model.defer_of(i), True{}), "✓ Closed " ++ Render.inline(Model.id_of(i)) ++ ": " ++ Render.inline(Model.title_of(i)) ++ " (" ++ Render.inline(reason) ++ ")\n", String.concat(["{\"id\":", Failure.quoted(Model.id_of(i)), ",\"title\":", Failure.quoted(Model.title_of(i)), ",\"status\":\"closed\",\"closed_at\":", Failure.quoted(offset_text(now)), ",\"close_reason\":", Failure.quoted(reason), "}"])}

# S4.292 (spec twin) the open-children reason from the child counts
def children_words(epic: Bool, c: Work.Children) -> String:
  match c:
    case Work.Children{total, done}:
      children_reason(epic, total, done)

# S4.292 (spec twin) does an issue have a child that is not closed
def children_open(c: Work.Children) -> Bool:
  match c:
    case Work.Children{total, done}:
      (total > done : U32)

# S4.292 S4.296 (spec twin) the preconditions of one close, in order: a terminal status; open children; open
# blockers. `--force` waives the last two and nothing else
def close_pick(+i: Model.Issue, now: Time.Instant, reason: String, terminal: Bool, force: Bool, kids: Bool, +c: Work.Children, +blockers: List<&2, String>) -> Verdict:
  match terminal force kids:
    case True{} _ _:
      Skipped{"already " ++ Model.status_of(i)}
    case False{} True{} _:
      closed_verdict(i, now, reason)
    case False{} False{} True{}:
      Skipped{children_words(String.eq(Model.type_of(i), "epic"), c)}
    case False{} False{} False{}:
      Bool.pick(Verdict, List.is_empty(&2, String, blockers), closed_verdict(i, now, reason), Skipped{blocked_reason(blockers)})

# S4.292 (spec twin) one close with its child counts and blockers known
def close_counted(+i: Model.Issue, +c: Work.Children, blockers: List<&2, String>, now: Time.Instant, reason: String, force: Bool) -> Verdict:
  close_pick(i, now, reason, Blocked.terminal(Model.status_of(i)), force, children_open(c), c, blockers)

# S4.290–S4.296 (spec twin) one id of `close`, judged against the store as it was before the batch
def close_one(+i: Model.Issue, +all: List<&2, Model.Issue>, relation: List<&2, Blocked.Entry>, now: Time.Instant, reason: String, force: Bool) -> Verdict:
  close_counted(i, Work.children(all, Model.id_of(i), Work.Children{0, 0}), close_blockers(Blocked.refs_of(relation, Model.id_of(i))), now, reason, force)

# ---------------------------------------------------------------- reopen (S4.310–S4.315)

# S4.312 (spec twin) an issue with one more comment at the end of its own array
def with_comment(i: Model.Issue, c: Model.Comment) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, List.append(&2, Model.Comment, comments, c <> Nil{})}

# S4.312 (spec twin) `--reason` is stored as a COMMENT `Reopened: <reason>` by the actor at the invocation instant
def reopen_noted(+i: Model.Issue, reason: Maybe<&2, String>, actor: String, now: Time.Instant, comment_id: String) -> Model.Issue:
  match reason:
    case None{}:
      i
    case Some{text}:
      with_comment(i, Model.Comment{comment_id, Model.id_of(i), actor, "Reopened: " ++ text, now})

# S4.314 (spec twin) the suffix of the success line: ` (<reason>)` when a reason was given
def reason_suffix(reason: Maybe<&2, String>) -> String:
  match reason:
    case None{}:
      ""
    case Some{text}:
      " (" ++ Render.inline(text) ++ ")"

# S4.311–S4.314 (spec twin) one id of `reopen`: only a `closed` issue reopens, to plain `open`, with every closing,
# deferral and deletion member cleared; anything else is a skip
def reopen_one(+i: Model.Issue, +now: Time.Instant, +reason: Maybe<&2, String>, actor: String, comment_id: String) -> Verdict:
  Bool.pick(Verdict, String.eq(Model.status_of(i), "closed"), Acted{reopen_noted(moved(i, "open", now, None{}, None{}, None{}, False{}), reason, actor, now, comment_id), "✓ Reopened " ++ Render.inline(Model.id_of(i)) ++ ": " ++ Render.inline(Model.title_of(i)) ++ reason_suffix(reason) ++ "\n", String.concat(["{\"id\":", Failure.quoted(Model.id_of(i)), ",\"title\":", Failure.quoted(Model.title_of(i)), ",\"status\":\"open\"}"])}, Skipped{Bool.pick(String, String.eq(Model.status_of(i), "tombstone"), "cannot reopen tombstone issue", "already " ++ Model.status_of(i))})

# ---------------------------------------------------------------- defer and undefer (S4.320–S4.326)

# S4.326 (spec twin) are two optional instants the same
def same_gate(a: Maybe<&2, Time.Instant>, b: Maybe<&2, Time.Instant>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{x} Some{y}:
      Time.eq(x, y)
    case _ _:
      False{}

# S4.323 S5.43 (spec twin) the deferral as the plain line names it
def until_words(until: Maybe<&2, Time.Instant>) -> String:
  match until:
    case None{}:
      " (indefinitely)"
    case Some{at}:
      " (until " ++ offset_text(at) ++ ")"

# S5.43 (spec twin) `defer_until` in the JSON element, omitted when the deferral is indefinite
def until_member(until: Maybe<&2, Time.Instant>) -> String:
  match until:
    case None{}:
      ""
    case Some{at}:
      ",\"defer_until\":" ++ Failure.quoted(offset_text(at))

# S4.321 S4.323 S4.326 (spec twin) one id of `defer`: a terminal issue cannot be deferred; one already deferred to the
# same gate is a skip; anything else becomes `deferred` with the gate set, or cleared when none was given
def defer_one(+i: Model.Issue, now: Time.Instant, +until: Maybe<&2, Time.Instant>) -> Verdict:
  Bool.pick(Verdict, Blocked.terminal(Model.status_of(i)), Skipped{"cannot defer " ++ Model.status_of(i) ++ " issue"}, Bool.pick(Verdict, (String.eq(Model.status_of(i), "deferred") && same_gate(Model.defer_of(i), until)), Skipped{"already deferred"}, Acted{moved(i, "deferred", now, Model.closed_of(i), Model.close_reason_of(i), until, True{}), "⏱ Deferred " ++ Render.inline(Model.id_of(i)) ++ ": " ++ Render.inline(Model.title_of(i)) ++ until_words(until) ++ "\n", String.concat(["{\"id\":", Failure.quoted(Model.id_of(i)), ",\"title\":", Failure.quoted(Model.title_of(i)), ",\"previous_status\":", Failure.quoted(Model.status_of(i)), ",\"status\":\"deferred\"", until_member(until), "}"])}))

# S4.325 (spec twin) the status after an undefer: `open` when it was `deferred`, unchanged otherwise
def undeferred_status(+status: String) -> String:
  Bool.pick(String, String.eq(status, "deferred"), "open", status)

# S4.325 S4.326 (spec twin) one id of `undefer`: a terminal issue is refused; an issue that is neither `deferred` nor
# carries a gate is a skip; anything else loses its gate, and a `deferred` one becomes `open`
def undefer_one(+i: Model.Issue, now: Time.Instant) -> Verdict:
  Bool.pick(Verdict, Blocked.terminal(Model.status_of(i)), Skipped{"cannot undefer " ++ Model.status_of(i) ++ " issue"}, Bool.pick(Verdict, (Bool.not(String.eq(Model.status_of(i), "deferred")) && Maybe.is_none(&2, Time.Instant, Model.defer_of(i))), Skipped{"not deferred (status: " ++ Model.status_of(i) ++ ")"}, Acted{moved(i, undeferred_status(Model.status_of(i)), now, Model.closed_of(i), Model.close_reason_of(i), None{}, True{}), "✓ Undeferred " ++ Render.inline(Model.id_of(i)) ++ ": " ++ Render.inline(Model.title_of(i)) ++ " (now " ++ undeferred_status(Model.status_of(i)) ++ ")\n", String.concat(["{\"id\":", Failure.quoted(Model.id_of(i)), ",\"title\":", Failure.quoted(Model.title_of(i)), ",\"previous_status\":", Failure.quoted(Model.status_of(i)), ",\"status\":", Failure.quoted(undeferred_status(Model.status_of(i))), "}"])}))

# ---------------------------------------------------------------- the batch (S4.213, S4.299)

# S4.213 S4.299 (data) a batch so far: the model with the survivors in it, the success lines and JSON elements (both
# REVERSED), the skips (REVERSED), and the last id acted on ("" when none)
type Batch is Data:
  Batch{model: List<&2, Model.Issue>, plain: List<&2, String>, json: List<&2, String>, skips: List<&2, Skip>, last: String}

# S4.299 (spec twin) the model with one issue replaced by its new self
def replaced(model: List<&2, Model.Issue>, +new: Model.Issue) -> List<&2, Model.Issue>:
  match model:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      Bool.pick(Model.Issue, String.eq(Model.id_of(i), Model.id_of(new)), new, i) <> replaced(rest, new)

# S4.208 S4.213 (spec twin) one verdict folded into the batch: a skip joins the skips and is NOT the last-touched id
def settle(b: Batch, id: String, v: Verdict) -> Batch:
  match b v:
    case Batch{model, plain, json, skips, last} Skipped{reason}:
      Batch{model, plain, json, Skip{id, reason} <> skips, last}
    case Batch{model, plain, json, skips, last} Acted{+issue, line, element}:
      Batch{replaced(model, issue), line <> plain, element <> json, skips, Model.id_of(issue)}

# S4.299 (spec twin) the model a batch holds
def model_of(b: Batch) -> List<&2, Model.Issue>:
  match b:
    case Batch{model, plain, json, skips, last}:
      model

# S4.382 (spec twin) the greatest comment id among some comments
def max_comment(cs: List<&2, Model.Comment>, acc: U32) -> U32:
  match cs:
    case Nil{}:
      acc
    case Con{Model.Comment{id, issue_id, author, text, created_at}, rest}:
      max_comment(rest, U32.max(acc, Maybe.default(&2, U32, U32.read(id), 0)))

# S4.382 (spec twin) the greatest comment id of the whole store
def max_comment_id(issues: List<&2, Model.Issue>, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{i, rest}:
      max_comment_id(rest, max_comment(Model.comments_of(i), acc))

# S4.382 (spec twin) the id of the next comment: one past the store-wide greatest
def next_comment_id(issues: List<&2, Model.Issue>) -> String:
  U32.show((max_comment_id(issues, 0) + 1 : U32))

# S4.292 (spec twin) one id of `close` folded in; a record that is missing is the skip `issue not found`
def close_step(b: Batch, +id: String, found: Maybe<&2, Model.Issue>, all: List<&2, Model.Issue>, relation: List<&2, Blocked.Entry>, now: Time.Instant, reason: String, force: Bool) -> Batch:
  match found:
    case None{}:
      settle(b, id, Skipped{"issue not found"})
    case Some{i}:
      settle(b, id, close_one(i, all, relation, now, reason, force))

# S4.299 (spec twin) `close` over resolved ids, in command-line order; `all` and `relation` are the store before the batch
def close_go(ids: List<&2, String>, b: Batch, +all: List<&2, Model.Issue>, +relation: List<&2, Blocked.Entry>, +now: Time.Instant, +reason: String, +force: Bool) -> Batch:
  match ids:
    case Nil{}:
      b
    case Con{+id, rest}:
      close_go(rest, close_step(b, id, Blocked.lookup(all, id), all, relation, now, reason, force), all, relation, now, reason, force)

# S4.313 (spec twin) one id of `reopen` folded in; the comment id comes from the batch's model as it stands
def reopen_step(+b: Batch, +id: String, found: Maybe<&2, Model.Issue>, now: Time.Instant, reason: Maybe<&2, String>, actor: String) -> Batch:
  match found:
    case None{}:
      settle(b, id, Skipped{"issue not found"})
    case Some{i}:
      settle(b, id, reopen_one(i, now, reason, actor, next_comment_id(model_of(b))))

# S4.315 (spec twin) `reopen` over resolved ids
def reopen_go(ids: List<&2, String>, b: Batch, +all: List<&2, Model.Issue>, +now: Time.Instant, +reason: Maybe<&2, String>, +actor: String) -> Batch:
  match ids:
    case Nil{}:
      b
    case Con{+id, rest}:
      reopen_go(rest, reopen_step(b, id, Blocked.lookup(all, id), now, reason, actor), all, now, reason, actor)

# S4.326 (spec twin) one id of `defer` (`deferring` true) or `undefer` folded in
def gate_step(b: Batch, +id: String, found: Maybe<&2, Model.Issue>, now: Time.Instant, until: Maybe<&2, Time.Instant>, deferring: Bool) -> Batch:
  match found deferring:
    case None{} _:
      settle(b, id, Skipped{"issue not found"})
    case Some{i} True{}:
      settle(b, id, defer_one(i, now, until))
    case Some{i} False{}:
      settle(b, id, undefer_one(i, now))

# S4.321 S4.325 (spec twin) `defer` or `undefer` over resolved ids
def gate_go(ids: List<&2, String>, b: Batch, +all: List<&2, Model.Issue>, +now: Time.Instant, +until: Maybe<&2, Time.Instant>, +deferring: Bool) -> Batch:
  match ids:
    case Nil{}:
      b
    case Con{+id, rest}:
      gate_go(rest, gate_step(b, id, Blocked.lookup(all, id), now, until, deferring), all, now, until, deferring)

# S4.293 (spec twin) the skips as the summary names them: up to five `<id>: <reason>` joined by `; `, then `+<n> more`
def summary_go(skips: List<&2, Skip>, left: Nat) -> List<&2, String>:
  match skips left:
    case Nil{} _:
      Nil{}
    case Con{s, rest} 0n:
      Nil{}
    case Con{Skip{id, reason}, rest} 1n+k:
      (id ++ ": " ++ reason) <> summary_go(rest, k)

# S4.293 (spec twin) the summary of some skips, in command-line order
def summary(+skips: List<&2, Skip>) -> String:
  String.join(summary_go(skips, 5n), "; ") ++ Bool.pick(String, Nat.is_gt(List.length(&2, Skip, skips), 5n), "; +" ++ Nat.show(Nat.sub(List.length(&2, Skip, skips), 5n)) ++ " more", "")

# S4.295 (spec twin) the hint of a `close` that skipped something, chosen by what the summary contains
def skip_hint(+text: String) -> String:
  Bool.pick(String, String.contains(text, "blocked by"), "Skipped issue(s) have open blocking dependencies. Close the blockers first, or re-run with --force to close anyway.", Bool.pick(String, (String.contains(text, "open children") || String.contains(text, "child issue")), "Skipped issue(s) have open children. Close the children first, or re-run with --force to close anyway.", "Skipped issue(s) were already closed or not found."))

# S4.293 S9.12 (spec twin) every id of a `close` was skipped
def nothing_to_do(+skips: List<&2, Skip>) -> Failure.Failure:
  Failure.Failure{"NOTHING_TO_DO", "Nothing to do: all " ++ Nat.show(List.length(&2, Skip, skips)) ++ " issue(s) skipped — " ++ summary(skips), Some{skip_hint(summary(skips))}, False{}, [Failure.CtxMember{"reason", Failure.CStr{"all " ++ Nat.show(List.length(&2, Skip, skips)) ++ " issue(s) skipped — " ++ summary(skips)}}], 3}

# S4.294 S9.14 (spec twin) some ids of a `close` landed and some were skipped: the closures are written, then this failure
def close_incomplete(+closed: Nat, +skips: List<&2, Skip>) -> Failure.Failure:
  Failure.Failure{"CLOSE_INCOMPLETE", "Partially applied: " ++ Nat.show(closed) ++ " closed, " ++ Nat.show(List.length(&2, Skip, skips)) ++ " skipped — " ++ summary(skips), Some{skip_hint(summary(skips))}, False{}, [Failure.CtxMember{"closed", Failure.CBare{Nat.show(closed)}}, Failure.CtxMember{"skipped", Failure.CBare{Nat.show(List.length(&2, Skip, skips))}}, Failure.CtxMember{"summary", Failure.CStr{summary(skips)}}], 3}

# S4.292 S4.313 (spec twin) the skips as warnings for stderr (`close`) …
def warning_lines(skips: List<&2, Skip>) -> List<&2, String>:
  match skips:
    case Nil{}:
      Nil{}
    case Con{Skip{id, reason}, rest}:
      ("Warning: Skipped " ++ Render.inline(id) ++ ": " ++ reason ++ "\n") <> warning_lines(rest)

# S4.313 S4.326 (spec twin) … and as `⊘ Skipped` lines for stdout (`reopen`, `defer`, `undefer`)
def skip_lines(skips: List<&2, Skip>) -> List<&2, String>:
  match skips:
    case Nil{}:
      Nil{}
    case Con{Skip{id, reason}, rest}:
      ("⊘ Skipped " ++ Render.inline(id) ++ ": " ++ reason ++ "\n") <> skip_lines(rest)

# S5.40 (spec twin) the skips as JSON objects `{"id":…,"reason":…}`, separated by `,`
def skip_objects(skips: List<&2, Skip>, first: Bool) -> List<&2, String>:
  match skips first:
    case Nil{} _:
      Nil{}
    case Con{Skip{id, reason}, rest} lead:
      String.concat([Bool.pick(String, lead, "", ","), "{\"id\":", Failure.quoted(id), ",\"reason\":", Failure.quoted(reason), "}"]) <> skip_objects(rest, False{})

# ---------------------------------------------------------------- epic close-eligible (S4.390, S4.391)

# S4.391 (spec twin) an eligible epic as `epic close-eligible` closes it: the close reason is the hard-coded
# literal `All children completed`, never a `--reason` (the subcommand has none)
def epic_closed(+i: Model.Issue, +now: Time.Instant) -> Model.Issue:
  moved(i, "closed", now, Some{now}, Some{"All children completed"}, Model.defer_of(i), True{})

# S4.391 (spec twin) every named epic closed in ONE batch, with one shared instant
def epics_closed(issues: List<&2, Model.Issue>, +ids: List<&2, String>, +now: Time.Instant) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      Bool.pick(Model.Issue, Blocked.among(ids, Model.id_of(i)), epic_closed(i, now), i) <> epics_closed(rest, ids, now)
