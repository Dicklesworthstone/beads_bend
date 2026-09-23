# core/create — `create` and `q`: a new issue (S4.7–S4.27, S4.200, S4.220–S4.239, S5.37, S5.38, S5.203).
# The order of S4.238: priority, the dates, the parent, the id, the issue-level
# validation (title, labels), the relations; then the record, the write-back of
# the WHOLE model (S5.1) and `.beads/last-touched`. Not here yet, each refused
# with the port's own failure by the dispatcher: `--file`, `--description-file`,
# `--agent-context`, and a `--deps` target given by title (S4.49).
# Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./failure.bend as Failure
import ./id.bend as Id
import ./query.bend as Query
import ./resolve.bend as Resolve
import ./when.bend as When
import ./render.bend as Render

# S4.200 S4.220 S4.221 (data) what a mutation knows of the world: every stored id (the raw file's, tombstones
# included: S4.10, S4.13), the acting actor, the invocation instant and its nanoseconds since the epoch as digits
# (the id seed's fourth part), the workspace's default prefix and its absolute path
type World is Data:
  World{ids: List<&2, String>, actor: String, now: Time.Instant, nanos: String, prefix: String, repo_path: String}

# S9 (spec twin) a validation failure: `Validation failed: <field>: <reason>`, exit 4
def invalid(+field: String, +reason: String) -> Failure.Failure:
  Failure.Failure{"VALIDATION_FAILED", "Validation failed: " ++ field ++ ": " ++ reason, None{}, True{}, [Failure.CtxMember{"field", Failure.CStr{field}}, Failure.CtxMember{"reason", Failure.CStr{reason}}], 4}

# ---------------------------------------------------------------- ids (S4.7–S4.27)

# S4.11 (spec twin) is this id free
def free(ids: List<&2, String>, +id: String) -> Bool:
  match ids:
    case Nil{}:
      True{}
    case Con{x, rest}:
      (Bool.not(String.eq(x, id)) && free(rest, id))

# S4.11 S4.12 (data) where the collision ladder stands: the hash length, the nonce, and whether the fixed
# twelve-character rung was reached
type Rung is Data:
  Rung{length: Nat, nonce: Nat, last: Bool}

# S4.11 S4.12 (spec twin) the next rung: nonces 0..9 at a length, then the next length up to 8, then length 12 with nonces 0..2000
def next_rung(r: Rung) -> Rung:
  match r:
    case Rung{+length, +nonce, +last}:
      Bool.pick(Rung, last, Rung{length, Nat.add(nonce, 1n), True{}}, Bool.pick(Rung, Nat.is_lt(nonce, 9n), Rung{length, Nat.add(nonce, 1n), False{}}, Bool.pick(Rung, Nat.is_lt(length, 8n), Rung{Nat.add(length, 1n), 0n, False{}}, Rung{12n, 0n, True{}})))

# S4.7 (spec twin) the id of one rung: the prefix, `-`, an optional slug and `-`, the hash of the seed at the rung's length
def rung_id(r: Rung, prefix: String, slug: String, title: String, description: String, creator: String, nanos: String) -> String:
  match r:
    case Rung{length, +nonce, last}:
      prefix ++ "-" ++ slug ++ Id.hash36(Id.seed(title, description, creator, nanos, nonce), length)

# S4.11–S4.13 (spec twin) climb the ladder until an id is free; "" when the last rung (length 12, nonce 2000) is taken
# too. The verdict of the CURRENT rung arrives as a parameter, so a free id stops the climb at once and no later
# rung is ever hashed. One unit of fuel per rung: 60 rungs below the fixed one, 2001 on it
def climb(fuel: Nat, is_free: Bool, candidate: String, +r: Rung, +ids: List<&2, String>, +prefix: String, +slug: String, +title: String, +description: String, +creator: String, +nanos: String) -> String:
  match fuel is_free:
    case 0n _:
      ""
    case 1n+g True{}:
      candidate
    case 1n+g False{}:
      climb(g, free(ids, rung_id(next_rung(r), prefix, slug, title, description, creator, nanos)), rung_id(next_rung(r), prefix, slug, title, description, creator, nanos), next_rung(r), ids, prefix, slug, title, description, creator, nanos)

# S4.233 (spec twin) one code point of a slug: an ASCII letter is lower-cased, a digit is kept, anything else is 0 ("a separator")
def slug_char(+c: U32) -> U32:
  Bool.pick(U32, ((c >= 65 : U32) && (c <= 90 : U32)), (c + 32 : U32), Bool.pick(U32, (((c >= 97 : U32) && (c <= 122 : U32)) || ((c >= 48 : U32) && (c <= 57 : U32))), c, 0))

# S4.233 (spec twin) push one slug code point: a separator (0) pushes nothing; a letter or digit after a pending gap
# pushes `-` first, unless nothing was pushed yet
def slug_push(+ch: U32, acc: List<&2, U32>, gap: Bool) -> List<&2, U32>:
  match acc gap:
    case Nil{} _:
      Bool.pick(List<&2, U32>, U32.is_eq(ch, 0), Nil{}, ch <> Nil{})
    case Con{+a, +rest} True{}:
      Bool.pick(List<&2, U32>, U32.is_eq(ch, 0), a <> rest, ch <> 45 <> a <> rest)
    case Con{+a, +rest} False{}:
      Bool.pick(List<&2, U32>, U32.is_eq(ch, 0), a <> rest, ch <> a <> rest)

# S4.233 (spec twin) a separator opens a gap; a letter or digit closes it
def slug_gap(ch: U32) -> Bool:
  U32.is_eq(ch, 0)

# S4.233 (spec twin) a slug is followed by `-` in the id; an empty one adds nothing
def slug_dash(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{h, t}:
      SCon{h, t} ++ "-"

# S4.233 (spec twin) a text without `-` at its end (the 48-point cap can leave one)
def no_tail_dash(rev: String) -> String:
  match rev:
    case SCon{Chr{45}, rest}:
      no_tail_dash(rest)
    case other:
      other

# S4.233 (spec twin) the normalized slug capped at 48 code points and followed by `-`; "" when nothing is left
def slug_text(s: String) -> String:
  slug_dash(String.reverse(no_tail_dash(String.reverse(String.take(s, 48n)))))

# S4.233 (spec twin) the slug's code points (REVERSED in `acc`): every run of separators collapses to one `-`, and a
# leading run vanishes; `gap` says a separator run is pending
def slug_go(cs: List<&2, U32>, acc: List<&2, U32>, gap: Bool) -> List<&2, U32>:
  match cs:
    case Nil{}:
      acc
    case Con{+c, rest}:
      slug_go(rest, slug_push(slug_char(c), acc, gap), slug_gap(slug_char(c)))

# S4.233 (spec twin) a `--slug` as the id carries it: normalized, capped at 48 code points, no `-` at either end,
# followed by one `-`; "" when nothing is left
def slug_of(given: Maybe<&2, String>) -> String:
  match given:
    case None{}:
      ""
    case Some{text}:
      slug_text(String.trim(Resolve.text_rev(slug_go(Time.codes(text), Nil{}, False{}), "")))

# S4.24–S4.26 (spec twin) the number a child id ends in, when `id` is a DIRECT child of `parent` (`<parent>.<digits>`); 0 otherwise
def child_number(+id: String, +parent: String) -> U32:
  Bool.pick(U32, String.starts_with(id, parent ++ "."), Maybe.default(&2, U32, U32.read(String.drop(id, Nat.add(String.length(parent), 1n))), 0), 0)

# S4.25 (spec twin) the greatest child number under a parent among the stored ids
def max_child(ids: List<&2, String>, +parent: String, acc: U32) -> U32:
  match ids:
    case Nil{}:
      acc
    case Con{id, rest}:
      max_child(rest, parent, U32.max(acc, child_number(id, parent)))

# S4.26 (spec twin) the first free child id from a number on, at most 100 increments past it; "" when none is free
def child_free(fuel: Nat, is_free: Bool, candidate: String, +n: U32, +ids: List<&2, String>, +parent: String) -> String:
  match fuel is_free:
    case 0n _:
      ""
    case 1n+g True{}:
      candidate
    case 1n+g False{}:
      child_free(g, free(ids, parent ++ "." ++ U32.show((n + 1 : U32))), parent ++ "." ++ U32.show((n + 1 : U32)), (n + 1 : U32), ids, parent)

# S4.26 (spec twin) the search for a free child id, from a number on
def child_from(+n: U32, +ids: List<&2, String>, +parent: String) -> String:
  child_free(101n, free(ids, parent ++ "." ++ U32.show(n)), parent ++ "." ++ U32.show(n), n, ids, parent)

# S4.24–S4.26 (spec twin) the id of a new child: `<parent>.<n>` with n one past the greatest stored child number
def child_id(+ids: List<&2, String>, +parent: String) -> String:
  child_from((max_child(ids, parent, 0) + 1 : U32), ids, parent)

# S4.8–S4.13 (spec twin) a fresh hashed id: the ladder starts at the adaptive length for the number of stored records, nonce 0
def hashed_id(+w: World, +slug: String, +title: String, +description: String, +creator: String) -> String:
  match w:
    case World{+ids, actor, now, +nanos, +prefix, repo_path}:
      climb(2062n, free(ids, rung_id(Rung{Id.length_for(U32.from_nat(List.length(&2, String, ids))), 0n, False{}}, prefix, slug, title, description, creator, nanos)), rung_id(Rung{Id.length_for(U32.from_nat(List.length(&2, String, ids))), 0n, False{}}, prefix, slug, title, description, creator, nanos), Rung{Id.length_for(U32.from_nat(List.length(&2, String, ids))), 0n, False{}}, ids, prefix, slug, title, description, creator, nanos)

# ---------------------------------------------------------------- the request

# S4.220–S4.234 (data) what the command line asks for. `seed_description` and `seed_creator` are the id seed's second
# and third parts (S4.15: the raw description and the actor for `create`; S4.16: both EMPTY for `q`); `quick` is `q`,
# which never sets `source_repo` and `source_repo_path` (S5.19)
type Request is Data:
  Request{title: String, seed_description: String, seed_creator: String, description: Maybe<&2, String>, kind: Maybe<&2, String>, priority: Maybe<&2, String>, status: Maybe<&2, String>, assignee: Maybe<&2, String>, owner: Maybe<&2, String>, labels: List<&2, String>, parent: Maybe<&2, String>, deps: List<&2, String>, estimate: Maybe<&2, String>, due: Maybe<&2, String>, defer: Maybe<&2, String>, external_ref: Maybe<&2, String>, acceptance: Maybe<&2, String>, prerequisites: Maybe<&2, String>, slug: Maybe<&2, String>, ephemeral: Bool, quick: Bool}

# S4.235 S5.37 (data) the new issue: as the write-back spells it (repaired, which is what `--json` prints), and as it
# was built in memory (which is what `--dry-run --json` prints); or the refusal
type Made is Data:
  MadeBad{failure: Failure.Failure}
  MadeOk{issue: Model.Issue, built: Model.Issue}

# ---------------------------------------------------------------- the pieces (S4.224, S4.227, S4.229, S4.230)

# S4.224 S9.15 (data) the priority's digits, or the refusal
type Rank is Data:
  RankBad{failure: Failure.Failure}
  RankOk{digits: String}

# S4.224 (spec twin) route on "not a priority" (9)
def rank_pick(+shown: String, +p: U32) -> Rank:
  Bool.pick(Rank, U32.is_eq(p, 9), RankBad{Query.bad_priority(shown)}, RankOk{U32.show(p)})

# S4.220 S4.224 (spec twin) `-p`: the bare digit or the `P` form, in any case; 2 when it is not given
def rank_of(given: Maybe<&2, String>) -> Rank:
  match given:
    case None{}:
      RankOk{"2"}
    case Some{+text}:
      rank_pick(Query.shouted(String.trim(text)), Query.priority_word(Query.shouted(String.trim(text))))

# S4.230 (data) an optional instant, or the refusal
type Date is Data:
  DateBad{failure: Failure.Failure}
  DateOk{at: Maybe<&2, Time.Instant>}

# S4.230 S4.324 (spec twin) a date option read by the grammar of core/when against the invocation instant
def date_named(n: When.Named, field: String) -> Date:
  match n:
    case When.NoTime{why}:
      DateBad{invalid(field, When.reason(why))}
    case When.AtTime{at}:
      DateOk{Some{at}}

# S4.230 (spec twin) `--due` or `--defer`, when given
def date_of(given: Maybe<&2, String>, now: Time.Instant, field: String) -> Date:
  match given:
    case None{}:
      DateOk{None{}}
    case Some{text}:
      date_named(When.named(String.trim(text), now), field)

# S4.227 (spec twin) keep a label that was not seen before
def first_put(l: String, seen: Bool, rest: List<&2, String>) -> List<&2, String>:
  match seen:
    case True{}:
      rest
    case False{}:
      l <> rest

# S4.227 (spec twin) keep the first occurrence of each label
def first_seen(labels: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match labels:
    case Nil{}:
      Nil{}
    case Con{+l, rest}:
      first_put(l, Query.among(seen, l), first_seen(rest, l <> seen))

# S4.239 (spec twin) may this code point stand in a label: an ASCII letter or digit, `-`, `_`, `:`
def label_char(+c: U32) -> Bool:
  (((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || U32.is_eq(c, 45) || U32.is_eq(c, 95) || U32.is_eq(c, 58))

# S4.239 (spec twin) is every code point of a label allowed
def label_ok(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{c}, rest}:
      (label_char(c) && label_ok(rest))

# S4.239 (spec twin) are all labels allowed
def labels_ok(labels: List<&2, String>) -> Bool:
  match labels:
    case Nil{}:
      True{}
    case Con{l, rest}:
      (label_ok(l) && labels_ok(rest))

# S4.229 (data) the edges of `--deps` so far (REVERSED), or the first refusal
type Edges is Data:
  EdgesBad{failure: Failure.Failure}
  EdgesOk{edges: List<&2, Model.Dependency>}

# S4.229 (spec twin) the refusal of a `--deps` type nobody knows; this list names `blocked-by`, unlike `dep add`'s
def bad_dep_type(t: String) -> Failure.Failure:
  invalid("deps", "Unknown dependency type: '" ++ t ++ "'. Allowed types: blocks, blocked-by, parent-child, conditional-blocks, waits-for, related, discovered-from, replies-to, relates-to, duplicates, supersedes, caused-by")

# S4.229 (spec twin) an element cut at its first `:`: with one, the type and the target; without one, `blocks` and the element
def dep_cut_typed(c: Resolve.Cut, whole: String) -> Resolve.Cut:
  match c:
    case Resolve.Cut{left, right, True{}}:
      Resolve.Cut{left, right, True{}}
    case Resolve.Cut{left, right, False{}}:
      Resolve.Cut{"blocks", whole, True{}}

# S4.229 (spec twin) one `--deps` element: `external:<name>` is a target of type `blocks`; `<type>:<id>` names the
# type; a bare id means `blocks`. The answer is the type then the target, cut apart
def dep_cut(+e: String) -> Resolve.Cut:
  Bool.pick(Resolve.Cut, String.starts_with(e, "external:"), Resolve.Cut{"blocks", e, True{}}, dep_cut_typed(Resolve.cut_first(e, 58, Nil{}), e))

# S4.229 S5.14 (spec twin) an edge minted by this command: the acting actor, `{}` and the empty thread id
def edge_of(+id: String, target: String, kind: String, +w: World) -> Model.Dependency:
  match w:
    case World{ids, actor, now, nanos, prefix, repo_path}:
      Model.Dependency{id, target, kind, now, Some{actor}, Some{"{}"}, Some{""}}

# S4.229 (spec twin) the type of a `--deps` element as it is stored: trimmed, lower case, `blocked-by` written `blocks`
def dep_kind(+t: String) -> String:
  Bool.pick(String, String.eq(Model.lowered(String.trim(t)), "blocked-by"), "blocks", Model.lowered(String.trim(t)))

# S4.229 S4.49 (spec twin) the target of a `--deps` element: `external:…` verbatim, anything else resolved like any id
def dep_target(+target: String, +w: World) -> Resolve.Found:
  match w:
    case World{ids, actor, now, nanos, prefix, repo_path}:
      Bool.pick(Resolve.Found, String.starts_with(target, "external:"), Resolve.FoundOk{target}, Resolve.resolve(ids, target, prefix))

# S4.229 (spec twin) fold one element in: a refusal is sticky; an unknown type is refused before the target is looked at
def edge_step(sofar: Edges, known: Bool, found: Resolve.Found, +kind: String, id: String, w: World) -> Edges:
  match sofar known found:
    case EdgesBad{f} _ _:
      EdgesBad{f}
    case EdgesOk{edges} False{} _:
      EdgesBad{bad_dep_type(kind)}
    case EdgesOk{edges} True{} Resolve.FoundBad{f}:
      EdgesBad{f}
    case EdgesOk{edges} True{} Resolve.FoundOk{target}:
      EdgesOk{edge_of(id, target, kind, w) <> edges}

# S4.229 (spec twin) one cut element folded in
def edge_cut(sofar: Edges, c: Resolve.Cut, +id: String, +w: World) -> Edges:
  match c:
    case Resolve.Cut{+t, target, found}:
      edge_step(sofar, Model.listed_word(Model.known_dep_types(), dep_kind(t)), dep_target(String.trim(target), w), dep_kind(t), id, w)

# S4.229 (spec twin) every `--deps` element, in order
def edges_go(elements: List<&2, String>, sofar: Edges, +id: String, +w: World) -> Edges:
  match elements:
    case Nil{}:
      sofar
    case Con{e, rest}:
      edges_go(rest, edge_cut(sofar, dep_cut(e), id, w), id, w)

# ---------------------------------------------------------------- the record (S4.220–S4.234)

# S4.231 (spec twin) `closed` sets `closed_at` to the create instant
def when_status(+status: String, +word: String, now: Time.Instant) -> Maybe<&2, Time.Instant>:
  Bool.pick(Maybe<&2, Time.Instant>, String.eq(Model.lowered(status), word), Some{now}, None{})

# S4.231 (spec twin) `tombstone` sets `deleted_by` to the actor
def who_deleted(status: String, actor: String) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, String.eq(Model.lowered(status), "tombstone"), Some{actor}, None{})

# S4.230 (spec twin) `-e` as the record holds it: the digits the argument parser accepted, without `+` or leading zeros
def minutes(given: Maybe<&2, String>) -> Maybe<&2, String>:
  match given:
    case None{}:
      None{}
    case Some{SCon{Chr{43}, digits}}:
      Some{U32.show(Maybe.default(&2, U32, U32.read(digits), 0))}
    case Some{digits}:
      Some{U32.show(Maybe.default(&2, U32, U32.read(digits), 0))}

# S5.19 (spec twin) `q` never sets the two source members; `create` sets the workspace's name and its absolute path
def source_part(quick: Bool, value: String) -> Maybe<&2, String>:
  match quick:
    case True{}:
      None{}
    case False{}:
      Some{value}

# S4.231 (spec twin) `-s` on the built record: the status as given; `closed` also stamps `closed_at`; `tombstone`
# also stamps `deleted_at` and names the actor in `deleted_by`
def record_status(+status: String, i: Model.Issue, actor: String, +now: Time.Instant) -> Model.Issue:
  match i:
    case Model.Issue{Model.Head{id, title, old, priority, kind}, texts, people, Model.Times{created_at, updated_at, closed_at, due_at, defer_until, deleted_at, compacted_at}, closing, source, Model.Deletion{deleted_by, delete_reason, original_type}, compaction, meta, flags, labels, dependencies, comments}:
      Model.Issue{Model.Head{id, title, status, priority, kind}, texts, people, Model.Times{created_at, updated_at, when_status(status, "closed", now), due_at, defer_until, when_status(status, "tombstone", now), compacted_at}, closing, source, Model.Deletion{who_deleted(status, actor), delete_reason, original_type}, compaction, meta, flags, labels, dependencies, comments}

# S4.220–S4.234 (spec twin) the record a request builds, once its id, priority, dates and edges are known
def record(r: Request, +w: World, id: String, priority: String, due: Maybe<&2, Time.Instant>, defer: Maybe<&2, Time.Instant>, edges: List<&2, Model.Dependency>) -> Model.Issue:
  match r w:
    case Request{title, seed_description, seed_creator, description, kind, rank, status, assignee, owner, labels, parent, deps, estimate, due_text, defer_text, external_ref, acceptance, prerequisites, slug, ephemeral, +quick} World{ids, +actor, +now, nanos, prefix, +repo_path}:
      record_status(Maybe.default(&2, String, status, "open"), Model.Issue{Model.Head{id, title, "open", priority, Maybe.default(&2, String, kind, "task")}, Model.Texts{description, None{}, acceptance, prerequisites, None{}}, Model.People{assignee, owner, Some{actor}, None{}}, Model.Times{now, now, None{}, due, defer, None{}, None{}}, Model.Closing{None{}, None{}, None{}, None{}, None{}}, Model.Source{external_ref, None{}, source_part(quick, Resolve.remainder_of(Resolve.cut_last(repo_path, 47))), source_part(quick, repo_path), None{}}, Model.Deletion{None{}, None{}, None{}}, Model.Compaction{None{}, None{}, None{}}, Model.Meta{minutes(estimate)}, Model.Flags{ephemeral, False{}, False{}}, first_seen(Query.comma_split(labels), Nil{}), edges, Nil{}}, actor, now)

# ---------------------------------------------------------------- make (S4.238)

# S4.228 (data) the parent a request names: none, the resolved id, or the refusal
type Parent is Data:
  ParentNone{}
  ParentBad{failure: Failure.Failure}
  ParentOk{id: String}

# S4.228 S4.238 (spec twin) `--parent`, resolved like any id; an unresolvable parent refuses the create
def parent_found(f: Resolve.Found) -> Parent:
  match f:
    case Resolve.FoundBad{failure}:
      ParentBad{failure}
    case Resolve.FoundOk{id}:
      ParentOk{id}

# S4.228 (spec twin) the parent of a request
def parent_of(given: Maybe<&2, String>, w: World) -> Parent:
  match given w:
    case None{} _:
      ParentNone{}
    case Some{text} World{ids, actor, now, nanos, prefix, repo_path}:
      parent_found(Resolve.resolve(ids, text, prefix))

# S4.228 (spec twin) the edges a record starts with: one `parent-child` edge on the CHILD when it has a parent
def parent_edges(p: Parent, id: String, w: World) -> Edges:
  match p:
    case ParentOk{parent}:
      EdgesOk{edge_of(id, parent, "parent-child", w) <> Nil{}}
    case other:
      EdgesOk{Nil{}}

# S4.24 S4.233 (spec twin) the new id: a child number under a parent (the slug is ignored then), else a fresh hash
def new_id(p: Parent, +w: World, slug: String, title: String, seed_description: String, seed_creator: String) -> String:
  match p w:
    case ParentOk{parent} World{ids, actor, now, nanos, prefix, repo_path}:
      child_id(ids, parent)
    case other whole:
      hashed_id(whole, slug, title, seed_description, seed_creator)

# S4.235 S5.37 (spec twin) the built record with its repaired spelling beside it
def made_pair(+built: Model.Issue) -> Made:
  MadeOk{Model.repaired(built), built}

# S4.229 S4.238 (spec twin) the last step: the relations; then the record, as built and as the write-back spells it
def made(e: Edges, r: Request, w: World, id: String, priority: String, due: Maybe<&2, Time.Instant>, defer: Maybe<&2, Time.Instant>) -> Made:
  match e:
    case EdgesBad{f}:
      MadeBad{f}
    case EdgesOk{edges}:
      made_pair(record(r, w, id, priority, due, defer, List.reverse(&2, Model.Dependency, edges)))

# S4.12 S4.26 (spec twin) an id that could not be found free refuses the create
def with_id(+id: String, p: Parent, +r: Request, +w: World, priority: String, due: Maybe<&2, Time.Instant>, defer: Maybe<&2, Time.Instant>, deps: List<&2, String>) -> Made:
  match id:
    case SNil{}:
      MadeBad{invalid("parent", "could not find available child ID")}
    case SCon{h, t}:
      made(edges_go(Query.comma_split(deps), parent_edges(p, id, w), id, w), r, w, id, priority, due, defer)

# S4.238 S4.239 S4.372 (spec twin) the checks in the original's order: the priority, the dates, the parent, then the
# title (empty, then too long) and the labels (their characters, then more than 64 of them); the first refusal wins
def checked(rank: Rank, due: Date, defer: Date, p: Parent, title_empty: Bool, title_long: Bool, labels_bad: Bool, labels_many: Bool, +r: Request, +w: World, +title: String, slug: String, seed_description: String, seed_creator: String, deps: List<&2, String>) -> Made:
  match rank due defer p title_empty title_long labels_bad:
    case RankBad{f} _ _ _ _ _ _:
      MadeBad{f}
    case RankOk{digits} DateBad{f} _ _ _ _ _:
      MadeBad{f}
    case RankOk{digits} DateOk{a} DateBad{f} _ _ _ _:
      MadeBad{f}
    case RankOk{digits} DateOk{a} DateOk{b} ParentBad{f} _ _ _:
      MadeBad{f}
    case RankOk{digits} DateOk{a} DateOk{b} parent True{} _ _:
      MadeBad{invalid("title", "cannot be empty")}
    case RankOk{digits} DateOk{a} DateOk{b} parent False{} True{} _:
      MadeBad{invalid("title", "exceeds 500 characters")}
    case RankOk{digits} DateOk{a} DateOk{b} parent False{} False{} True{}:
      MadeBad{invalid("label", "invalid characters (only alphanumeric, hyphen, underscore, colon allowed)")}
    case RankOk{digits} DateOk{a} DateOk{b} +parent False{} False{} False{}:
      Bool.pick(Made, labels_many, MadeBad{invalid("labels", "exceeds 64 labels")}, with_id(new_id(parent, w, slug, title, seed_description, seed_creator), parent, r, w, digits, a, b, deps))

# S4.220–S4.239 (spec twin) a new issue from a request, or the first refusal
def make(+r: Request, +w: World) -> Made:
  match r w:
    case Request{+title, seed_description, seed_creator, description, kind, rank, status, assignee, owner, +labels, parent, deps, estimate, due_text, defer_text, external_ref, acceptance, prerequisites, slug, ephemeral, quick} World{ids, actor, +now, nanos, prefix, repo_path}:
      checked(rank_of(rank), date_of(due_text, now, "date"), date_of(defer_text, now, "date"), parent_of(parent, w), String.is_empty(String.trim(title)), Nat.is_gt(String.length(title), 500n), Bool.not(labels_ok(Query.comma_split(labels))), Nat.is_gt(List.length(&2, String, Model.dedup(List.sort(~String, ~String.is_le, Query.comma_split(labels)))), 64n), r, w, title, slug_of(slug), seed_description, seed_creator, deps)
