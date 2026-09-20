# core/work — what is blocked, what is ready, and the `stats` figures (S4.151–S4.156, S4.167–S4.178).
# All three read the BLOCKED relation of core/blocked. `blocked` lists its
# live keys under its own order (the blocker count is a sort key nowhere else);
# `ready` lists the open issues outside it under one of three sort policies;
# `stats` counts. Not here yet: `blocked --detailed`, `ready --parent` /
# `--recursive` / `--epic`, and a mean of whole-hour lead times that is not
# itself a whole number of tenths, or whose days figure lands exactly on a
# half of a tenth that binary64 does not hold exactly (OQ-078).
# Nothing here consults the original.
import Base
import ./time.bend as Time
import ./model.bend as Model
import ./blocked.bend as Blocked
import ./query.bend as Query

# S4.167 (data) one row of `blocked`: the issue and the ids that block it, in the relation's normalized order
type Row is Data:
  Row{issue: Model.Issue, blockers: List<&2, String>}

# S4.163 (spec twin) blocker refs as the ids the outputs show
def ref_ids(refs: List<&2, String>) -> List<&2, String>:
  match refs:
    case Nil{}:
      Nil{}
    case Con{r, rest}:
      Blocked.ref_id(r) <> ref_ids(rest)

# S4.167 (spec twin) a key of the relation is a row when its issue is stored and not terminal
def row_put(found: Maybe<&2, Model.Issue>, refs: List<&2, String>, +rest: List<&2, Row>) -> List<&2, Row>:
  match found:
    case None{}:
      rest
    case Some{+i}:
      Bool.pick(List<&2, Row>, Blocked.terminal(Model.status_of(i)), rest, Row{i, ref_ids(refs)} <> rest)

# S4.167 (spec twin) the rows of `blocked` before its filters, in the relation's order
def rows(entries: List<&2, Blocked.Entry>, +all: List<&2, Model.Issue>) -> List<&2, Row>:
  match entries:
    case Nil{}:
      Nil{}
    case Con{Blocked.Entry{id, refs}, rest}:
      row_put(Blocked.lookup(all, id), refs, rows(rest, all))

# S4.168 (spec twin) does a row pass the filters of `blocked`: type (any of), priority (any of), label (all of)
def row_keeps(+i: Model.Issue, types: List<&2, String>, priorities: List<&2, U32>, labels: List<&2, String>) -> Bool:
  (Query.word_ok(types, Query.folded(Model.type_of(i))) && Query.priority_ok(priorities, Query.priority_number(Model.priority_of(i))) && Query.labels_all_ok(labels, Model.labels_of(i)))

# S4.168 (spec twin) keep a row that passes
def rows_put(r: Row, keep: Bool, rest: List<&2, Row>) -> List<&2, Row>:
  match keep:
    case True{}:
      r <> rest
    case False{}:
      rest

# S4.168 (spec twin) the rows that pass the filters
def rows_kept(rs: List<&2, Row>, +types: List<&2, String>, +priorities: List<&2, U32>, +labels: List<&2, String>) -> List<&2, Row>:
  match rs:
    case Nil{}:
      Nil{}
    case Con{Row{+issue, blockers}, rest}:
      rows_put(Row{issue, blockers}, row_keeps(issue, types, priorities, labels), rows_kept(rest, types, priorities, labels))

# S4.169 (spec twin) the four keys of the `blocked` order, compared in turn
def row_le_keys(+xp: U32, +yp: U32, +xn: Nat, +yn: Nat, +xc: Time.Instant, +yc: Time.Instant, xi: String, yi: String) -> Bool:
  ((xp < yp : U32) || (U32.is_eq(xp, yp) && (Nat.is_gt(xn, yn) || (Nat.is_eq(xn, yn) && (Bool.not(Time.le(xc, yc)) || (Time.eq(xc, yc) && String.is_le(xi, yi)))))))

# S4.169 (spec twin) the order of `blocked`: priority ascending, then blocker count DESCENDING, then `created_at`
# descending, then id ascending
def row_le(x: Row, y: Row) -> Bool:
  match x y:
    case Row{+xi, +xb} Row{+yi, +yb}:
      row_le_keys(Query.priority_number(Model.priority_of(xi)), Query.priority_number(Model.priority_of(yi)), List.length(&2, String, xb), List.length(&2, String, yb), Model.created_of(xi), Model.created_of(yi), Model.id_of(xi), Model.id_of(yi))

# S4.167–S4.169 (spec twin) the rows of `blocked`: the live keys of the relation, filtered, in the command's order
def blocked_rows(+all: List<&2, Model.Issue>, types: List<&2, String>, priorities: List<&2, U32>, labels: List<&2, String>) -> List<&2, Row>:
  List.sort(~Row, ~row_le, rows_kept(rows(Blocked.relation(all), all), types, priorities, labels))

# ---------------------------------------------------------------- ready (S4.171–S4.178)

# S4.171 (spec twin) is an optional instant absent, or not after `now`; without a `now` nothing is held back
def gate_open(until: Maybe<&2, Time.Instant>, now: Maybe<&2, Time.Instant>) -> Bool:
  match until now:
    case None{} _:
      True{}
    case Some{u} None{}:
      True{}
    case Some{u} Some{n}:
      Time.le(u, n)

# S4.171 S4.172 (spec twin) is an issue a `ready` candidate: its status is in the ready group (`open`, and `deferred`
# under `--include-deferred`, which also drops the defer gate); it is not a key of the BLOCKED relation; it is not
# pinned, not ephemeral, not a template, and its id holds no `-wisp-`
def candidate(+i: Model.Issue, +blocked_ids: List<&2, String>, now: Maybe<&2, Time.Instant>, +with_deferred: Bool) -> Bool:
  ((String.eq(Model.status_of(i), "open") || (with_deferred && String.eq(Query.folded(Model.status_of(i)), "deferred"))) && Bool.not(Blocked.among(blocked_ids, Model.id_of(i))) && (with_deferred || gate_open(Model.defer_of(i), now)) && Bool.not(Model.is_pinned(i)) && Bool.not(Model.is_ephemeral(i)) && Bool.not(String.contains(Model.id_of(i), "-wisp-")) && Bool.not(Model.is_template(i)))

# S4.171 (spec twin) keep a candidate
def ready_put(i: Model.Issue, keep: Bool, rest: List<&2, Model.Issue>) -> List<&2, Model.Issue>:
  match keep:
    case True{}:
      i <> rest
    case False{}:
      rest

# S4.171 (spec twin) the candidates of a store, in store order
def candidates(issues: List<&2, Model.Issue>, +blocked_ids: List<&2, String>, +now: Maybe<&2, Time.Instant>, +with_deferred: Bool) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      ready_put(i, candidate(i, blocked_ids, now, with_deferred), candidates(rest, blocked_ids, now, with_deferred))

# S4.173 (spec twin) does a candidate pass the filters of `ready`: assignee, unassigned, labels (all of), labels (any of),
# type (any of), priority (any of)
def ready_keeps(+i: Model.Issue, assignee: Maybe<&2, String>, unassigned: Bool, labels_all: List<&2, String>, labels_any: List<&2, String>, types: List<&2, String>, priorities: List<&2, U32>) -> Bool:
  (Query.assignee_ok(assignee, Model.assignee_of(i)) && Query.unassigned_ok(unassigned, Model.assignee_of(i)) && Query.labels_all_ok(labels_all, Model.labels_of(i)) && Query.labels_any_ok(labels_any, Model.labels_of(i)) && Query.word_ok(types, Query.folded(Model.type_of(i))) && Query.priority_ok(priorities, Query.priority_number(Model.priority_of(i))))

# S4.173 (spec twin) the candidates that pass the filters
def ready_kept(issues: List<&2, Model.Issue>, +assignee: Maybe<&2, String>, +unassigned: Bool, +labels_all: List<&2, String>, +labels_any: List<&2, String>, +types: List<&2, String>, +priorities: List<&2, U32>) -> List<&2, Model.Issue>:
  match issues:
    case Nil{}:
      Nil{}
    case Con{+i, rest}:
      ready_put(i, ready_keeps(i, assignee, unassigned, labels_all, labels_any, types, priorities), ready_kept(rest, assignee, unassigned, labels_all, labels_any, types, priorities))

# S4.174 (spec twin) the hybrid bucket of a priority: 0 for P0 and P1, 1 for everything else
def bucket(+p: U32) -> U32:
  Bool.pick(U32, (p <= 1 : U32), 0, 1)

# S4.174 (spec twin) `hybrid`: the bucket, then `created_at` ASCENDING, then id ascending
def le_hybrid(x: Query.Row, y: Query.Row) -> Bool:
  match x y:
    case Query.Row{+xp, +xa, xt, xi, xo} Query.Row{+yp, +ya, yt, yi, yo}:
      Query.le3((bucket(xp) < bucket(yp) : U32), U32.is_eq(bucket(xp), bucket(yp)), Bool.not(Time.le(ya, xa)), Time.eq(xa, ya), String.is_le(xi, yi))

# S4.175 (spec twin) `priority`: priority ascending, then `created_at` ascending, then id ascending
def le_by_priority(x: Query.Row, y: Query.Row) -> Bool:
  match x y:
    case Query.Row{+xp, +xa, xt, xi, xo} Query.Row{+yp, +ya, yt, yi, yo}:
      Query.le3((xp < yp : U32), U32.is_eq(xp, yp), Bool.not(Time.le(ya, xa)), Time.eq(xa, ya), String.is_le(xi, yi))

# S4.174–S4.176 (spec twin) the candidates under a sort policy: 0 hybrid, 1 priority, 2 oldest (the `created_at`
# ascending order of core/query)
def ready_sorted(+rows: List<&2, Query.Row>, policy: U32) -> List<&2, Query.Row>:
  match policy:
    case 0:
      List.sort(~Query.Row, ~le_hybrid, rows)
    case 1:
      List.sort(~Query.Row, ~le_by_priority, rows)
    case _:
      List.sort(~Query.Row, ~Query.le_oldest, rows)

# S4.174–S4.176 (spec twin) the sort policy of `--sort`: hybrid unless it says `priority` or `oldest` (the argument
# parser refuses any other word, S1.78)
def policy_of(given: Maybe<&2, String>) -> U32:
  match given:
    case None{}:
      0
    case Some{+word}:
      Bool.pick(U32, String.eq(word, "priority"), 1, Bool.pick(U32, String.eq(word, "oldest"), 2, 0))

# S4.171–S4.176 (spec twin) the ready issues of a store, filtered and ordered, before any limit
def ready_issues(+all: List<&2, Model.Issue>, now: Maybe<&2, Time.Instant>, with_deferred: Bool, assignee: Maybe<&2, String>, unassigned: Bool, labels_all: List<&2, String>, labels_any: List<&2, String>, types: List<&2, String>, priorities: List<&2, U32>, policy: U32) -> List<&2, Model.Issue>:
  Query.issues_of(ready_sorted(Query.rows_of(ready_kept(candidates(all, Blocked.keys(Blocked.relation(all)), now, with_deferred), assignee, unassigned, labels_all, labels_any, types, priorities), 1), policy))

# S4.178 (spec twin) does the store hold any issue that is neither terminal nor a template
def any_active(issues: List<&2, Model.Issue>) -> Bool:
  match issues:
    case Nil{}:
      False{}
    case Con{+i, rest}:
      ((Bool.not(Blocked.terminal(Model.status_of(i))) && Bool.not(Model.is_template(i))) || any_active(rest))

# ---------------------------------------------------------------- stats (S4.151–S4.156)

# S4.151 (data) the figures of `stats`, and the closed issues' whole lead-time hours: their sum and how many there are
type Figures is Data:
  Figures{total: U32, open: U32, in_progress: U32, closed: U32, blocked: U32, deferred: U32, draft: U32, ready: U32, tombstone: U32, pinned: U32, epics: U32, lead_sum: U32, lead_count: U32}

# S4.151 (spec twin) how many issues have exactly this stored status
def with_status(issues: List<&2, Model.Issue>, +status: String, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{i, rest}:
      with_status(rest, status, (acc + Bool.to_u32(String.eq(Model.status_of(i), status)) : U32))

# S4.151 (spec twin) how many issues carry the pinned marker or the status `pinned`
def pinned_count(issues: List<&2, Model.Issue>, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{+i, rest}:
      pinned_count(rest, (acc + Bool.to_u32((Model.is_pinned(i) || String.eq(Model.status_of(i), "pinned"))) : U32))

# S4.154 (spec twin) whole hours from `created_at` to `closed_at`, truncated toward zero; 0 when the close is not after the creation
def whole_hours(from: Time.Instant, to: Time.Instant) -> U32:
  match from to:
    case Time.Instant{+fd, +fs, fn} Time.Instant{+td, +ts, tn}:
      Bool.pick(U32, Time.le(Time.Instant{td, ts, 0}, Time.Instant{fd, fs, 0}), 0, ((((((td - fd : U32) * 86400 : U32) + ts : U32) - fs : U32)) / 3600 : U32))

# S4.154 (spec twin) the lead time of one issue joins the sum when it is `closed` and carries a `closed_at`
def lead_of(closed: Bool, from: Time.Instant, to: Maybe<&2, Time.Instant>) -> Maybe<&2, U32>:
  match closed to:
    case True{} Some{at}:
      Some{whole_hours(from, at)}
    case _ _:
      None{}

# S4.154 (data) a running sum and count
type Tally is Data:
  Tally{sum: U32, count: U32}

# S4.154 (spec twin) add one lead time, when there is one
def tally_lead(t: Tally, lead: Maybe<&2, U32>) -> Tally:
  match t lead:
    case Tally{sum, count} Some{hours}:
      Tally{(sum + hours : U32), (count + 1 : U32)}
    case Tally{sum, count} None{}:
      Tally{sum, count}

# S4.154 (spec twin) the lead times of every closed issue with a `closed_at`
def leads(issues: List<&2, Model.Issue>, t: Tally) -> Tally:
  match issues:
    case Nil{}:
      t
    case Con{+i, rest}:
      leads(rest, tally_lead(t, lead_of(String.eq(Model.status_of(i), "closed"), Model.created_of(i), Model.closed_of(i))))

# S4.152 (spec twin) keep a key whose issue is stored and not terminal
def live_put(id: String, found: Maybe<&2, Model.Issue>, +rest: List<&2, String>) -> List<&2, String>:
  match found:
    case None{}:
      rest
    case Some{i}:
      Bool.pick(List<&2, String>, Blocked.terminal(Model.status_of(i)), rest, id <> rest)

# S4.152 (spec twin) the ids of the relation's keys whose issue is stored and not terminal
def live_keys(ids: List<&2, String>, +all: List<&2, Model.Issue>) -> List<&2, String>:
  match ids:
    case Nil{}:
      Nil{}
    case Con{+id, rest}:
      live_put(id, Blocked.lookup(all, id), live_keys(rest, all))

# S4.152 (spec twin) the issues whose stored status is literally `blocked` and that are not already counted
def stored_blocked(issues: List<&2, Model.Issue>, +counted: List<&2, String>, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{+i, rest}:
      stored_blocked(rest, counted, (acc + Bool.to_u32((String.eq(Model.status_of(i), "blocked") && Bool.not(Blocked.among(counted, Model.id_of(i))))) : U32))

# S4.190 (data) the children of one epic: how many, and how many of them are closed or tombstoned
type Children is Data:
  Children{total: U32, closed: U32}

# S4.190 (spec twin) one issue against an epic: each of its `parent-child` edges to the epic counts it as a child, unless it is a template
def child_edges(edges: List<&2, Model.Dependency>, +epic: String, +counts: Bool, +closed: Bool, c: Children) -> Children:
  match edges c:
    case Nil{} Children{total, done}:
      Children{total, done}
    case Con{+e, rest} Children{total, done}:
      child_edges(rest, epic, counts, closed, Children{(total + Bool.to_u32((counts && String.eq(Model.dep_type_of(e), "parent-child") && String.eq(Model.target_of(e), epic))) : U32), (done + Bool.to_u32((counts && closed && String.eq(Model.dep_type_of(e), "parent-child") && String.eq(Model.target_of(e), epic))) : U32)})

# S4.190 (spec twin) the direct children of an epic over the whole store
def children(issues: List<&2, Model.Issue>, +epic: String, c: Children) -> Children:
  match issues:
    case Nil{}:
      c
    case Con{+i, rest}:
      children(rest, epic, child_edges(Model.deps_of(i), epic, Bool.not(Model.is_template(i)), Blocked.terminal(Model.status_of(i)), c))

# S4.191 (spec twin) an epic may close when it has children and all of them are closed
def eligible(c: Children) -> Bool:
  match c:
    case Children{+total, done}:
      ((total > 0 : U32) && U32.is_eq(done, total))

# S4.155 (spec twin) the epics that are live, not templates, and eligible
def eligible_epics(issues: List<&2, Model.Issue>, +all: List<&2, Model.Issue>, acc: U32) -> U32:
  match issues:
    case Nil{}:
      acc
    case Con{+i, rest}:
      eligible_epics(rest, all, (acc + Bool.to_u32((String.eq(Model.type_of(i), "epic") && Bool.not(Blocked.terminal(Model.status_of(i))) && Bool.not(Model.is_template(i)) && eligible(children(all, Model.id_of(i), Children{0, 0})))) : U32))

# S4.151–S4.155 (spec twin) the figures from their parts: `live` is the live keys of the BLOCKED relation, `t` the
# lead times, `ready` the number of ready issues. `total` leaves the tombstones out
def figures_of(+all: List<&2, Model.Issue>, +live: List<&2, String>, t: Tally, ready: U32) -> Figures:
  match t:
    case Tally{sum, count}:
      Figures{(U32.from_nat(List.length(&2, Model.Issue, all)) - with_status(all, "tombstone", 0) : U32), with_status(all, "open", 0), with_status(all, "in_progress", 0), with_status(all, "closed", 0), stored_blocked(all, live, U32.from_nat(List.length(&2, String, live))), with_status(all, "deferred", 0), with_status(all, "draft", 0), ready, with_status(all, "tombstone", 0), pinned_count(all, 0), eligible_epics(all, all, 0), sum, count}

# S4.154 S5.54 S5.170 (data) the average lead time as `stats` prints it: none; one the port cannot print yet
# (not a whole number of tenths: OQ-078); or its plain text with the unit and its JSON number
type Lead is Data:
  NoLead{}
  LeadBad{}
  LeadOk{plain: String, json: String}

# S5.54 S5.170 (spec twin) a whole number of tenths as `N.d`
def tenths_text(+q: U32) -> String:
  U32.show((q / 10 : U32)) ++ "." ++ U32.show((q % 10 : U32))

# S5.170 (spec twin) where the remainder of a division sits against half of the divisor: 0 below, 1 exactly half,
# 2 above
def half_case(+twice: U32, +den: U32) -> U32:
  Bool.pick(U32, U32.is_eq(twice, den), 1, Bool.pick(U32, (twice < den : U32), 0, 2))

# S5.170 (spec twin) the rounded tenths, ties to even (Rust's `{:.1}`). A tie is decided only when the value is
# one binary64 holds exactly, which for a half of a tenth means `.25` or `.75` (the tenths digit 2 or 7): any
# other tie is a value binary64 rounds first, which the port cannot follow yet (OQ-078)
def rounded_tenths(+q0: U32, side: U32, dyadic: Bool, even: Bool) -> Maybe<&2, U32>:
  match side:
    case 0:
      Some{q0}
    case 2:
      Some{(q0 + 1 : U32)}
    case _:
      Bool.pick(Maybe<&2, U32>, dyadic, Bool.pick(Maybe<&2, U32>, even, Some{q0}, Some{(q0 + 1 : U32)}), None{})

# S5.170 (spec twin) `num / den` in tenths as the original prints it. Away from a tie the exact ratio and the
# binary64 the original rounds first fall on the same side of the boundary: the ratio's distance to the nearest
# half-tenth is at least 1/(20·den), which for a store of fewer than 100000 closed issues is far above the
# 1 ulp of a mean under 1000000 hours
def tenths(+num: U32, +den: U32) -> Maybe<&2, U32>:
  rounded_tenths((num / den : U32), half_case(((num % den : U32) * 2 : U32), den), U32.is_eq(((num / den : U32) % 5 : U32), 2), U32.is_eq(((num / den : U32) % 2 : U32), 0))

# S5.170 (spec twin) the plain form: hours under 24, days from 24 hours on, one fractional digit each
def lead_plain(+hours_q: U32, in_hours: Bool, days_q: Maybe<&2, U32>) -> Lead:
  match in_hours days_q:
    case True{} _:
      LeadOk{tenths_text(hours_q) ++ " hours", tenths_text(hours_q)}
    case False{} Some{+q}:
      LeadOk{tenths_text(q) ++ " days", tenths_text(hours_q)}
    case False{} None{}:
      LeadBad{}

# S4.154 S5.54 S5.170 (spec twin) the average of the whole-hour lead times. The JSON number is printed as tenths,
# so a mean of hours that is not a whole number of tenths is still refused (it would need binary64's shortest
# round-trip form: OQ-078); the plain days figure is rounded to tenths
def lead_of_sum(+sum: U32, +count: U32, none: Bool, exact: Bool) -> Lead:
  match none exact:
    case True{} _:
      NoLead{}
    case False{} False{}:
      LeadBad{}
    case False{} True{}:
      lead_plain(((sum * 10 : U32) / count : U32), (sum < (count * 24 : U32) : U32), tenths((sum * 10 : U32), (count * 24 : U32)))

# S4.154 (spec twin) the average lead time of the figures; a count of zero is guarded before any division
def lead(f: Figures) -> Lead:
  match f:
    case Figures{total, open, in_progress, closed, blocked, deferred, draft, ready, tombstone, pinned, epics, +lead_sum, +lead_count}:
      lead_of_sum(lead_sum, U32.max(lead_count, 1), U32.is_eq(lead_count, 0), U32.is_eq(((lead_sum * 10 : U32) % U32.max(lead_count, 1) : U32), 0))

# S4.151–S4.155 (spec twin) every figure of `stats`
def figures(+all: List<&2, Model.Issue>, now: Maybe<&2, Time.Instant>) -> Figures:
  figures_of(all, live_keys(Blocked.keys(Blocked.relation(all)), all), leads(all, Tally{0, 0}), U32.from_nat(List.length(&2, Model.Issue, candidates(all, Blocked.keys(Blocked.relation(all)), now, False{}))))

