# Probe: core/json's lexer against the corpus's pinned serde_json message
# (goldens/error_malformed_jsonl.err: `EOF while parsing a string at line 1
# column 40`) and against real fixture lines, on every engine.
# Lives in port/ (not port/probes/json/): a module imported through a `../` path
# gets a qualified name that starts with a dot, and a call to it inside a
# `( .. : U32)` group is then misread as `U32.<name>` ("expected a defined name,
# observed U32../../core/json.hex_val", bend 2.0.20). Import downward only.
import Base
import ./core/json.bend as Json

def codes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{c}, rest}:
      c <> codes(rest)

def report(r: Json.Lexed) -> String:
  match r:
    case Json.LexBad{msg, at}:
      msg ++ " at line 1 column " ++ U32.show(at)
    case Json.LexOk{toks}:
      "ok " ++ Nat.show(List.length(&2, Json.Tok, toks)) ++ " tokens"

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(report(Json.lex(codes("{\"id\":\"proj-aab\",\"title\":\"truncated line"))))
    IO.print(report(Json.lex(codes("{\"id\":\"proj-aaa\",\"title\":\"x\",\"priority\":2,\"labels\":[\"a\",\"b\"],\"ephemeral\":true}"))))
    IO.print(report(Json.lex(codes("{\"t\":\"tab\\t quote\\\" uni\\u00e9 pair\\ud83d\\ude80 end\"}"))))
    IO.print(report(Json.lex(codes("{\"t\":\"lone \\ud83d x\"}"))))
    IO.print(report(Json.lex(codes(""))))
    IO.print(report(Json.lex(codes("@"))))
