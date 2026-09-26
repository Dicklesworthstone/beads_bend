# core/surface — the command-line surface as DATA (S1.3, S1.16, S1.31–S1.54).
# What each command accepts: its options (long name, short letter, visible
# alias, value placeholder, whether it repeats, whether its value is optional,
# whether the value may begin with `-`, how the value is checked by the
# argument parser), its positionals, the pairs that exclude each other, and
# its subcommand words. core/cli.bend is the algorithm that reads these tables;
# nothing here decides anything. Nothing here consults the original.
import Base

# S1.21 S1.22 S1.23 (data) how the argument parser itself checks a value:
# not at all; as an unsigned 64-bit integer; as a signed 64-bit integer that
# must then lie in a range (magnitudes as digit strings, plus the lower bound
# as the message prints it); or as one of a fixed list of words
type Check is Data:
  Free{}
  Unsigned{}
  Ranged{lo_mag: String, hi_mag: String, lo_text: String}
  Choice{values: List<&2, String>}

# S1.3 S1.31 (data) one option. `short` is a code point (0 = none), `alias` a second long
# name ("" = none), `value` the placeholder the messages print ("" = the option takes no value)
type Opt is Data:
  Opt{key: String, short: U32, alias: String, value: String, repeat: Bool, optional: Bool, hyphen: Bool, check: Check}

# S1.24 (data) one positional: the placeholder, whether it is required, whether it collects every remaining word
type Pos is Data:
  Pos{name: String, required: Bool, many: Bool}

# S1.35 S1.36 S1.39 S1.46 S1.49 (data) two arguments that exclude each other (an option's key, or a positional's placeholder)
type Clash is Data:
  Clash{a: String, b: String}

# S1.16 S1.51 (data) a subcommand word. `target` is the index `cmd_at` answers to.
# `scope`: 0 = in the port's surface, 1 = a command of the original outside it (PLAN §3), 2 = `help`
type Name is Data:
  Name{word: String, target: U32, scope: U32}

# S1.1 (data) one level of the command line: the words that lead to it, what it accepts, and
# whether a subcommand must follow
type Cmd is Data:
  Cmd{path: String, opts: List<&2, Opt>, pos: List<&2, Pos>, clashes: List<&2, Clash>, subs: List<&2, Name>, need_sub: Bool}

# S1.21 (spec twin) one character of a placeholder: lower case becomes upper case, `-` becomes `_`
def upper_char(+c: U32, low: Bool, dash: Bool) -> U32:
  match low dash:
    case True{} _:
      (c - 32 : U32)
    case False{} True{}:
      95
    case False{} False{}:
      c

# S1.21 (spec twin) the placeholder derived from a long name: `priority-min` prints as `PRIORITY_MIN`
def placeholder(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, rest}:
      SCon{Chr{upper_char(c, ((c >= 97 : U32) && (c <= 122 : U32)), U32.is_eq(c, 45))}, placeholder(rest)}

# S1.3 (data) an option without a value, given at most once
def flag(key: String) -> Opt:
  Opt{key, 0, "", "", False{}, False{}, False{}, Free{}}

# S1.3 (data) the same with a short letter
def flag_s(key: String, short: U32) -> Opt:
  Opt{key, short, "", "", False{}, False{}, False{}, Free{}}

# S1.31 (data) an option with one free value, given at most once
def one(+key: String) -> Opt:
  Opt{key, 0, "", placeholder(key), False{}, False{}, False{}, Free{}}

# S1.31 (data) the same with a short letter
def one_s(+key: String, short: U32) -> Opt:
  Opt{key, short, "", placeholder(key), False{}, False{}, False{}, Free{}}

# S1.13 (data) an option with a free value that accumulates
def many(+key: String) -> Opt:
  Opt{key, 0, "", placeholder(key), True{}, False{}, False{}, Free{}}

# S1.13 (data) the same with a short letter
def many_s(+key: String, short: U32) -> Opt:
  Opt{key, short, "", placeholder(key), True{}, False{}, False{}, Free{}}

# S1.21 (data) an option whose one value the parser checks
def checked(+key: String, check: Check) -> Opt:
  Opt{key, 0, "", placeholder(key), False{}, False{}, False{}, check}

# S1.36 (data) an option whose placeholder is not derived from its name
def named(key: String, short: U32, value: String, repeat: Bool) -> Opt:
  Opt{key, short, "", value, repeat, False{}, False{}, Free{}}

# S1.36 S1.42 (data) an option whose value may begin with `-`, with its short letter and alias
def dashed(+key: String, short: U32, alias: String) -> Opt:
  Opt{key, short, alias, placeholder(key), False{}, False{}, True{}, Free{}}

# S1.87 (data) an option whose value may begin with `-`, with a placeholder not derived from its name
def named_dashed(key: String, short: U32, value: String, repeat: Bool) -> Opt:
  Opt{key, short, "", value, repeat, False{}, True{}, Free{}}

# S1.22 (data) an 8-bit unsigned value
def u8() -> Check:
  Ranged{"0", "255", "0"}

# S1.48 (data) a 32-bit unsigned value
def u32() -> Check:
  Ranged{"0", "4294967295", "0"}

# S1.36 (data) a 32-bit signed value
def i32() -> Check:
  Ranged{"2147483648", "2147483647", "-2147483648"}

# S1.23 (data) the output formats `list` and `search` name
def formats_list() -> Check:
  Choice{"text" <> "json" <> "csv" <> "toon" <> Nil{}}

# S1.23 S1.35 (data) the output formats every other command names
def formats() -> Check:
  Choice{"text" <> "json" <> "toon" <> Nil{}}

# S1.23 S1.51 (data) the directions of `dep list` and `dep tree`
def directions() -> Check:
  Choice{"down" <> "up" <> "both" <> Nil{}}

# S1.3 (data) the twelve global options, in declaration order; every level accepts them
def globals() -> List<&2, Opt>:
  one("db") <> one("actor") <> flag("json") <> flag("no-daemon") <> flag("no-auto-flush") <> flag("no-auto-import") <> flag("allow-stale") <> checked("lock-timeout", Unsigned{}) <> flag("no-db") <> Opt{"verbose", 118, "", "", True{}, False{}, False{}, Free{}} <> flag_s("quiet", 113) <> flag("no-color") <> Nil{}

# S1.29 (data) `-h`/`--help` exists on every level
def help_opt() -> Opt:
  flag_s("help", 104)

# S1.29 (data) `-V`/`--version` exists on the top level only
def version_opt() -> Opt:
  flag_s("version", 86)

# S1.36 S1.42 (data) the three attribution options
def attribution() -> List<&2, Opt>:
  named("agent-name", 0, "NAME", False{}) <> one("harness") <> one("model") <> Nil{}

# S1.31 (data) the options of `list`, which `search` shares (S1.34)
def list_opts() -> List<&2, Opt>:
  many_s("status", 115) <> many_s("type", 116) <> one("assignee") <> flag("unassigned") <> many("id") <> many_s("label", 108) <> many("label-any") <> many_s("priority", 112) <> checked("priority-min", u8()) <> checked("priority-max", u8()) <> one("title-contains") <> one("desc-contains") <> one("notes-contains") <> flag_s("all", 97) <> checked("limit", Unsigned{}) <> checked("offset", Unsigned{}) <> one("sort") <> flag_s("reverse", 114) <> flag("deferred") <> flag("overdue") <> flag("long") <> flag("pretty") <> flag("tree") <> flag("wrap") <> checked("format", formats_list()) <> flag("stats") <> one("fields") <> Nil{}

# S1.36 (data) the options of `create`
def create_opts() -> List<&2, Opt>:
  named("title", 0, "TITLE_FLAG", False{}) <> one_s("type", 116) <> one("slug") <> one_s("priority", 112) <> dashed("description", 100, "body") <> named("description-file", 0, "PATH", False{}) <> one_s("assignee", 97) <> one("owner") <> many_s("labels", 108) <> one("parent") <> many("deps") <> Opt{"estimate", 101, "", "ESTIMATE", False{}, False{}, False{}, i32()} <> one("due") <> one("defer") <> one("external-ref") <> flag("ephemeral") <> one_s("status", 115) <> dashed("acceptance-criteria", 0, "acceptance") <> dashed("prerequisites", 0, "") <> one("agent-context") <> flag("dry-run") <> flag("silent") <> one_s("file", 102) <> attribution()

# S1.38 (data) the options of `q`
def q_opts() -> List<&2, Opt>:
  one_s("priority", 112) <> one_s("type", 116) <> many_s("labels", 108) <> dashed("description", 100, "body") <> one("parent") <> Opt{"estimate", 101, "", "ESTIMATE", False{}, False{}, False{}, i32()} <> Nil{}

# S1.39 (data) the options of `update`
def update_opts() -> List<&2, Opt>:
  one("title") <> dashed("description", 100, "body") <> named("description-file", 0, "PATH", False{}) <> dashed("design", 0, "") <> Opt{"acceptance-criteria", 0, "acceptance", "ACCEPTANCE_CRITERIA", False{}, False{}, True{}, Free{}} <> dashed("prerequisites", 0, "") <> named_dashed("check-acceptance", 0, "ITEMS", True{}) <> named_dashed("uncheck-acceptance", 0, "ITEMS", True{}) <> named_dashed("add-acceptance", 0, "TEXT", True{}) <> dashed("notes", 0, "") <> named_dashed("append-notes", 0, "TEXT", True{}) <> named_dashed("transition-comment", 0, "COMMENT", False{}) <> one_s("status", 115) <> one_s("priority", 112) <> one_s("type", 116) <> one("assignee") <> one("owner") <> flag("claim") <> flag("force") <> one("due") <> one("defer") <> checked("estimate", i32()) <> many("add-label") <> many("remove-label") <> Opt{"set-labels", 0, "labels", "SET_LABELS", True{}, False{}, False{}, Free{}} <> one("parent") <> one("external-ref") <> one("source-repo") <> one("source-repo-path") <> one("agent-context") <> one("session") <> attribution()

# S1.42 (data) the options of `close`
def close_opts() -> List<&2, Opt>:
  dashed("reason", 114, "") <> named_dashed("transition-comment", 0, "COMMENT", False{}) <> flag_s("force", 102) <> flag("suggest-next") <> one("session") <> flag("robot") <> flag("bypass-policy") <> named("bypass-reason", 0, "REASON", False{}) <> attribution()

# S1.43 (data) the options of `reopen`
def reopen_opts() -> List<&2, Opt>:
  dashed("reason", 114, "") <> flag("robot") <> attribution()

# S1.44 (data) the options of `defer`
def defer_opts() -> List<&2, Opt>:
  one("until") <> flag("robot") <> named_dashed("transition-comment", 0, "COMMENT", False{}) <> attribution()

# S1.45 (data) the options of `undefer`
def undefer_opts() -> List<&2, Opt>:
  flag("robot") <> named_dashed("transition-comment", 0, "COMMENT", False{}) <> attribution()

# S1.46 (data) the options of `delete`
def delete_opts() -> List<&2, Opt>:
  one("reason") <> one("from-file") <> flag("cascade") <> flag("force") <> flag("hard") <> flag("dry-run") <> Nil{}

# S1.35 (data) the options of `show`
def show_opts() -> List<&2, Opt>:
  checked("format", formats()) <> flag("wrap") <> flag("no-wrap") <> flag("stats") <> Nil{}

# S1.47 (data) the options of `count`
def count_opts() -> List<&2, Opt>:
  checked("by", Choice{"status" <> "priority" <> "type" <> "assignee" <> "label" <> Nil{}}) <> flag("by-status") <> flag("by-priority") <> flag("by-type") <> flag("by-assignee") <> flag("by-label") <> many("status") <> many("type") <> many("priority") <> one("assignee") <> flag("unassigned") <> flag("include-closed") <> flag("include-templates") <> one("title-contains") <> Nil{}

# S1.48 (data) the options of `stats` (alias `status`)
def stats_opts() -> List<&2, Opt>:
  flag("by-type") <> flag("by-priority") <> flag("by-assignee") <> flag("by-label") <> flag("activity") <> flag("no-activity") <> checked("activity-hours", u32()) <> checked("format", formats()) <> flag("stats") <> flag("robot") <> Nil{}

# S1.49 (data) the options of `ready`; `--assignee` takes zero or one value
def ready_opts() -> List<&2, Opt>:
  checked("limit", Unsigned{}) <> Opt{"assignee", 0, "", "ASSIGNEE", False{}, True{}, False{}, Free{}} <> flag("unassigned") <> many_s("label", 108) <> many("label-any") <> many_s("type", 116) <> many_s("priority", 112) <> checked("sort", Choice{"hybrid" <> "priority" <> "oldest" <> Nil{}}) <> flag("include-deferred") <> one("parent") <> flag_s("recursive", 114) <> one("epic") <> flag("wrap") <> checked("format", formats()) <> flag("stats") <> flag("robot") <> Nil{}

# S1.50 (data) the options of `blocked`
def blocked_opts() -> List<&2, Opt>:
  checked("limit", Unsigned{}) <> flag("detailed") <> flag("wrap") <> many_s("type", 116) <> many_s("priority", 112) <> many_s("label", 108) <> checked("format", formats()) <> flag("stats") <> flag("robot") <> Nil{}

# S1.24 (data) the zero-or-more issue ids most mutations and `show` take
def ids() -> List<&2, Pos>:
  Pos{"IDS", False{}, True{}} <> Nil{}

# S1.51 (data) the two required positionals of `dep add` and `dep remove`
def edge() -> List<&2, Pos>:
  Pos{"ISSUE", True{}, False{}} <> Pos{"DEPENDS_ON", True{}, False{}} <> Nil{}

# S1.16 (data) the 52 top-level words, in the order the original lists them; aliases follow their
# command; a word outside the port's surface keeps its place because the similarity tip ranks over all of them
def top_names() -> List<&2, Name>:
  Name{"agents", 0, 1} <> Name{"audit", 0, 1} <> Name{"blocked", 15, 0} <> Name{"capabilities", 0, 1} <> Name{"capacity", 0, 1} <> Name{"changelog", 0, 1} <> Name{"close", 4, 0} <> Name{"comments", 30, 0} <> Name{"comment", 30, 0} <> Name{"completions", 0, 1} <> Name{"completion", 0, 1} <> Name{"config", 0, 1} <> Name{"coordination", 0, 1} <> Name{"coord", 0, 1} <> Name{"count", 12, 0} <> Name{"create", 1, 0} <> Name{"defer", 6, 0} <> Name{"delete", 8, 0} <> Name{"dep", 18, 0} <> Name{"doctor", 0, 1} <> Name{"epic", 33, 0} <> Name{"gate", 0, 1} <> Name{"graph", 0, 1} <> Name{"history", 0, 1} <> Name{"info", 0, 1} <> Name{"init", 0, 1} <> Name{"label", 24, 0} <> Name{"lint", 0, 1} <> Name{"list", 10, 0} <> Name{"orphans", 0, 1} <> Name{"q", 2, 0} <> Name{"query", 0, 1} <> Name{"ready", 14, 0} <> Name{"reopen", 5, 0} <> Name{"robot-docs", 0, 1} <> Name{"robot_docs", 0, 1} <> Name{"scheduler", 0, 1} <> Name{"schedule", 0, 1} <> Name{"schema", 0, 1} <> Name{"search", 11, 0} <> Name{"show", 9, 0} <> Name{"stale", 0, 1} <> Name{"stats", 13, 0} <> Name{"status", 36, 0} <> Name{"sync", 0, 1} <> Name{"undefer", 7, 0} <> Name{"update", 3, 0} <> Name{"vcs-status", 0, 1} <> Name{"upgrade", 0, 1} <> Name{"version", 17, 0} <> Name{"where", 16, 0} <> Name{"help", 0, 2} <> Nil{}

# S1.51 (data) the words under `dep`
def dep_names() -> List<&2, Name>:
  Name{"add", 19, 0} <> Name{"import", 0, 1} <> Name{"remove", 20, 0} <> Name{"rm", 20, 0} <> Name{"list", 21, 0} <> Name{"tree", 22, 0} <> Name{"cycles", 23, 0} <> Name{"help", 0, 2} <> Nil{}

# S1.52 (data) the words under `label`
def label_names() -> List<&2, Name>:
  Name{"add", 25, 0} <> Name{"remove", 26, 0} <> Name{"list", 27, 0} <> Name{"list-all", 28, 0} <> Name{"rename", 29, 0} <> Name{"help", 0, 2} <> Nil{}

# S1.53 (data) the words under `comments`
def comments_names() -> List<&2, Name>:
  Name{"add", 31, 0} <> Name{"list", 32, 0} <> Name{"help", 0, 2} <> Nil{}

# S1.54 (data) the words under `epic`
def epic_names() -> List<&2, Name>:
  Name{"status", 34, 0} <> Name{"close-eligible", 35, 0} <> Name{"help", 0, 2} <> Nil{}

# S1.1 S1.31–S1.54 (data) the level a Name's target names. 0 is the top level; a branch is
# built only when it is asked for
def cmd_at(n: U32) -> Cmd:
  match n:
    case 1:
      Cmd{"create", create_opts(), Pos{"TITLE", False{}, False{}} <> Nil{}, Clash{"title", "TITLE"} <> Clash{"description", "description-file"} <> Nil{}, Nil{}, False{}}
    case 2:
      Cmd{"q", q_opts(), Pos{"TITLE", False{}, True{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 3:
      Cmd{"update", update_opts(), ids(), Clash{"description", "description-file"} <> Clash{"acceptance-criteria", "check-acceptance"} <> Clash{"acceptance-criteria", "uncheck-acceptance"} <> Clash{"acceptance-criteria", "add-acceptance"} <> Clash{"notes", "append-notes"} <> Nil{}, Nil{}, False{}}
    case 4:
      Cmd{"close", close_opts(), ids(), Nil{}, Nil{}, False{}}
    case 5:
      Cmd{"reopen", reopen_opts(), ids(), Nil{}, Nil{}, False{}}
    case 6:
      Cmd{"defer", defer_opts(), ids(), Nil{}, Nil{}, False{}}
    case 7:
      Cmd{"undefer", undefer_opts(), ids(), Nil{}, Nil{}, False{}}
    case 8:
      Cmd{"delete", delete_opts(), ids(), Clash{"force", "cascade"} <> Nil{}, Nil{}, False{}}
    case 9:
      Cmd{"show", show_opts(), ids(), Clash{"wrap", "no-wrap"} <> Nil{}, Nil{}, False{}}
    case 10:
      Cmd{"list", list_opts(), Nil{}, Nil{}, Nil{}, False{}}
    case 11:
      Cmd{"search", list_opts(), Pos{"QUERY", True{}, False{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 12:
      Cmd{"count", count_opts(), Nil{}, Nil{}, Nil{}, False{}}
    case 13:
      Cmd{"stats", stats_opts(), Nil{}, Nil{}, Nil{}, False{}}
    case 14:
      Cmd{"ready", ready_opts(), Nil{}, Clash{"assignee", "unassigned"} <> Clash{"epic", "parent"} <> Nil{}, Nil{}, False{}}
    case 15:
      Cmd{"blocked", blocked_opts(), Nil{}, Nil{}, Nil{}, False{}}
    case 16:
      Cmd{"where", Nil{}, Nil{}, Nil{}, Nil{}, False{}}
    case 17:
      Cmd{"version", flag_s("check", 99) <> flag_s("short", 115) <> Nil{}, Nil{}, Nil{}, Nil{}, False{}}
    case 18:
      Cmd{"dep", Nil{}, Nil{}, Nil{}, dep_names(), True{}}
    case 19:
      Cmd{"dep add", one_s("type", 116) <> one("metadata") <> Nil{}, edge(), Nil{}, Nil{}, False{}}
    case 20:
      Cmd{"dep remove", one_s("type", 116) <> Nil{}, edge(), Nil{}, Nil{}, False{}}
    case 21:
      Cmd{"dep list", checked("direction", directions()) <> one_s("type", 116) <> checked("format", formats()) <> flag("stats") <> Nil{}, Pos{"ISSUE", True{}, False{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 22:
      Cmd{"dep tree", Opt{"direction", 100, "", "DIRECTION", False{}, False{}, False{}, directions()} <> checked("max-depth", Unsigned{}) <> one("format") <> Nil{}, Pos{"ISSUE", True{}, False{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 23:
      Cmd{"dep cycles", flag("blocking-only") <> flag("include-closed") <> Nil{}, Nil{}, Nil{}, Nil{}, False{}}
    case 24:
      Cmd{"label", Nil{}, Nil{}, Nil{}, label_names(), True{}}
    case 25:
      Cmd{"label add", many_s("label", 108) <> Nil{}, Pos{"ISSUES", False{}, True{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 26:
      Cmd{"label remove", many_s("label", 108) <> Nil{}, Pos{"ISSUES", False{}, True{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 27:
      Cmd{"label list", Nil{}, Pos{"ISSUE", False{}, False{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 28:
      Cmd{"label list-all", Nil{}, Nil{}, Nil{}, Nil{}, False{}}
    case 29:
      Cmd{"label rename", Nil{}, Pos{"OLD_NAME", True{}, False{}} <> Pos{"NEW_NAME", True{}, False{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 30:
      Cmd{"comments", flag("wrap") <> Nil{}, Pos{"ID", False{}, False{}} <> Nil{}, Nil{}, comments_names(), False{}}
    case 31:
      Cmd{"comments add", one_s("file", 102) <> one("author") <> dashed("message", 109, "content") <> Nil{}, Pos{"ID", True{}, False{}} <> Pos{"TEXT", False{}, True{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 32:
      Cmd{"comments list", flag("wrap") <> Nil{}, Pos{"ID", True{}, False{}} <> Nil{}, Nil{}, Nil{}, False{}}
    case 33:
      Cmd{"epic", Nil{}, Nil{}, Nil{}, epic_names(), True{}}
    case 34:
      Cmd{"epic status", flag("eligible-only") <> Nil{}, Nil{}, Nil{}, Nil{}, False{}}
    case 35:
      Cmd{"epic close-eligible", flag("dry-run") <> named_dashed("transition-comment", 0, "COMMENT", False{}) <> Nil{}, Nil{}, Nil{}, Nil{}, False{}}
    case 36:
      Cmd{"status", stats_opts(), Nil{}, Nil{}, Nil{}, False{}}
    case _:
      Cmd{"", Nil{}, Nil{}, Nil{}, top_names(), True{}}
