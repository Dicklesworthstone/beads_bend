# core/model — the data model (S3.1–S3.15) and the store line of one issue (S5.2–S5.11).
# The 44 serialized members are grouped into small records so that no pattern
# is 44 wide; their ORDER on the wire is fixed by `line`, not by the grouping.
# Integers are decimal digit strings (docs/NUMERIC_PLAN.md: a file may hold any
# i64); instants are core/time's; open-set strings stay String (S3.7–S3.9).
# The repetitive parts of this file were produced once by a script; this file,
# not the script, is the source. Nothing here consults the original.
import Base
import ./time.bend as Time
import ./failure.bend as Failure

# S3.1 (data) the `Head` members of an issue
type Head is Data:
  Head{id: String, title: String, status: String, priority: String, issue_type: String}

# S3.1 (data) the `Texts` members of an issue
type Texts is Data:
  Texts{description: Maybe<&2, String>, design: Maybe<&2, String>, acceptance_criteria: Maybe<&2, String>, prerequisites: Maybe<&2, String>, notes: Maybe<&2, String>}

# S3.1 (data) the `People` members of an issue
type People is Data:
  People{assignee: Maybe<&2, String>, owner: Maybe<&2, String>, created_by: Maybe<&2, String>, sender: Maybe<&2, String>}

# S3.1 (data) the `Times` members of an issue
type Times is Data:
  Times{created_at: Time.Instant, updated_at: Time.Instant, closed_at: Maybe<&2, Time.Instant>, due_at: Maybe<&2, Time.Instant>, defer_until: Maybe<&2, Time.Instant>, deleted_at: Maybe<&2, Time.Instant>, compacted_at: Maybe<&2, Time.Instant>}

# S3.1 (data) the `Closing` members of an issue
type Closing is Data:
  Closing{close_reason: Maybe<&2, String>, closed_by_session: Maybe<&2, String>, bypassed_policy: Maybe<&2, Bool>, bypass_reason: Maybe<&2, String>, policy_gates_fired: Maybe<&2, List<&2, String>>}

# S3.1 (data) the `Source` members of an issue
type Source is Data:
  Source{external_ref: Maybe<&2, String>, source_system: Maybe<&2, String>, source_repo: Maybe<&2, String>, source_repo_path: Maybe<&2, String>, agent_context: Maybe<&2, String>}

# S3.1 (data) the `Deletion` members of an issue
type Deletion is Data:
  Deletion{deleted_by: Maybe<&2, String>, delete_reason: Maybe<&2, String>, original_type: Maybe<&2, String>}

# S3.1 (data) the `Compaction` members of an issue
type Compaction is Data:
  Compaction{compaction_level: Maybe<&2, String>, compacted_at_commit: Maybe<&2, String>, original_size: Maybe<&2, String>}

# S3.1 (data) the `Meta` members of an issue
type Meta is Data:
  Meta{estimated_minutes: Maybe<&2, String>}

# S3.1 (data) the `Flags` members of an issue
type Flags is Data:
  Flags{ephemeral: Bool, pinned: Bool, is_template: Bool}

# S3.5 (data) a dependency: seven members in this order; the last three optional
type Dependency is Data:
  Dependency{issue_id: String, depends_on_id: String, dep_type: String, created_at: Time.Instant, created_by: Maybe<&2, String>, metadata: Maybe<&2, String>, thread_id: Maybe<&2, String>}

# S3.6 (data) a comment: five members, all always present; the id is a decimal digit string
type Comment is Data:
  Comment{id: String, issue_id: String, author: String, text: String, created_at: Time.Instant}

# S3.1 S3.4 (data) an issue: the ten groups and the three collections
type Issue is Data:
  Issue{head: Head, texts: Texts, people: People, times: Times, closing: Closing, source: Source, deletion: Deletion, compaction: Compaction, meta: Meta, flags: Flags, labels: List<&2, String>, dependencies: List<&2, Dependency>, comments: List<&2, Comment>}

# S2.28 (spec twin) the record before any member is read: status `open`, priority `2`, type `task`,
# every optional absent, every flag false, every collection empty
def blank() -> Issue:
  Issue{Head{"", "", "open", "2", "task"}, Texts{None{}, None{}, None{}, None{}, None{}}, People{None{}, None{}, None{}, None{}}, Times{Time.Instant{0, 0, 0}, Time.Instant{0, 0, 0}, None{}, None{}, None{}, None{}, None{}}, Closing{None{}, None{}, None{}, None{}, None{}}, Source{None{}, None{}, None{}, None{}, None{}}, Deletion{None{}, None{}, None{}}, Compaction{None{}, None{}, None{}}, Meta{None{}}, Flags{False{}, False{}, False{}}, Nil{}, Nil{}, Nil{}}

# S5.2 (spec twin) `"key":` then a JSON string
def m_str(key: String, value: String) -> String:
  Failure.quoted(key) ++ ":" ++ Failure.quoted(value)

# S5.11 (spec twin) `"key":` then a bare integer (a digit string, written verbatim)
def m_int(key: String, digits: String) -> String:
  Failure.quoted(key) ++ ":" ++ digits

# S4.54 (spec twin) `"key":` then an instant, RFC 3339 in UTC with `Z`
def m_time(key: String, at: Time.Instant) -> String:
  Failure.quoted(key) ++ ":" ++ Failure.quoted(Time.print(at, "Z"))

# S5.5 (spec twin) an optional string member: absent writes nothing
def o_str(key: String, value: Maybe<&2, String>) -> String:
  match value:
    case None{}:
      ""
    case Some{text}:
      m_str(key, text)

# S5.5 (spec twin) an optional integer member: absent writes nothing
def o_int(key: String, value: Maybe<&2, String>) -> String:
  match value:
    case None{}:
      ""
    case Some{digits}:
      m_int(key, digits)

# S5.6 (spec twin) an integer member that is ALWAYS written: absent writes the given default
def d_int(key: String, value: Maybe<&2, String>, fallback: String) -> String:
  match value:
    case None{}:
      m_int(key, fallback)
    case Some{digits}:
      m_int(key, digits)

# S5.5 (spec twin) a string member that is ALWAYS written on write-back: absent writes the given default
def d_str(key: String, value: Maybe<&2, String>, fallback: String) -> String:
  match value:
    case None{}:
      m_str(key, fallback)
    case Some{text}:
      m_str(key, text)

# S5.5 (spec twin) an optional instant member
def o_time(key: String, value: Maybe<&2, Time.Instant>) -> String:
  match value:
    case None{}:
      ""
    case Some{at}:
      m_time(key, at)

# S3.3 (spec twin) a flag is written only when true
def o_flag(key: String, value: Bool) -> String:
  match value:
    case True{}:
      Failure.quoted(key) ++ ":true"
    case False{}:
      ""

# S3.1 (spec twin) an optional boolean member
def o_optflag(key: String, value: Maybe<&2, Bool>) -> String:
  match value:
    case None{}:
      ""
    case Some{True{}}:
      Failure.quoted(key) ++ ":true"
    case Some{False{}}:
      Failure.quoted(key) ++ ":false"

# S5.2 (spec twin) JSON strings joined by `,` (compact: no space)
def strings_text(items: List<&2, String>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{item, Nil{}}:
      Failure.quoted(item)
    case Con{item, rest}:
      Failure.quoted(item) ++ "," ++ strings_text(rest)

# S3.4 (spec twin) a collection of strings is written only when non-empty
def o_strings(key: String, items: List<&2, String>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{first, rest}:
      Failure.quoted(key) ++ ":[" ++ strings_text(first <> rest) ++ "]"

# S3.1 (spec twin) an optional list of strings
def o_optlist(key: String, value: Maybe<&2, List<&2, String>>) -> String:
  match value:
    case None{}:
      ""
    case Some{items}:
      Failure.quoted(key) ++ ":[" ++ strings_text(items) ++ "]"

# S5.2 (spec twin) the non-empty parts with a `,` pushed before every part but the first, onto a
# REVERSED list of chunks: an absent member leaves no comma behind, and nothing is re-walked
# (appending to a growing string would walk a long description once per later member)
def chunks(parts: List<&2, String>, acc: List<&2, String>, first: Bool) -> List<&2, String>:
  match parts first:
    case Nil{} _:
      acc
    case Con{SNil{}, rest} still:
      chunks(rest, acc, still)
    case Con{SCon{h, t}, rest} True{}:
      chunks(rest, SCon{h, t} <> acc, False{})
    case Con{SCon{h, t}, rest} False{}:
      chunks(rest, SCon{h, t} <> ("," <> acc), False{})

# S5.2 (spec twin) the non-empty parts joined by `,` (compact: no space), concatenated once
def joined(parts: List<&2, String>) -> String:
  String.concat(List.reverse(&2, String, chunks(parts, Nil{}, True{})))

# S3.5 S5.7 (spec twin) one dependency, seven members in order, the optional ones only when set
def dep_text(d: Dependency) -> String:
  match d:
    case Dependency{issue_id, depends_on_id, dep_type, created_at, created_by, metadata, thread_id}:
      "{" ++ joined([m_str("issue_id", issue_id), m_str("depends_on_id", depends_on_id), m_str("type", dep_type), m_time("created_at", created_at), o_str("created_by", created_by), o_str("metadata", metadata), o_str("thread_id", thread_id)]) ++ "}"

# S3.6 S5.9 (spec twin) one comment, five members in order, all always present
def comment_text(c: Comment) -> String:
  match c:
    case Comment{id, issue_id, author, text, created_at}:
      "{" ++ joined([m_int("id", id), m_str("issue_id", issue_id), m_str("author", author), m_str("text", text), m_time("created_at", created_at)]) ++ "}"

# S5.2 (spec twin) dependencies joined by `,`
def deps_text(items: List<&2, Dependency>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{item, Nil{}}:
      dep_text(item)
    case Con{item, rest}:
      dep_text(item) ++ "," ++ deps_text(rest)

# S5.2 (spec twin) comments joined by `,`
def comments_text(items: List<&2, Comment>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{item, Nil{}}:
      comment_text(item)
    case Con{item, rest}:
      comment_text(item) ++ "," ++ comments_text(rest)

# S3.4 (spec twin) the dependencies member, only when non-empty
def o_deps(items: List<&2, Dependency>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{first, rest}:
      "\"dependencies\":[" ++ deps_text(first <> rest) ++ "]"

# S3.4 (spec twin) the comments member, only when non-empty
def o_comments(items: List<&2, Comment>) -> String:
  match items:
    case Nil{}:
      ""
    case Con{first, rest}:
      "\"comments\":[" ++ comments_text(first <> rest) ++ "]"

# S5.2 S5.4 S5.5 S5.6 (spec twin) the members of one issue, WITHOUT the braces: the 44 members in
# S5.4's fixed order; always present: id, title, status, priority, issue_type, created_at, updated_at,
# compaction_level (0 when unset), source_repo (`.` when unset) and original_size (0 when unset)
def members(i: Issue) -> String:
  match i:
    case Issue{Head{id, title, status, priority, issue_type}, Texts{description, design, acceptance_criteria, prerequisites, notes}, People{assignee, owner, created_by, sender}, Times{created_at, updated_at, closed_at, due_at, defer_until, deleted_at, compacted_at}, Closing{close_reason, closed_by_session, bypassed_policy, bypass_reason, policy_gates_fired}, Source{external_ref, source_system, source_repo, source_repo_path, agent_context}, Deletion{deleted_by, delete_reason, original_type}, Compaction{compaction_level, compacted_at_commit, original_size}, Meta{estimated_minutes}, Flags{ephemeral, pinned, is_template}, labels, dependencies, comments}:
      joined([m_str("id", id), m_str("title", title), o_str("description", description), o_str("design", design), o_str("acceptance_criteria", acceptance_criteria), o_str("prerequisites", prerequisites), o_str("notes", notes), m_str("status", status), m_int("priority", priority), m_str("issue_type", issue_type), o_str("assignee", assignee), o_str("owner", owner), o_int("estimated_minutes", estimated_minutes), m_time("created_at", created_at), o_str("created_by", created_by), m_time("updated_at", updated_at), o_time("closed_at", closed_at), o_str("close_reason", close_reason), o_str("closed_by_session", closed_by_session), o_optflag("bypassed_policy", bypassed_policy), o_str("bypass_reason", bypass_reason), o_optlist("policy_gates_fired", policy_gates_fired), o_time("due_at", due_at), o_time("defer_until", defer_until), o_str("external_ref", external_ref), o_str("source_system", source_system), d_str("source_repo", source_repo, "."), o_str("source_repo_path", source_repo_path), o_str("agent_context", agent_context), o_time("deleted_at", deleted_at), o_str("deleted_by", deleted_by), o_str("delete_reason", delete_reason), o_str("original_type", original_type), d_int("compaction_level", compaction_level, "0"), o_time("compacted_at", compacted_at), o_str("compacted_at_commit", compacted_at_commit), d_int("original_size", original_size, "0"), o_str("sender", sender), o_flag("ephemeral", ephemeral), o_flag("pinned", pinned), o_flag("is_template", is_template), o_strings("labels", labels), o_deps(dependencies), o_comments(comments)])

# S5.2 (spec twin) the store line of one issue, WITHOUT its newline
def line(i: Issue) -> String:
  "{" ++ members(i) ++ "}"

# S5.33 (spec twin) an issue without its own dependency and comment arrays
def without_edges(i: Issue) -> Issue:
  match i:
    case Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, dependencies, comments}:
      Issue{head, texts, people, times, closing, source, deletion, compaction, meta, flags, labels, Nil{}, Nil{}}

# S5.33 (spec twin) an element of `list --json`: the issue's own members (labels kept, its dependency and
# comment arrays left out), then `dependency_count` and `dependent_count`, both always present
def listed(i: Issue, dependency_count: U32, dependent_count: U32) -> String:
  "{" ++ members(without_edges(i)) ++ ",\"dependency_count\":" ++ U32.show(dependency_count) ++ ",\"dependent_count\":" ++ U32.show(dependent_count) ++ "}"

# S4.220 S5.5 (spec twin) the record `create` makes when no flag is given: status `open`, priority `2`,
# type `task`, the creator, one instant for created_at and updated_at (S4.52), and the workspace's
# directory name and absolute path as source_repo and source_repo_path
def fresh(id: String, title: String, creator: String, +at: Time.Instant, repo: String, repo_path: String) -> Issue:
  Issue{Head{id, title, "open", "2", "task"}, Texts{None{}, None{}, None{}, None{}, None{}}, People{None{}, None{}, Some{creator}, None{}}, Times{at, at, None{}, None{}, None{}, None{}, None{}}, Closing{None{}, None{}, None{}, None{}, None{}}, Source{None{}, None{}, Some{repo}, Some{repo_path}, None{}}, Deletion{None{}, None{}, None{}}, Compaction{None{}, None{}, None{}}, Meta{None{}}, Flags{False{}, False{}, False{}}, Nil{}, Nil{}, Nil{}}


# S3.1 (spec twin) an issue's id
def id_of(i: Issue) -> String:
  match i:
    case Issue{Head{id, _, _, _, _}, _, _, _, _, _, _, _, _, _, _, _, _}:
      id

# S3.1 (spec twin) an issue's title
def title_of(i: Issue) -> String:
  match i:
    case Issue{Head{_, title, _, _, _}, _, _, _, _, _, _, _, _, _, _, _, _}:
      title

# S3.1 (spec twin) an issue's stored status string
def status_of(i: Issue) -> String:
  match i:
    case Issue{Head{_, _, status, _, _}, _, _, _, _, _, _, _, _, _, _, _, _}:
      status

# S3.1 (spec twin) an issue's priority, as its digits
def priority_of(i: Issue) -> String:
  match i:
    case Issue{Head{_, _, _, priority, _}, _, _, _, _, _, _, _, _, _, _, _, _}:
      priority

# S3.1 (spec twin) an issue's type string
def type_of(i: Issue) -> String:
  match i:
    case Issue{Head{_, _, _, _, issue_type}, _, _, _, _, _, _, _, _, _, _, _, _}:
      issue_type

# S3.1 (spec twin) an issue's description, when it has one
def description_of(i: Issue) -> Maybe<&2, String>:
  match i:
    case Issue{_, Texts{description, _, _, _, _}, _, _, _, _, _, _, _, _, _, _, _}:
      description

# S3.1 (spec twin) an issue's notes, when it has them
def notes_of(i: Issue) -> Maybe<&2, String>:
  match i:
    case Issue{_, Texts{_, _, _, _, notes}, _, _, _, _, _, _, _, _, _, _, _}:
      notes

# S3.1 (spec twin) an issue's assignee, when it has one
def assignee_of(i: Issue) -> Maybe<&2, String>:
  match i:
    case Issue{_, _, People{assignee, _, _, _}, _, _, _, _, _, _, _, _, _, _}:
      assignee

# S3.1 (spec twin) an issue's owner, when it has one
def owner_of(i: Issue) -> Maybe<&2, String>:
  match i:
    case Issue{_, _, People{_, owner, _, _}, _, _, _, _, _, _, _, _, _, _}:
      owner

# S3.1 (spec twin) when an issue was created
def created_of(i: Issue) -> Time.Instant:
  match i:
    case Issue{_, _, _, Times{created_at, _, _, _, _, _, _}, _, _, _, _, _, _, _, _, _}:
      created_at

# S3.1 (spec twin) when an issue was last updated
def updated_of(i: Issue) -> Time.Instant:
  match i:
    case Issue{_, _, _, Times{_, updated_at, _, _, _, _, _}, _, _, _, _, _, _, _, _, _}:
      updated_at

# S3.1 (spec twin) when an issue is due, when it says
def due_of(i: Issue) -> Maybe<&2, Time.Instant>:
  match i:
    case Issue{_, _, _, Times{_, _, _, due_at, _, _, _}, _, _, _, _, _, _, _, _, _}:
      due_at

# S3.1 (spec twin) until when an issue is deferred, when it says
def defer_of(i: Issue) -> Maybe<&2, Time.Instant>:
  match i:
    case Issue{_, _, _, Times{_, _, _, _, defer_until, _, _}, _, _, _, _, _, _, _, _, _}:
      defer_until

# S3.1 S4.103 (spec twin) is the issue a template
def is_template(i: Issue) -> Bool:
  match i:
    case Issue{_, _, _, _, _, _, _, _, _, Flags{_, _, template}, _, _, _}:
      template

# S3.1 (spec twin) an issue's labels, sorted and without duplicates since the load
def labels_of(i: Issue) -> List<&2, String>:
  match i:
    case Issue{_, _, _, _, _, _, _, _, _, _, labels, _, _}:
      labels

# S3.1 (spec twin) an issue's own dependency edges
def deps_of(i: Issue) -> List<&2, Dependency>:
  match i:
    case Issue{_, _, _, _, _, _, _, _, _, _, _, dependencies, _}:
      dependencies

# S3.4 (spec twin) the id an edge points at
def target_of(d: Dependency) -> String:
  match d:
    case Dependency{_, depends_on_id, _, _, _, _, _}:
      depends_on_id

# ---------------------------------------------------------------- the load repairs (S2.31–S2.36, S5.9)

# S2.31 (spec twin) ASCII lower case of one code point
def lower_char(+c: U32, up: Bool) -> U32:
  match up:
    case True{}:
      (c + 32 : U32)
    case False{}:
      c

# S2.31 S2.32 S2.33 (spec twin) a word with the 26 ASCII capitals folded to lower case
def lowered(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{lower_char(c, ((c >= 65 : U32) && (c <= 90 : U32)))}, lowered(rest)}

# S2.31 (spec twin) a status as the model holds it: lower case; `inprogress` is `in_progress`; the five
# words that mean "closed" (trimmed) are `closed`
def status_repaired(+s: String) -> String:
  Bool.pick(String, String.eq(s, "inprogress"), "in_progress", Bool.pick(String, (String.eq(String.trim(s), "done") || String.eq(String.trim(s), "complete") || String.eq(String.trim(s), "completed") || String.eq(String.trim(s), "finished") || String.eq(String.trim(s), "resolved")), "closed", s))

# S5.9 (spec twin) an optional string that is present but empty is "not set" in the model
def unblank(value: Maybe<&2, String>) -> Maybe<&2, String>:
  match value:
    case Some{SNil{}}:
      None{}
    case other:
      other

# S2.36 (spec twin) `external_ref` is trimmed, and "not set" when nothing is left
def ref_repaired(value: Maybe<&2, String>) -> Maybe<&2, String>:
  match value:
    case None{}:
      None{}
    case Some{text}:
      unblank(Some{String.trim(text)})

# S2.36 (spec twin) keep a word unless the next one equals it
def dedup_put(a: String, same: Bool, rest: List<&2, String>) -> List<&2, String>:
  match same:
    case True{}:
      rest
    case False{}:
      a <> rest

# S2.36 (spec twin) adjacent equal words collapse to one
def dedup(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Con{+a, Con{+b, rest}}:
      dedup_put(a, String.eq(a, b), dedup(b <> rest))
    case other:
      other

# S2.36 (spec twin) labels in ascending byte order, each once
def labels_repaired(labels: List<&2, String>) -> List<&2, String>:
  dedup(List.sort(~String, ~String.is_le, labels))

# S3.9 (data) the eleven dependency types
def known_dep_types() -> List<&2, String>:
  ["blocks", "parent-child", "conditional-blocks", "waits-for", "related", "discovered-from", "replies-to", "relates-to", "duplicates", "supersedes", "caused-by"]

# S2.33 (spec twin) is this word in the list
def listed_word(xs: List<&2, String>, +x: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{y, rest}:
      (String.eq(y, x) || listed_word(rest, x))

# S2.33 (spec twin) every `_` written `-`
def dashed(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{95}, rest}:
      SCon{Chr{45}, dashed(rest)}
    case SCon{c, rest}:
      SCon{c, dashed(rest)}

# S2.33 (spec twin) a dependency type as the model holds it: lower case, and when that is not one of the eleven, its
# `_` written `-` provided THAT is one of the eleven
def dep_type_repaired(+t: String) -> String:
  Bool.pick(String, (Bool.not(listed_word(known_dep_types(), lowered(t))) && listed_word(known_dep_types(), dashed(lowered(t)))), dashed(lowered(t)), lowered(t))

# S2.33 S2.37 (spec twin) one edge repaired: its type, and a blank `metadata` is "not set"
def dep_repaired(d: Dependency) -> Dependency:
  match d:
    case Dependency{issue_id, depends_on_id, dep_type, created_at, created_by, metadata, thread_id}:
      Dependency{issue_id, depends_on_id, dep_type_repaired(dep_type), created_at, created_by, metadata, thread_id}

# S2.36 (spec twin) every edge repaired, in file order
def deps_repaired(ds: List<&2, Dependency>) -> List<&2, Dependency>:
  match ds:
    case Nil{}:
      Nil{}
    case Con{d, rest}:
      dep_repaired(d) <> deps_repaired(rest)

# S2.36 (spec twin) do two edges share `(issue_id, depends_on_id, type)`
def same_edge(a: Dependency, b: Dependency) -> Bool:
  match a b:
    case Dependency{ai, ad, at, _, _, _, _} Dependency{bi, bd, bt, _, _, _, _}:
      (String.eq(ai, bi) && String.eq(ad, bd) && String.eq(at, bt))

# S3.4 (spec twin) when an edge was made
def dep_at(d: Dependency) -> Time.Instant:
  match d:
    case Dependency{_, _, _, created_at, _, _, _}:
      created_at

# S2.36 (spec twin) does an EARLIER edge with the same key beat this one: it does when it is at least as new
def beaten_before(before: List<&2, Dependency>, +d: Dependency) -> Bool:
  match before:
    case Nil{}:
      False{}
    case Con{+e, rest}:
      ((same_edge(e, d) && Time.le(dep_at(d), dep_at(e))) || beaten_before(rest, d))

# S2.36 (spec twin) does a LATER edge with the same key beat this one: only when it is strictly newer
def beaten_after(after: List<&2, Dependency>, +d: Dependency) -> Bool:
  match after:
    case Nil{}:
      False{}
    case Con{+e, rest}:
      ((same_edge(e, d) && Bool.not(Time.le(dep_at(e), dep_at(d)))) || beaten_after(rest, d))

# S2.36 (spec twin) keep an edge that nothing beats
def edge_keep(d: Dependency, beaten: Bool, rest: List<&2, Dependency>) -> List<&2, Dependency>:
  match beaten:
    case True{}:
      rest
    case False{}:
      d <> rest

# S2.36 (spec twin) duplicate edges collapse to the newest, the first winning a tie; survivors keep their file order.
# `before` is the edges already passed (any order)
def edges_collapsed(ds: List<&2, Dependency>, +before: List<&2, Dependency>) -> List<&2, Dependency>:
  match ds:
    case Nil{}:
      Nil{}
    case Con{+d, +rest}:
      edge_keep(d, (beaten_before(before, d) || beaten_after(rest, d)), edges_collapsed(rest, d <> before))

# S2.36 (spec twin) are two comments the same in every member
def same_comment(a: Comment, b: Comment) -> Bool:
  match a b:
    case Comment{ai, aq, aa, ax, at} Comment{bi, bq, ba, bx, bt}:
      (String.eq(ai, bi) && String.eq(aq, bq) && String.eq(aa, ba) && String.eq(ax, bx) && Time.eq(at, bt))

# S2.36 (spec twin) was this comment already seen
def comment_seen(seen: List<&2, Comment>, +c: Comment) -> Bool:
  match seen:
    case Nil{}:
      False{}
    case Con{s, rest}:
      (same_comment(s, c) || comment_seen(rest, c))

# S2.36 (spec twin) keep a comment that was not seen
def comment_keep(c: Comment, seen: Bool, rest: List<&2, Comment>) -> List<&2, Comment>:
  match seen:
    case True{}:
      rest
    case False{}:
      c <> rest

# S2.36 (spec twin) identical comments collapse to their first occurrence
def comments_collapsed(cs: List<&2, Comment>, +seen: List<&2, Comment>) -> List<&2, Comment>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{+c, rest}:
      comment_keep(c, comment_seen(seen, c), comments_collapsed(rest, c <> seen))

# S2.36 (spec twin) a `closed` or `tombstone` record without `closed_at` gains its `updated_at`; any other record's `closed_at` is discarded
def closed_at_repaired(terminal: Bool, closed_at: Maybe<&2, Time.Instant>, updated_at: Time.Instant) -> Maybe<&2, Time.Instant>:
  match terminal closed_at:
    case False{} _:
      None{}
    case True{} None{}:
      Some{updated_at}
    case True{} Some{at}:
      Some{at}

# S2.36 (spec twin) an `updated_at` earlier than `created_at` is raised to it
def updated_repaired(+created_at: Time.Instant, +updated_at: Time.Instant) -> Time.Instant:
  Bool.pick(Time.Instant, Time.le(created_at, updated_at), updated_at, created_at)

# S2.36 (spec twin) the times of a record once its repaired status is known
def times_repaired(t: Times, terminal: Bool) -> Times:
  match t:
    case Times{+created_at, +updated_at, closed_at, due_at, defer_until, deleted_at, compacted_at}:
      Times{created_at, updated_repaired(created_at, updated_at), closed_at_repaired(terminal, closed_at, updated_repaired(created_at, updated_at)), due_at, defer_until, deleted_at, compacted_at}

# S2.31 S2.32 S2.36 S5.9 (spec twin) the record as the loaded model holds it: every repair of S2.36 in order, and
# every optional string that is present but empty made "not set", except `compacted_at_commit`
def repaired_status(i: Issue, +status: String) -> Issue:
  match i:
    case Issue{Head{+id, title, _, priority, issue_type}, Texts{description, design, acceptance_criteria, prerequisites, notes}, People{assignee, owner, created_by, sender}, times, Closing{close_reason, closed_by_session, bypassed_policy, bypass_reason, policy_gates_fired}, Source{external_ref, source_system, source_repo, source_repo_path, agent_context}, Deletion{deleted_by, delete_reason, original_type}, compaction, meta, Flags{ephemeral, pinned, template}, labels, dependencies, comments}:
      Issue{Head{id, title, status, priority, lowered(issue_type)}, Texts{unblank(description), unblank(design), unblank(acceptance_criteria), unblank(prerequisites), unblank(notes)}, People{unblank(assignee), unblank(owner), unblank(created_by), unblank(sender)}, times_repaired(times, (String.eq(status, "closed") || String.eq(status, "tombstone"))), Closing{unblank(close_reason), unblank(closed_by_session), bypassed_policy, bypass_reason, policy_gates_fired}, Source{ref_repaired(external_ref), unblank(source_system), unblank(source_repo), unblank(source_repo_path), unblank(agent_context)}, Deletion{unblank(deleted_by), unblank(delete_reason), unblank(original_type)}, compaction, meta, Flags{(ephemeral || String.contains(id, "-wisp-")), pinned, template}, labels_repaired(labels), edges_collapsed(deps_repaired(dependencies), Nil{}), comments_collapsed(comments, Nil{})}

# S2.36 (spec twin) the record as the loaded model holds it
def repaired(+i: Issue) -> Issue:
  repaired_status(i, status_repaired(lowered(status_of(i))))

# S2.42 (spec twin) is the record ephemeral: it is parsed and counted, then dropped before any storage work
def is_ephemeral(i: Issue) -> Bool:
  match i:
    case Issue{_, _, _, _, _, _, _, _, _, Flags{ephemeral, _, _}, _, _, _}:
      ephemeral
