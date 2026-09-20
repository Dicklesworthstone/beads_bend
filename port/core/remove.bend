# core/remove — `delete`: a soft delete that tombstones (S4.330–S4.341, S5.44).
# The named ids are deduplicated and sorted ascending before resolution
# (S4.340), so the command line's order never reaches the output. Dependents
# that neither `--force` nor `--cascade` accounts for turn the run into a
# PREVIEW that writes nothing. Every edge touching a deleted id is removed
# from both ends, then the tombstones are written.
# Not here yet, each refused with the port's own failure by the dispatcher:
# `--hard` (a purge) and `--from-file`. Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./blocked.bend as Blocked
import ./render.bend as Render

# S4.330 (spec twin) the record as a tombstone: the status, the instant, the actor, the reason and the type the
# issue had; `issue_type` itself, the title, the priority and the labels are left alone
def tombstoned(i: Model.Issue, +now: Time.Instant, actor: String, reason: String) -> Model.Issue:
  match i:
    case Model.Issue{Model.Head{id, title, status, priority, kind}, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, defer_until, deleted_at, compacted_at}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, "tombstone", priority, kind}, texts, people, Model.Times{created_at, now, closed_at, due_at, defer_until, Some{now}, compacted_at}, closing, source, Model.Deletion{Some{actor}, Some{reason}, Some{kind}}, compaction, meta, flags, labels, dependencies, comments}

# S4.331 (spec twin) the edges of one issue that point at none of the deleted ids
def edges_without(edges: List<&2, Model.Dependency>, +ids: List<&2, String>) -> List<&2, Model.Dependency>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      edge_put(e, Blocked.among(ids, Model.target_of(e)), edges_without(rest, ids))

# S4.331 (spec twin) keep an edge whose target survives
def edge_put(e: Model.Dependency, drop: Bool, rest: List<&2, Model.Dependency>) -> List<&2, Model.Dependency>:
  match drop:
    case True{}:
      rest
    case False{}:
      e <> rest

# S4.336 (spec twin) how many edges of one issue touch a deleted id, from either end
def touching(edges: List<&2, Model.Dependency>, +mine: Bool, +ids: List<&2, String>, acc: U32) -> U32:
  match edges:
    case Nil{}:
      acc
    case Con{+e, rest}:
      touching(rest, mine, ids, (acc + Bool.to_u32((mine || Blocked.among(ids, Model.target_of(e)))) : U32))

# S4.336 (spec twin) every edge of the store that touches a deleted id, counted once
def links_removed(issues: List<&2, Model.Issue>, +ids: List<&2, String>, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{+i, rest}:
      links_removed(rest, ids, touching(Model.deps_of(i), Blocked.among(ids, Model.id_of(i)), ids, acc))

# S4.330 S4.331 (spec twin) one record after the delete: a deleted id becomes a tombstone without edges, another
# issue loses its edges to deleted ids (and has its `updated_at` bumped only when it lost one)
def applied_one(+i: Model.Issue, +ids: List<&2, String>, now: Time.Instant, actor: String, reason: String, +kept: List<&2, Model.Dependency>) -> Model.Issue:
  Bool.pick(Model.Issue, Blocked.among(ids, Model.id_of(i)), tombstoned(without_edges(i), now, actor, reason), Bool.pick(Model.Issue, Nat.is_eq(List.length(&2, Model.Dependency, kept), List.length(&2, Model.Dependency, Model.deps_of(i))), i, bumped(with_edges(i, kept), now)))

# S4.331 (spec twin) an issue without its own edges
def without_edges(i: Model.Issue) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, Nil{}, comments}

# S4.331 (spec twin) an issue with these edges
def with_edges(i: Model.Issue, edges: List<&2, Model.Dependency>) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, edges, comments}

# S4.331 (spec twin) `updated_at` becomes the invocation instant
def bumped(i: Model.Issue, now: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, c, d, e, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, now, c, d, e, f, g}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}

# S4.330 S4.331 (spec twin) the model after the delete
def applied(issues: List<&2, Model.Issue>, +ids: List<&2, String>, +now: Time.Instant, +actor: String, +reason: String) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      applied_one(i, ids, now, actor, reason, edges_without(Model.deps_of(i), ids)) <> applied(rest, ids, now, actor, reason)

# ---------------------------------------------------------------- dependents (S4.332)

# S4.332 (spec twin) does one issue depend on a deleted id: it has a BLOCKING edge pointing at one
def depends_on(edges: List<&2, Model.Dependency>, +ids: List<&2, String>) -> Bool:
  match edges:
    case Nil{}:
      False{}
    case Con{+e, rest}:
      ((Blocked.blocking(Model.dep_type_of(e)) && Blocked.among(ids, Model.target_of(e))) || depends_on(rest, ids))

# S4.332 (spec twin) the parents named by the `parent-child` edges of a deleted id
def parents_of(edges: List<&2, Model.Dependency>, +mine: Bool) -> List<&2, String>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      word_put(Model.target_of(e), Bool.not((mine && String.eq(Model.dep_type_of(e), "parent-child"))), parents_of(rest, mine))

# S4.332 (spec twin) keep a word unless it is to be dropped
def word_put(word: String, drop: Bool, rest: List<&2, String>) -> List<&2, String>:
  match drop:
    case True{}:
      rest
    case False{}:
      word <> rest

# S4.332 (spec twin) the ids that depend on the deleted set: every issue with a blocking edge into it, plus the
# parent of every deleted child; the deleted ids themselves are excluded
def dependents_go(issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> List<&2, String>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      List.append(&2, String, word_put(Model.id_of(i), Bool.not((depends_on(Model.deps_of(i), ids) && Bool.not(Blocked.among(ids, Model.id_of(i))))), parents_of(Model.deps_of(i), Blocked.among(ids, Model.id_of(i)))), dependents_go(rest, ids))

# S4.332 (spec twin) the ids that depend on the deleted set, sorted, de-duplicated, and without the deleted ids
def dependents(+issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> List<&2, String>:
  Model.dedup(List.sort(~String, ~String.is_le, drop_known(dependents_go(issues, ids), ids)))

# S4.332 (spec twin) drop the ids that are already in the delete set
def drop_known(words: List<&2, String>, +ids: List<&2, String>) -> List<&2, String>:
  match words:
    case Nil{}:
      Nil{}
    case Con{+w, rest}:
      word_put(w, Blocked.among(ids, w), drop_known(rest, ids))

# S4.335 (spec twin) the transitive closure of the dependent relation, from the named ids; one unit of fuel per round
def closure(fuel: Nat, +issues: List<&2, Model.Issue>, +ids: List<&2, String>) -> List<&2, String>:
  match fuel:
    case 0n:
      ids
    case 1n+g:
      closure_step(g, issues, ids, dependents(issues, ids))
