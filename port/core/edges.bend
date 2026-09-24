# core/edges — `dep add` and `dep remove` (S4.350–S4.363, S5.45).
# One edge at a time, written into the DEPENDENT issue's own array. The
# checks run in the order of S4.353, and only the blocking edge types take
# part in the cycle check, with `parent-child` inverted (a stored row is
# child → parent, the blocker edge is parent → child, S4.354).
# Not here yet, refused with the port's own failure by the dispatcher:
# `--metadata` (it must be valid JSON, S4.350). Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./blocked.bend as Blocked
import ./create.bend as Create
import ./render.bend as Render
import ./json.bend as Json
import ./resolve.bend as Resolve

# S4.350–S4.363 (data) what one edge command answered: the refusal, or the model to write (unchanged on a no-op),
# the plain text, the JSON payload, and the dependent's id for `.beads/last-touched`
type Done is Data:
  EdgeBad{failure: Failure.Failure}
  EdgeOk{model: List<&2, Model.Issue>, plain: String, json: String, last: String, changed: Bool}

# S4.352 (spec twin) the canonical spelling of a `--type`, matched without regard to ASCII case; "" when it is none
# of the eleven
def canonical(+word: String) -> String:
  Bool.pick(String, Model.listed_word(Model.known_dep_types(), Model.lowered(word)), Model.lowered(word), "")

# S4.352 (spec twin) `_` and a space read as `-` when a near match is sought
def dash_char(+c: U32) -> U32:
  Bool.pick(U32, (U32.is_eq(c, 95) || U32.is_eq(c, 32)), 45, c)

# S4.352 (spec twin) a word with `_` and spaces turned into `-`
def dashed(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{dash_char(c)}, dashed(rest)}

# S4.352 (spec twin) the least of three counts
def least3(+a: Nat, +b: Nat, +c: Nat) -> Nat:
  Bool.pick(Nat, Nat.is_lt(a, b), Bool.pick(Nat, Nat.is_lt(a, c), a, c), Bool.pick(Nat, Nat.is_lt(b, c), b, c))

# S4.352 (spec twin) one row of the edit-distance table for the code point `ca` of the word: `up` is the row above
# from this column on, `diag` the cell above-left, `left` the cell just computed
def lev_next(+ca: U32, b: List<&2, U32>, +diag: Nat, up: List<&2, Nat>, +left: Nat) -> List<&2, Nat>:
  match b up:
    case Nil{} _:
      Nil{}
    case Con{+cb, brest} Nil{}:
      Nil{}
    case Con{+cb, brest} Con{+u, urest}:
      least3(Nat.add(u, 1n), Nat.add(left, 1n), Nat.add(diag, Bool.pick(Nat, U32.is_eq(ca, cb), 0n, 1n))) <> lev_next(ca, brest, u, urest, least3(Nat.add(u, 1n), Nat.add(left, 1n), Nat.add(diag, Bool.pick(Nat, U32.is_eq(ca, cb), 0n, 1n))))

# S4.352 (spec twin) the next row, from the one above
def lev_row(+ca: U32, +b: List<&2, U32>, prev: List<&2, Nat>, +i: Nat) -> List<&2, Nat>:
  match prev:
    case Nil{}:
      i <> Nil{}
    case Con{p0, rest}:
      i <> lev_next(ca, b, p0, rest, i)

# S4.352 (spec twin) every row, one per code point of the word; the last row's last cell is the distance
def lev_rows(a: List<&2, U32>, +b: List<&2, U32>, prev: List<&2, Nat>, +i: Nat) -> List<&2, Nat>:
  match a:
    case Nil{}:
      prev
    case Con{ca, rest}:
      lev_rows(rest, b, lev_row(ca, b, prev, Nat.add(i, 1n)), Nat.add(i, 1n))

# S4.352 (spec twin) the first row: 0, 1, …, the length of the type
def lev_first(b: List<&2, U32>, +i: Nat) -> List<&2, Nat>:
  match b:
    case Nil{}:
      i <> Nil{}
    case Con{c, rest}:
      i <> lev_first(rest, Nat.add(i, 1n))

# S4.352 (spec twin) the edit distance (insertions, deletions, substitutions of code points) between two words
def distance(+a: String, +b: String) -> Nat:
  Maybe.default(&2, Nat, List.last(&2, Nat, lev_rows(Time.codes(a), Time.codes(b), lev_first(Time.codes(b), 0n), 0n)), 0n)

# S4.352 (spec twin) keep a type in front of the rest
def type_keep(t: String, keep: Bool, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      t <> rest
    case False{}:
      rest

# S4.352 (spec twin) the types a word is a prefix of
def prefixed_types(ts: List<&2, String>, +word: String) -> List<&2, String>:
  match ts:
    case Nil{}:
      Nil{}
    case Con{+t, rest}:
      type_keep(t, String.starts_with(t, word), prefixed_types(rest, word))

# S4.352 (spec twin) the nearest type within an edit distance of 2, the first of the list on a tie; `best` so far
# with its distance `d` (3 means none yet)
def nearest_edit(ts: List<&2, String>, +word: String, best: String, +d: Nat) -> String:
  match ts:
    case Nil{}:
      Bool.pick(String, Nat.is_lt(d, 3n), best, "")
    case Con{+t, rest}:
      nearest_edit(rest, word, Bool.pick(String, Nat.is_lt(distance(word, t), d), t, best), Bool.pick(Nat, Nat.is_lt(distance(word, t), d), distance(word, t), d))

# S4.352 (spec twin) the one prefix match, else the nearest by edit distance
def nearest_pick(+prefixed: List<&2, String>, +norm: String) -> String:
  match prefixed:
    case Con{t, Nil{}}:
      t
    case other:
      nearest_edit(Model.known_dep_types(), norm, "", 3n)

# S4.352 (spec twin) the near match of an unknown `--type`, "" when none: the word lower-cased with `_` and spaces as
# `-`, then an exact match, a unique prefix, or the nearest type within an edit distance of 2
def nearest_type(+norm: String) -> String:
  Bool.pick(String, Model.listed_word(Model.known_dep_types(), norm), norm, nearest_pick(prefixed_types(Model.known_dep_types(), norm), norm))

# S4.352 (spec twin) the hint of an unknown `--type`: the near match, else the list
def type_hint(+near: String) -> String:
  Bool.pick(String, String.is_empty(near), "Use --type with one of: " ++ String.join(Model.known_dep_types(), ", ") ++ ".", "Did you mean --type " ++ near ++ "?")

# S4.352 (spec twin) the refusal with its hint chosen
def bad_type_hinted(+word: String, +hint: String) -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: type: Unknown dependency type: '" ++ word ++ "'. Allowed types: " ++ String.join(Model.known_dep_types(), ", "), Some{hint}, True{}, [Failure.CtxMember{"field", Failure.CStr{"type"}}, Failure.CtxMember{"reason", Failure.CStr{"Unknown dependency type: '" ++ word ++ "'. Allowed types: " ++ String.join(Model.known_dep_types(), ", ")}}, Failure.CtxMember{"hint", Failure.CStr{hint}}], 4}

# S4.352 (spec twin) the refusal of a type outside the eleven; this list does NOT name `blocked-by` (unlike `--deps`)
def bad_type(+word: String) -> Failure.Failure:
  bad_type_hinted(word, type_hint(nearest_type(Model.lowered(dashed(word)))))

# S4.356 S9.22 (spec twin) an issue cannot depend on itself; the context key is `id` (golden error_dep_add_self_json), not `issue_id`
def self_edge(+id: String) -> Failure.Failure:
  Failure.Failure{"SELF_DEPENDENCY", "Issue cannot depend on itself: " ++ id, Some{"An issue cannot depend on itself"}, False{}, [Failure.CtxMember{"id", Failure.CStr{id}}], 5}

# S4.355 S9 (spec twin) the cycle refusal, which never prints a path
def cycle_found(+dependent: String, +target: String) -> Failure.Failure:
  Failure.Failure{"CYCLE_DETECTED", "Cycle detected in dependencies: Adding dependency " ++ dependent ++ " -> " ++ target ++ " would create a cycle", Some{"Remove one dependency to break the cycle. Note: epic containment participates in blocking cycles — depending on an epic implies depending on its entire subtree, so the cycle may traverse parent-child edges that the message does not list (see docs/CLI_REFERENCE.md, `dep add`)"}, False{}, [Failure.CtxMember{"cycle_path", Failure.CStr{"Adding dependency " ++ dependent ++ " -> " ++ target ++ " would create a cycle"}}], 5}

# ---------------------------------------------------------------- the cycle check (S4.354)

# S4.354 (data) one arc of the blocking graph
type Arc is Data:
  Arc{from: String, to: String}

# S4.354 (spec twin) one stored edge as an arc: a blocking edge runs source → target, a `parent-child` edge runs
# parent → child (the inverse of the stored row); any other type takes no part
def arc_put(source: String, target: String, blocks: Bool, parent_child: Bool, rest: List<&2, Arc>) -> List<&2, Arc>:
  match blocks parent_child:
    case True{} _:
      Arc{source, target} <> rest
    case False{} True{}:
      Arc{target, source} <> rest
    case False{} False{}:
      rest

# S4.354 (spec twin) the arcs of one issue's edges
def arcs_of(edges: List<&2, Model.Dependency>, +source: String) -> List<&2, Arc>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      arc_put(source, Model.target_of(e), Blocked.blocking(Model.dep_type_of(e)), String.eq(Model.dep_type_of(e), "parent-child"), arcs_of(rest, source))

# S4.354 (spec twin) every arc of the store
def arcs(issues: List<&2, Model.Issue>) -> List<&2, Arc>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      List.append(&2, Arc, arcs_of(Model.deps_of(i), Model.id_of(i)), arcs(rest))

# S4.354 (spec twin) keep a head that is new
def head_put(to: String, keep: Bool, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      to <> rest
    case False{}:
      rest

# S4.354 (spec twin) the heads of the arcs that leave any node of the set and are not in it yet
def step_of(ways: List<&2, Arc>, +set: List<&2, String>) -> List<&2, String>:
  match ways:
    case Nil{}:
      Nil{}
    case Con{Arc{+from, +to}, rest}:
      head_put(to, (Blocked.among(set, from) && Bool.not(Blocked.among(set, to))), step_of(rest, set))

# S4.354 (spec twin) the nodes reachable from a set, to a fixed point; the next round's new heads arrive as a
# parameter (Bend has no mutual recursion), one unit of fuel per round
def reached(fuel: Nat, +ways: List<&2, Arc>, +set: List<&2, String>, more: List<&2, String>) -> List<&2, String>:
  match fuel more:
    case 0n _:
      set
    case 1n+g Nil{}:
      set
    case 1n+g Con{+m, +rest}:
      reached(g, ways, Model.dedup(List.sort(~String, ~String.is_le, List.append(&2, String, set, m <> rest))), step_of(ways, Model.dedup(List.sort(~String, ~String.is_le, List.append(&2, String, set, m <> rest)))))

# S4.354 (spec twin) can `goal` be reached from `start` along the blocking arcs of the store
def reaches(+issues: List<&2, Model.Issue>, +start: String, +goal: String) -> Bool:
  Blocked.among(reached(Nat.add(List.length(&2, Model.Issue, issues), 1n), arcs(issues), start <> Nil{}, step_of(arcs(issues), start <> Nil{})), goal)

# S4.354 (spec twin) would the new edge close a cycle: its arc's head already reaches its tail. A `parent-child`
# edge's arc runs parent → child, so the check starts at the target
def closes_cycle(+issues: List<&2, Model.Issue>, +dependent: String, +target: String, +kind: String) -> Bool:
  Bool.pick(Bool, Blocked.blocking(kind), Bool.pick(Bool, String.eq(kind, "parent-child"), reaches(issues, dependent, target), reaches(issues, target, dependent)), False{})

# ---------------------------------------------------------------- the edge itself (S4.350, S4.358–S4.363)

# S4.350 S4.358 (spec twin) does this issue already carry an edge to the target with this type
def has_edge(edges: List<&2, Model.Dependency>, +target: String, +kind: String) -> Bool:
  match edges:
    case Nil{}:
      False{}
    case Con{+e, rest}:
      ((String.eq(Model.target_of(e), target) && String.eq(Model.dep_type_of(e), kind)) || has_edge(rest, target, kind))

# S4.363 (spec twin) the parent an issue already has, "" when it has none
def parent_of(edges: List<&2, Model.Dependency>) -> String:
  match edges:
    case Nil{}:
      ""
    case Con{+e, rest}:
      Bool.pick(String, String.eq(Model.dep_type_of(e), "parent-child"), Model.target_of(e), parent_of(rest))

# S4.359 (spec twin) keep the type of an edge that points at the target
def type_put(kind: String, keep: Bool, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      kind <> rest
    case False{}:
      rest

# S4.359 (spec twin) the types of the edges between this issue and the target
def types_between(edges: List<&2, Model.Dependency>, +target: String) -> List<&2, String>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      type_put(Model.dep_type_of(e), String.eq(Model.target_of(e), target), types_between(rest, target))

# S4.350 (spec twin) the issue with one more edge at the end of its array, and `updated_at` bumped
def with_edge(i: Model.Issue, e: Model.Dependency, now: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, c, d, f, g, h}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, now, c, d, f, g, h}, closing, source, deletion, compaction, meta, flags, labels, List.append(&2, Model.Dependency, dependencies, e <> Nil{}), comments}

# S4.351 (spec twin) keep an edge that is not the one being removed
def edge_keep(e: Model.Dependency, keep: Bool, rest: List<&2, Model.Dependency>) -> List<&2, Model.Dependency>:
  match keep:
    case True{}:
      e <> rest
    case False{}:
      rest

# S4.351 (spec twin) the edges without those that point at the target with this type
def dropped(edges: List<&2, Model.Dependency>, +target: String, +kind: String) -> List<&2, Model.Dependency>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+e, rest}:
      edge_keep(e, Bool.not((String.eq(Model.target_of(e), target) && String.eq(Model.dep_type_of(e), kind))), dropped(rest, target, kind))

# S4.351 (spec twin) the issue without the edges that point at the target with this type, and `updated_at` bumped
def without_edge(i: Model.Issue, target: String, kind: String, now: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, Model.Times{created_at, updated_at, c, d, f, g, h}, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{head, texts, people, Model.Times{created_at, now, c, d, f, g, h}, closing, source, deletion, compaction, meta, flags, labels, dropped(dependencies, target, kind), comments}

# S4.350 (spec twin) the model with one issue replaced
def replaced(model: List<&2, Model.Issue>, +new: Model.Issue) -> List<&2, Model.Issue>:
  match model:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      Bool.pick(Model.Issue, String.eq(Model.id_of(i), Model.id_of(new)), new, i) <> replaced(rest, new)

# S5.45 (spec twin) the five-member payload both edge commands print under `--json`
def payload(status: String, +dependent: String, +target: String, kind: String, action: String) -> String:
  String.concat(["{\"status\":", Failure.quoted(status), ",\"issue_id\":", Failure.quoted(dependent), ",\"depends_on_id\":", Failure.quoted(target), ",\"type\":", Failure.quoted(kind), ",\"action\":", Failure.quoted(action), "}\n"])

# S4.350 S4.353 (data) the `metadata` of a new edge: the text to store, or the refusal
type Meta is Data:
  MetaOk{text: String}
  MetaBad{failure: Failure.Failure}

# S4.350 S4.353 (spec twin) the verdict on one JSON text: it is stored verbatim when it is one JSON value; otherwise
# serde_json's message and position name the pair and the type. The text is quoted by Rust's `{:?}` and the position
# counts lines (`{` LF ` x` → `line 2 column 2`; OQ-136)
def meta_checked(c: Json.Checked, +raw: String, +dependent: String, +target: String, +kind: String) -> Meta:
  match c:
    case Json.CheckOk{toks}:
      MetaOk{raw}
    case Json.CheckBad{msg, at}:
      MetaBad{Create.invalid("metadata", "dependency metadata must be valid JSON for " ++ dependent ++ " -> " ++ target ++ " (type=" ++ kind ++ "); " ++ Failure.meta_found(raw, msg, Json.place(raw, at)))}
    case Json.CheckOdd{}:
      MetaBad{Failure.unported()}

# S4.350 (spec twin) `--metadata`: absent or blank is the literal `{}`; anything else is judged as one JSON value
def meta_of(given: Maybe<&2, String>, +dependent: String, +target: String, +kind: String) -> Meta:
  match given:
    case None{}:
      MetaOk{"{}"}
    case Some{+raw}:
      Bool.pick(Meta, String.is_empty(String.trim(raw)), MetaOk{"{}"}, meta_checked(Json.value(raw), raw, dependent, target, kind))

# S4.350 S4.355 S4.361 (spec twin) `dep add` once every check has passed: the cycle is the LAST check (S4.353),
# and the edge is written at the end of the dependent's array with its `metadata`
def add_edge(+model: List<&2, Model.Issue>, +i: Model.Issue, +dependent: String, +target: String, +kind: String, meta: String, +now: Time.Instant, actor: String, cycles: Bool) -> Done:
  match cycles:
    case True{}:
      EdgeBad{cycle_found(dependent, target)}
    case False{}:
      EdgeOk{replaced(model, with_edge(i, Model.Dependency{dependent, target, kind, now, Some{actor}, Some{meta}, Some{""}}, now)), "✓ Added dependency: " ++ Render.inline(dependent) ++ " -> " ++ Render.inline(target) ++ " (" ++ Render.inline(kind) ++ ")\n", payload("ok", dependent, target, kind, "added"), dependent, True{}}

# S4.358 (spec twin) an edge that is already there is a success no-op that rewrites nothing. The duplicate check
# comes BEFORE the cycle check (S4.353), so re-adding an existing edge never reports a cycle
def add_dup(+model: List<&2, Model.Issue>, +i: Model.Issue, +dependent: String, +target: String, +kind: String, meta: String, +now: Time.Instant, actor: String, exists: Bool, cycles: Bool) -> Done:
  match exists:
    case True{}:
      EdgeOk{model, "Dependency already exists: " ++ Render.inline(dependent) ++ " → " ++ Render.inline(target) ++ "\n", payload("exists", dependent, target, kind, "already_exists"), dependent, False{}}
    case False{}:
      add_edge(model, i, dependent, target, kind, meta, now, actor, cycles)

# S4.363 (spec twin) a second, different parent is refused before the duplicate and the cycle are looked at
def add_parented(+model: List<&2, Model.Issue>, +i: Model.Issue, +dependent: String, +target: String, +kind: String, +meta: String, +now: Time.Instant, actor: String, exists: Bool, cycles: Bool, +held: String) -> Done:
  Bool.pick(Done, (String.eq(kind, "parent-child") && Bool.not(String.is_empty(held)) && Bool.not(String.eq(held, target))), EdgeBad{Create.invalid("depends_on_id", "issue " ++ dependent ++ " already has parent " ++ held ++ "; clear or replace the existing parent before adding " ++ target)}, add_dup(model, i, dependent, target, kind, meta, now, actor, exists, cycles))

# S4.353 S4.356 (spec twin) the checks of `dep add` in the order of S4.353: self-dependency, the single parent,
# the duplicate edge, the cycle
def add_checked(model: List<&2, Model.Issue>, +i: Model.Issue, +dependent: String, +target: String, +kind: String, meta: String, now: Time.Instant, actor: String, itself: Bool, cycles: Bool) -> Done:
  match itself:
    case True{}:
      EdgeBad{self_edge(dependent)}
    case False{}:
      add_parented(model, i, dependent, target, kind, meta, now, actor, has_edge(Model.deps_of(i), target, kind), cycles, parent_of(Model.deps_of(i)))

# S4.359 (spec twin) `dep remove --type`: the named type must be one of the edges that connect the pair
def remove_typed(+model: List<&2, Model.Issue>, +i: Model.Issue, +dependent: String, +target: String, +kind: String, +now: Time.Instant, present: Bool) -> Done:
  match present:
    case False{}:
      EdgeOk{model, "", payload("not_found", dependent, target, kind, "not_found"), dependent, False{}}
    case True{}:
      EdgeOk{replaced(model, without_edge(i, target, kind, now)), "✓ Removed dependency: " ++ Render.inline(dependent) ++ " -> " ++ Render.inline(target) ++ " (" ++ Render.inline(kind) ++ ")\n", payload("ok", dependent, target, kind, "removed"), dependent, True{}}

# S4.359 S4.360 (spec twin) `dep remove` once the pair is known: no edge is a warning and no rewrite; several types
# without `--type` are refused; one edge is removed
def remove_edge(+model: List<&2, Model.Issue>, +i: Model.Issue, +dependent: String, +target: String, +kinds: List<&2, String>, given: Maybe<&2, String>, +now: Time.Instant) -> Done:
  match kinds given:
    case Nil{} _:
      EdgeOk{model, "", payload("not_found", dependent, target, "unknown", "not_found"), dependent, False{}}
    case Con{k, Nil{}} None{}:
      EdgeOk{replaced(model, without_edge(i, target, k, now)), "✓ Removed dependency: " ++ Render.inline(dependent) ++ " -> " ++ Render.inline(target) ++ " (" ++ Render.inline(k) ++ ")\n", payload("ok", dependent, target, k, "removed"), dependent, True{}}
    case Con{k, more} None{}:
      EdgeBad{Create.invalid("type", "multiple dependency types connect " ++ dependent ++ " to " ++ target ++ "; specify --type to remove one relationship")}
    case Con{k, more} Some{+want}:
      remove_typed(model, i, dependent, target, Model.dep_type_repaired(want), now, Blocked.among(k <> more, Model.dep_type_repaired(want)))

# S4.360 (spec twin) the warning a `dep remove` that found nothing writes to stderr
def not_found_warning(+dependent: String, +target: String) -> String:
  "Warning: Dependency not found: " ++ Render.inline(dependent) ++ " → " ++ Render.inline(target) ++ "\n"

# ---------------------------------------------------------------- the markdown import's issues and edges (S4.237)

# S4.237 (data) a created heading: its title and its id
type MdTitle is Data:
  MdTitle{title: String, id: String}

# S4.237 (data) an edge the import adds after every heading is created: a parent named by a LATER heading, or one
# dependency word of an issue
type MdPend is Data:
  PendParent{child: String, title: String}
  PendDep{issue: String, word: String}

# S4.237 (data) the import so far: the world (its ids grow), the created records, the titles, the pending edges and
# the refusals (all REVERSED)
type MdRun is Data:
  MdRun{world: Create.World, made: List<&2, Model.Issue>, titles: List<&2, MdTitle>, pend: List<&2, MdPend>, errs: List<&2, String>}

# S4.237 (spec twin) the id of a created heading with this exact title
def md_title_id(titles: List<&2, MdTitle>, +t: String) -> Maybe<&2, String>:
  match titles:
    case Nil{}:
      None{}
    case Con{MdTitle{title, +id}, rest}:
      Bool.pick(Maybe<&2, String>, String.eq(title, t), Some{id}, md_title_id(rest, t))

# S4.237 (spec twin) does a later heading carry this title
def md_later(plans: List<&2, Create.MdPlan>, +t: String) -> Bool:
  match plans:
    case Nil{}:
      False{}
    case Con{Create.MdPlanOk{r, d, p, ds}, rest}:
      (String.eq(Create.request_title(r), t) || md_later(rest, t))
    case Con{Create.MdPlanBad{title, reason}, rest}:
      (String.eq(title, t) || md_later(rest, t))

# S4.237 (spec twin) the dependency words of a created issue, as pending edges (REVERSED onto acc)
def md_pend_deps(words: List<&2, String>, +id: String, acc: List<&2, MdPend>) -> List<&2, MdPend>:
  match words:
    case Nil{}:
      acc
    case Con{w, rest}:
      md_pend_deps(rest, id, PendDep{id, w} <> acc)

# S4.237 (spec twin) a deferred parent, as a pending edge in front of the issue's dependency words
def md_pend_parent(later: Maybe<&2, String>, +id: String, acc: List<&2, MdPend>) -> List<&2, MdPend>:
  match later:
    case None{}:
      acc
    case Some{t}:
      PendParent{id, t} <> acc

# S4.237 (spec twin) the world of the import so far
def md_world(run: MdRun) -> Create.World:
  match run:
    case MdRun{w, made, titles, pend, errs}:
      w

# S4.237 (spec twin) the titles created so far
def md_titles(run: MdRun) -> List<&2, MdTitle>:
  match run:
    case MdRun{w, made, titles, pend, errs}:
      titles

# S4.237 (spec twin) one refusal more
def md_err(run: MdRun, +e: String) -> MdRun:
  match run:
    case MdRun{w, made, titles, pend, errs}:
      MdRun{w, made, titles, pend, e <> errs}

# S4.237 (spec twin) one heading made (or refused by the create itself): the record joins without `created_by`, with
# its design; its pending edges follow it
def md_made(m: Create.Made, +title: String, d: Maybe<&2, String>, later: Maybe<&2, String>, words: List<&2, String>, run: MdRun) -> MdRun:
  match m run:
    case Create.MadeBad{f} MdRun{w, made, titles, pend, errs}:
      MdRun{w, made, titles, pend, ("✗ Failed to create " ++ title ++ ": " ++ Create.failure_message(f)) <> errs}
    case Create.MadeOk{+issue, built} MdRun{w, made, titles, pend, errs}:
      MdRun{Create.taken(w, Model.id_of(issue)), Create.without_creator(Create.with_design(issue, d)) <> made, MdTitle{title, Model.id_of(issue)} <> titles, md_pend_deps(words, Model.id_of(issue), md_pend_parent(later, Model.id_of(issue), pend)), errs}

# S4.237 (spec twin) a heading whose parent is not a created title: an id (full or partial) makes a child; a LATER
# heading's title defers the edge; anything else refuses the heading
def md_parent_found(p: Create.Parent, +r: Create.Request, d: Maybe<&2, String>, +parent: String, words: List<&2, String>, later: Bool, +run: MdRun) -> MdRun:
  match p later:
    case Create.ParentOk{id} _:
      md_made(Create.make(Create.with_parent(r, id), md_world(run)), Create.request_title(r), d, None{}, words, run)
    case Create.ParentBad{f} True{}:
      md_made(Create.make(r, md_world(run)), Create.request_title(r), d, Some{parent}, words, run)
    case Create.ParentBad{f} False{}:
      md_err(run, "✗ Failed to resolve parent for " ++ Create.request_title(r) ++ ": " ++ Create.failure_message(f))
    case Create.ParentNone{} _:
      md_made(Create.make(r, md_world(run)), Create.request_title(r), d, None{}, words, run)

# S4.237 (spec twin) a heading's parent: a created title first, then an id, then a later title
def md_parented(found: Maybe<&2, String>, +r: Create.Request, d: Maybe<&2, String>, +parent: String, words: List<&2, String>, rest: List<&2, Create.MdPlan>, +run: MdRun) -> MdRun:
  match found:
    case Some{id}:
      md_made(Create.make(Create.with_parent(r, id), md_world(run)), Create.request_title(r), d, None{}, words, run)
    case None{}:
      md_parent_found(Create.parent_of(Some{parent}, md_world(run)), r, d, parent, words, md_later(rest, parent), run)

# S4.237 (spec twin) one heading of the first pass; `rest` are the headings after it
def md_first(p: Create.MdPlan, rest: List<&2, Create.MdPlan>, +run: MdRun) -> MdRun:
  match p:
    case Create.MdPlanBad{title, reason}:
      md_err(run, "✗ Failed to create " ++ title ++ ": " ++ reason)
    case Create.MdPlanOk{+r, d, None{}, words}:
      md_made(Create.make(r, md_world(run)), Create.request_title(r), d, None{}, words, run)
    case Create.MdPlanOk{+r, d, Some{+parent}, words}:
      md_parented(md_title_id(md_titles(run), parent), r, d, parent, words, rest, run)

# S4.237 (spec twin) the first pass: every heading in order
def md_pass1(plans: List<&2, Create.MdPlan>, run: MdRun) -> MdRun:
  match plans:
    case Nil{}:
      run
    case Con{p, +rest}:
      md_pass1(rest, md_first(p, rest, run))

# S4.237 (data) an edge to add: the dependent, the target, the type
type MdEdge is Data:
  MdEdge{from: String, to: String, kind: String}

# S4.237 (data) the second pass's answer: the edges (REVERSED) and the warnings (REVERSED)
type MdLinks is Data:
  MdLinks{edges: List<&2, MdEdge>, warns: List<&2, String>}

# S4.237 (spec twin) a dependency word's type and reference: `<known type>:<ref>`, else the whole word as a `blocks` ref
def md_word_cut(c: Resolve.Cut, +word: String) -> Resolve.Cut:
  match c:
    case Resolve.Cut{+t, right, found}:
      Bool.pick(Resolve.Cut, Model.listed_word(Model.known_dep_types(), Create.dep_kind(t)), Resolve.Cut{Create.dep_kind(t), String.trim(right), True{}}, Resolve.Cut{"blocks", word, True{}})

# S4.237 (spec twin) one dependency word resolved: a created title first, then an id; unresolved is a warning
def md_dep_found(title_hit: Maybe<&2, String>, f: Resolve.Found, +from: String, +kind: String, +word: String, links: MdLinks) -> MdLinks:
  match title_hit f links:
    case Some{id} _ MdLinks{edges, warns}:
      MdLinks{MdEdge{from, id, kind} <> edges, warns}
    case None{} Resolve.FoundOk{id} MdLinks{edges, warns}:
      MdLinks{MdEdge{from, id, kind} <> edges, warns}
    case None{} Resolve.FoundBad{e} MdLinks{edges, warns}:
      MdLinks{edges, ("warning: unresolved dependency '" ++ word ++ "' for issue " ++ from ++ ": " ++ Create.failure_message(e)) <> warns}

# S4.237 (spec twin) one dependency word, cut
def md_dep_cut(c: Resolve.Cut, +from: String, +word: String, +titles: List<&2, MdTitle>, +w: Create.World, links: MdLinks) -> MdLinks:
  match c:
    case Resolve.Cut{+kind, +ref, found}:
      md_dep_found(md_title_id(titles, ref), Create.dep_target(ref, w), from, kind, word, links)

# S4.237 (spec twin) a deferred parent: the later heading's id (none when that heading was not created)
def md_parent_edge(hit: Maybe<&2, String>, +child: String, links: MdLinks) -> MdLinks:
  match hit links:
    case Some{id} MdLinks{edges, warns}:
      MdLinks{MdEdge{child, id, "parent-child"} <> edges, warns}
    case None{} other:
      other

# S4.237 (spec twin) the second pass: every pending edge in order
def md_pass2(pend: List<&2, MdPend>, +titles: List<&2, MdTitle>, +w: Create.World, links: MdLinks) -> MdLinks:
  match pend:
    case Nil{}:
      links
    case Con{PendParent{child, t}, rest}:
      md_pass2(rest, titles, w, md_parent_edge(md_title_id(titles, t), child, links))
    case Con{PendDep{from, +word}, rest}:
      md_pass2(rest, titles, w, md_dep_cut(md_word_cut(Create.dep_cut(word), word), from, word, titles, w, links))

# S4.237 (spec twin) a record with one more edge
def md_with_edge(i: Model.Issue, e: Model.Dependency) -> Model.Issue:
  match i:
    case Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, deps, comments}:
      Model.Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, List.append(&2, Model.Dependency, deps, e <> Nil{}), comments}

# S4.237 (spec twin) an edge put on its dependent among the created records
def md_attach(made: List<&2, Model.Issue>, +from: String, +e: Model.Dependency) -> List<&2, Model.Issue>:
  match made:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      Bool.pick(Model.Issue, String.eq(Model.id_of(i), from), md_with_edge(i, e), i) <> md_attach(rest, from, e)

# S4.237 (data) one predecessor on a path search: the node and the node it was reached from
type MdPred is Data:
  MdPred{node: String, from: String}

# S4.237 (spec twin) has a node been reached
def md_seen(preds: List<&2, MdPred>, +n: String) -> Bool:
  match preds:
    case Nil{}:
      False{}
    case Con{MdPred{node, from}, rest}:
      (String.eq(node, n) || md_seen(rest, n))

# S4.237 (data) a round of the search: the predecessors and the next frontier (REVERSED)
type MdPreds is Data:
  MdPreds{preds: List<&2, MdPred>, next: List<&2, String>}

# S4.237 (spec twin) keep a newly reached node
def md_keep_arc(hit: Bool, +to: String, +n: String, st: MdPreds) -> MdPreds:
  match hit st:
    case True{} MdPreds{preds, next}:
      MdPreds{MdPred{to, n} <> preds, to <> next}
    case False{} other:
      other

# S4.237 (spec twin) whether an arc leaves `n` for a node not reached yet
def md_fresh(+from: String, +to: String, +n: String, st: MdPreds) -> Bool:
  match st:
    case MdPreds{preds, next}:
      (String.eq(from, n) && Bool.not(md_seen(preds, to)))

# S4.237 (spec twin) one node's arcs, in arc order, reached for the first time
def md_expand(ways: List<&2, Arc>, +n: String, +st: MdPreds) -> MdPreds:
  match ways:
    case Nil{}:
      st
    case Con{Arc{+from, +to}, rest}:
      md_expand(rest, n, md_keep_arc(md_fresh(from, to, n, st), to, n, st))

# S4.237 (spec twin) one round over a frontier
def md_round(frontier: List<&2, String>, +ways: List<&2, Arc>, acc: MdPreds) -> MdPreds:
  match frontier:
    case Nil{}:
      acc
    case Con{+n, rest}:
      md_round(rest, ways, md_expand(ways, n, acc))

# S4.237 (spec twin) the breadth-first search from `start` until `goal` is reached (fuel: one round per node)
def md_search(fuel: Nat, st: MdPreds, +ways: List<&2, Arc>, +goal: String) -> List<&2, MdPred>:
  match fuel st:
    case 0n MdPreds{preds, next}:
      preds
    case 1n+g MdPreds{+preds, +next}:
      Bool.pick(List<&2, MdPred>, (md_seen(preds, goal) || List.is_empty(&2, String, next)), preds, md_search(g, md_round(List.reverse(&2, String, next), ways, MdPreds{preds, Nil{}}), ways, goal))

# S4.237 (spec twin) the predecessor of a node
def md_pred_of(preds: List<&2, MdPred>, +n: String) -> String:
  match preds:
    case Nil{}:
      ""
    case Con{MdPred{+node, from}, rest}:
      Bool.pick(String, String.eq(node, n), from, md_pred_of(rest, n))

# S4.237 (spec twin) the path back from `n` to `start`, as a list from start to n
def md_back(fuel: Nat, +preds: List<&2, MdPred>, +start: String, +n: String, +acc: List<&2, String>) -> List<&2, String>:
  match fuel:
    case 0n:
      n <> acc
    case 1n+g:
      Bool.pick(List<&2, String>, String.eq(n, start), n <> acc, md_back(g, preds, start, md_pred_of(preds, n), n <> acc))

# S4.237 (spec twin) the least of some ids, in byte order
def md_least(ids: List<&2, String>, +best: String) -> String:
  match ids:
    case Nil{}:
      best
    case Con{+i, rest}:
      md_least(rest, Bool.pick(String, String.is_le(i, best), i, best))

# S4.237 (spec twin) a ring of ids turned to start at `first`: the part from it on, then the part before it
def md_turn(ring: List<&2, String>, +first: String, +before: List<&2, String>) -> List<&2, String>:
  match ring:
    case Nil{}:
      List.reverse(&2, String, before)
    case Con{+i, +rest}:
      Bool.pick(List<&2, String>, String.eq(i, first), List.append(&2, String, i <> rest, List.reverse(&2, String, before)), md_turn(rest, first, i <> before))

# S4.237 (spec twin) a ring as the words `a -> b -> … -> a`
def md_cycle_ring(+ring: List<&2, String>) -> String:
  String.join(List.append(&2, String, md_turn(ring, md_least(ring, Maybe.default(&2, String, List.head(&2, String, ring), "")), Nil{}), md_least(ring, Maybe.default(&2, String, List.head(&2, String, ring), "")) <> Nil{}), " -> ")

# S4.237 (spec twin) the cycle an edge from → to closes, as the bulk warning prints it: the path to ⇝ from along the
# blocking arcs, turned to start at its least id and closed on it
def md_cycle_text(+issues: List<&2, Model.Issue>, +from: String, +to: String) -> String:
  md_cycle_ring(md_back(Nat.add(List.length(&2, Model.Issue, issues), 1n), md_search(Nat.add(List.length(&2, Model.Issue, issues), 1n), MdPreds{MdPred{to, to} <> Nil{}, to <> Nil{}}, arcs(issues), from), to, from, Nil{}))

# S4.237 (data) the third pass so far: the created records, the store with them, the first cycle's words, the failures
# (REVERSED)
type MdAdd is Data:
  MdAdd{made: List<&2, Model.Issue>, cycle: Maybe<&2, String>, fails: List<&2, String>}

# S4.237 (spec twin) would an edge close a cycle
def md_closes(e: MdEdge, +issues: List<&2, Model.Issue>) -> Bool:
  match e:
    case MdEdge{+from, +to, +kind}:
      closes_cycle(issues, from, to, kind)

# S4.237 (spec twin) the cycle the bulk warning names: the first one met
def md_first_cycle(cycle: Maybe<&2, String>, +issues: List<&2, Model.Issue>, +from: String, +to: String) -> Maybe<&2, String>:
  match cycle:
    case Some{c}:
      Some{c}
    case None{}:
      Some{md_cycle_text(issues, from, to)}

# S4.237 (spec twin) an edge that closes a cycle is refused (the first one names the cycle); any other is added
def md_add_pick(closes: Bool, +e: MdEdge, +model: List<&2, Model.Issue>, +w: Create.World, st: MdAdd) -> MdAdd:
  match closes e st:
    case True{} MdEdge{+from, +to, kind} MdAdd{+made, cycle, fails}:
      MdAdd{made, md_first_cycle(cycle, List.append(&2, Model.Issue, model, made), from, to), ("warning: failed to add dependency " ++ from ++ " → " ++ to ++ ": Cycle detected in dependencies: Adding dependency " ++ from ++ " -> " ++ to ++ " would create a cycle") <> fails}
    case False{} MdEdge{+from, to, +kind} MdAdd{made, cycle, fails}:
      MdAdd{md_attach(made, from, Create.edge_of(from, to, kind, w)), cycle, fails}

# S4.237 (spec twin) the third pass: the edges added one at a time, in order, each checked against the store and the
# edges added before it
def md_pass3(edges: List<&2, MdEdge>, +model: List<&2, Model.Issue>, +w: Create.World, st: MdAdd) -> MdAdd:
  match edges st:
    case Nil{} other:
      other
    case Con{+e, rest} MdAdd{+made, cycle, fails}:
      md_pass3(rest, model, w, md_add_pick(md_closes(e, List.append(&2, Model.Issue, model, made)), e, model, w, MdAdd{made, cycle, fails}))

# S4.237 (data) what the import did: the created records in heading order, stderr's lines in order, the exit code
type MdResult is Data:
  MdResult{made: List<&2, Model.Issue>, errs: List<&2, String>, code: U32}

# S4.237 (spec twin) the third pass's words: the bulk warning (once, when a cycle was met) before the failures
def md_cycle_words(cycle: Maybe<&2, String>, fails: List<&2, String>) -> List<&2, String>:
  match cycle:
    case None{}:
      fails
    case Some{c}:
      ("warning: bulk dependency import failed (Cycle detected in dependencies: " ++ c ++ "); retrying dependencies one by one") <> fails

# S4.237 (spec twin) the answer from the three passes: exit 5 when a dependency was unresolved or refused
def md_result(add: MdAdd, +links_warns: List<&2, String>, errs: List<&2, String>) -> MdResult:
  match add:
    case MdAdd{made, cycle, +fails}:
      MdResult{made, List.concat(&2, String, [List.reverse(&2, String, errs), List.reverse(&2, String, links_warns), md_cycle_words(cycle, List.reverse(&2, String, fails))]), Bool.pick(U32, (List.is_empty(&2, String, links_warns) && List.is_empty(&2, String, fails)), 0, 5)}

# S4.237 (spec twin) the third pass over the second's edges
def md_linked2(links: MdLinks, made: List<&2, Model.Issue>, +model: List<&2, Model.Issue>, +w: Create.World, errs: List<&2, String>) -> MdResult:
  match links:
    case MdLinks{edges, warns}:
      md_result(md_pass3(List.reverse(&2, MdEdge, edges), model, w, MdAdd{List.reverse(&2, Model.Issue, made), None{}, Nil{}}), warns, errs)

# S4.237 (spec twin) the passes after the first: the pending edges resolved, then added
def md_linked(run: MdRun, +model: List<&2, Model.Issue>) -> MdResult:
  match run:
    case MdRun{+w, made, +titles, pend, errs}:
      md_linked2(md_pass2(List.reverse(&2, MdPend, pend), titles, w, MdLinks{Nil{}, Nil{}}), made, model, w, errs)

# S4.237 (spec twin) the whole import of a file's plans into a store
def md_import(plans: List<&2, Create.MdPlan>, w: Create.World, +model: List<&2, Model.Issue>) -> MdResult:
  md_linked(md_pass1(plans, MdRun{w, Nil{}, Nil{}, Nil{}, Nil{}}), model)
