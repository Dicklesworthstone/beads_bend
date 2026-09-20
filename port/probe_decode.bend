# Probe: decode then re-encode every line of fixture `basic` (the original's own
# normalized output): each must come back byte for byte. Generated from
# goldens/fixtures/basic.jsonl; the byte length is the `eof` column.
import Base
import ./core/decode.bend as Decode
import ./core/model.bend as Model
import ./core/time.bend as Time

def verdict(n: Nat, same: Bool, got: String) -> String:
  match same:
    case True{}:
      "line " ++ Nat.show(n) ++ ": same"
    case False{}:
      "line " ++ Nat.show(n) ++ ": DIFFERENT -> " ++ got

def shown(n: Nat, +want: String, d: Decode.Dec) -> String:
  match d:
    case Decode.DecBad{msg, at}:
      "line " ++ Nat.show(n) ++ ": REFUSED " ++ msg ++ " at column " ++ U32.show(at)
    case Decode.DecOk{+i}:
      verdict(n, String.eq(Model.line(i), want), Model.line(i))

def check(n: Nat, +text: String, eof: U32) -> String:
  shown(n, text, Decode.issue_of(Time.codes(text), eof))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(check(0n, "{\"id\":\"proj-170\",\"title\":\"Implement user auth\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"feature\",\"assignee\":\"alice\",\"created_at\":\"2026-01-01T10:00:01Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T11:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"labels\":[\"auth\",\"backend\"],\"dependencies\":[{\"issue_id\":\"proj-170\",\"depends_on_id\":\"proj-mta\",\"type\":\"blocks\",\"created_at\":\"2026-01-01T11:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"},{\"issue_id\":\"proj-170\",\"depends_on_id\":\"proj-uly\",\"type\":\"parent-child\",\"created_at\":\"2026-01-01T11:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}", 666))
    IO.print(check(1n, "{\"id\":\"proj-5u2\",\"title\":\"Write API docs\",\"status\":\"open\",\"priority\":3,\"issue_type\":\"docs\",\"created_at\":\"2026-01-01T10:00:03Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T11:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"dependencies\":[{\"issue_id\":\"proj-5u2\",\"depends_on_id\":\"proj-170\",\"type\":\"related\",\"created_at\":\"2026-01-01T11:00:00Z\",\"created_by\":\"tester\",\"metadata\":\"{}\",\"thread_id\":\"\"}]}", 450))
    IO.print(check(2n, "{\"id\":\"proj-7vm\",\"title\":\"Refactor config loader\",\"status\":\"deferred\",\"priority\":4,\"issue_type\":\"chore\",\"created_at\":\"2026-01-01T10:00:05Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T14:00:00Z\",\"defer_until\":\"2027-06-01T09:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}", 326))
    IO.print(check(3n, "{\"id\":\"proj-b75\",\"title\":\"Ünïcödé title — “quotes” & <tags> \\\\ backslash\",\"description\":\"Line one\\nLine two\\ttabbed\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-01-01T10:00:06Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:06Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}", 361))
    IO.print(check(4n, "{\"id\":\"proj-mkh\",\"title\":\"Already finished work\",\"status\":\"closed\",\"priority\":2,\"issue_type\":\"task\",\"created_at\":\"2026-01-01T10:00:07Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T13:00:00Z\",\"closed_at\":\"2026-01-01T13:00:00Z\",\"close_reason\":\"Done before the fixture\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}", 361))
    IO.print(check(5n, "{\"id\":\"proj-mta\",\"title\":\"Set up database schema\",\"description\":\"Create the initial tables.\",\"status\":\"open\",\"priority\":1,\"issue_type\":\"task\",\"created_at\":\"2026-01-01T10:00:00Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"labels\":[\"backend\",\"db\"]}", 353))
    IO.print(check(6n, "{\"id\":\"proj-ptp\",\"title\":\"Fix login timeout\",\"status\":\"in_progress\",\"priority\":0,\"issue_type\":\"bug\",\"assignee\":\"bob\",\"created_at\":\"2026-01-01T10:00:02Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T12:30:00Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0,\"comments\":[{\"id\":1,\"issue_id\":\"proj-ptp\",\"author\":\"tester\",\"text\":\"Reproduced on staging.\",\"created_at\":\"2026-01-01T12:30:00Z\"}]}", 432))
    IO.print(check(7n, "{\"id\":\"proj-uly\",\"title\":\"Auth epic\",\"status\":\"open\",\"priority\":2,\"issue_type\":\"epic\",\"created_at\":\"2026-01-01T10:00:04Z\",\"created_by\":\"tester\",\"updated_at\":\"2026-01-01T10:00:04Z\",\"source_repo\":\"proj\",\"source_repo_path\":\"/mnt/proj\",\"compaction_level\":0,\"original_size\":0}", 271))
