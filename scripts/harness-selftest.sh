#!/usr/bin/env bash
# harness-selftest: mutation-test the port's own gates. Copies the port
# (docs, goldens, port, perf, scripts; legacy/ is linked, never copied) into
# a scratch directory, applies ONE deliberate lie per copy, and requires the
# gate that must catch it to go red. A gate that stays green under a lie is
# the finding (LEAK). Before mutating, every gate is run once on a clean
# copy: a gate that is already red cannot be tested (UNTESTABLE), so a broken
# baseline never inflates the result. Nothing in the real port is touched;
# the scratch copies stay under $TMPDIR (the JSON names the directory) so a
# LEAK can be inspected. Mutations and the gate that must catch each:
#   M1  one byte of a golden .out flipped                -> conform.sh FAIL (exit 1)
#   M2  a case's .err golden moved aside                 -> conform.sh FAIL (a missing golden is FAIL, not skip)
#   M3  cases.tsv reduced to a comment                   -> conform.sh FAIL (zero-test green refused)
#   M4  a case renamed in cases.tsv                      -> conform.sh FAIL (no golden under the new name)
#   M5  the ORIGINAL run as the port (oracle-on-oracle)  -> conform.sh refused (exit 2); needs -- <original cmd>
#   M6  a law's proof removed from PROOF.bend            -> law-coverage.sh RED (exit 1)
#   M7  a law removed from LAWS.bend, its proof kept     -> law-coverage.sh RED (proof of no law)
#   M8  "we should revisit later" appended to the NE ledger -> claims-lint.sh hit (exit 1)
#   M9  an intention sentence appended to PORT_STATE     -> state-check.sh finding (exit 1)
#   M10 a `present` board row with no golden and no law  -> parity-board.sh MALFORMED (exit 1)
#   M11 a re-capture without --repin/--disc              -> golden-capture.sh refused (exit 3); needs -- <original cmd>
# The port under test is the native binary built once from port/main.bend
# (--lane c-1t, the default) or the interpreter through scripts/interp-lane.sh
# (--lane interpreter). PARITY-GATE "Anti-gaming" lists what these lies are.
#
# usage: harness-selftest.sh [--root DIR] [--lane c-1t|interpreter] [-- <original cmd...>]
#        harness-selftest.sh --regressions  # portable harness regressions; no Bend build
# exit: 0 every mutation caught, 1 any LEAK or UNTESTABLE gate, 2 usage or build failure.
# Last stdout line: {"schema":"p2b.harness-selftest.v1","sha","bend","host","lane",
#   "mutations":N,"caught":K,"leaked":[..],"untestable":[..],"scratch":"<dir>","verdict":"OK|LEAK|UNTESTABLE"}
set -uo pipefail
usage() { sed -n '2,/^set -/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }
if [[ "${1:-}" == --regressions ]]; then
  [[ $# -eq 1 ]] || { echo 'error: --regressions takes no additional arguments' >&2; exit 2; }
  exec python3 -B - "$(dirname "$0")" <<'PY'
import json, os, subprocess, sys, tempfile, time
from pathlib import Path
scripts = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(scripts))
from case_manifest import run
root = Path(tempfile.mkdtemp(prefix='harness-regressions.'))
checks = []
def invoke(script, arguments, expected, label, timeout=15, env=None, cwd=None):
    result = subprocess.run([str(scripts / script)] + list(map(str, arguments)), cwd=root if cwd is None else cwd,
                            capture_output=True, timeout=timeout, env=env)
    assert result.returncode == expected, (label, result.returncode, result.stdout, result.stderr)
    checks.append(label)
    lines = result.stdout.decode().splitlines()
    return json.loads(lines[-1]) if lines and lines[-1].startswith('{') else result
def fixture(name, rows, outputs):
    directory = root / name
    directory.mkdir()
    manifest = directory / 'cases.tsv'
    manifest.write_text(rows)
    for case, (out, err, rc) in outputs.items():
        (directory / f'{case}.out').write_bytes(out)
        (directory / f'{case}.err').write_bytes(err)
        (directory / f'{case}.exit').write_text(str(rc) + '\n')
    return manifest, directory
python = sys.executable
invoke('case-gen.py', ['--class', 'ints', '--seed', 12, '--size', 0], 0,
       'zero-size integer generator cannot select from an empty row list')
echo = [python, '-c', 'print("ok")']
m, g = fixture('no-final-newline', 'first\t\nlast\t', {'first': (b'ok\n', b'', 0), 'last': (b'wrong\n', b'', 0)})
r = invoke('conform.sh', [m, g, '--', *echo], 1, 'last TSV row is compared')
assert len(r['cases']) == 2
m, g = fixture('missing-input', 'first\t\nmissing\t\tabsent-input\n', {'first': (b'ok\n', b'', 0), 'missing': (b'ok\n', b'', 1)})
r = invoke('conform.sh', [m, g, '--', *echo], 1, 'missing stdin cannot reuse previous output')
assert r['inconclusive'] == 1
av = ['', 'x y', '*', '--', 'tab\there']
cmd = [python, '-c', 'import json,sys; print(json.dumps(sys.argv[1:]))']
m, g = fixture('argv', 'argv\t' + json.dumps(av) + '\t-\n', {'argv': ((json.dumps(av) + '\n').encode(), b'', 0)})
invoke('conform.sh', [m, g, '--lane', 'quote"\nline', '--', *cmd], 0, 'JSON argv and JSON lane escaping')
m, g = fixture('reserved', 'reserved\t\n', {'reserved': (b'', b'', 124)})
r = invoke('conform.sh', [m, g, '--', python, '-c', 'raise SystemExit(124)'], 1, 'equal timeout exits remain inconclusive')
assert r['verdict'] == 'INCONCLUSIVE'
for code in (125, 129, 139, 143, 255):
    m, g = fixture('reserved-' + str(code), 'only\n', {'only': (b'', b'', code)})
    r = invoke('conform.sh', [m, g, '--', 'bash', '-c', f'exit {code}'], 1,
               f'wrapper/infrastructure exit {code} cannot pass')
    assert r['inconclusive'] == 1
    invoke('first-divergence.sh', ['only', m, g, '--', 'true'], 1,
           f'reserved golden {code} is inconclusive in first divergence')
    assert run(['bash', '-c', f'exit {code}'])['problem']
fifo = root / 'stdin.fifo'; os.mkfifo(fifo)
m, g = fixture('fifo-input', 'only\t[]\t' + str(fifo) + '\n', {'only': (b'', b'', 0)})
r = invoke('conform.sh', [m, g, '--timeout', '.03', '--', 'cat'], 1,
           'FIFO stdin is rejected before opening can hang', timeout=2)
assert r['inconclusive'] == 1
invoke('golden-capture.sh', [m, root / 'fifo-capture', '--timeout', '.03', '--', 'cat'], 1,
       'capture provenance cannot block on FIFO stdin', timeout=2)
invoke('cases-lint.sh', [fifo], 1, 'FIFO case manifest is rejected before reading', timeout=2)
invoke('conform.sh', [fifo, g, '--', 'true'], 2,
       'conformance rejects FIFO manifest without entering a case', timeout=2)
fifo_gold = root / 'fifo-golden'; fifo_gold.mkdir(); os.mkfifo(fifo_gold / 'only.out')
m_plain = root / 'fifo-golden.tsv'; m_plain.write_text('only\n')
r = invoke('conform.sh', [m_plain, fifo_gold, '--', 'true'], 1,
           'FIFO golden stream is an invalid golden, never a hang', timeout=2)
assert r['failed'] == 1
os.mkfifo(fifo_gold / 'MANIFEST.txt')
invoke('conform.sh', [m_plain, fifo_gold, '--', 'true'], 2,
       'FIFO oracle metadata is rejected before parsing', timeout=2)
(root / 'cwd.in').write_bytes(b'from child cwd\n')
r = run(['cat'], stdin='cwd.in', cwd=root)
assert r['out'] == b'from child cwd\n' and not r['problem']
checks.append('callable runner resolves stdin relative to child cwd')
for command, timeout_value in (([], 1), (echo, 0), (echo, float('nan')), ('echo', 1)):
    try:
        run(command, timeout=timeout_value)
    except ValueError:
        pass
    else:
        raise AssertionError((command, timeout_value))
checks.append('callable runner rejects invalid command vectors and deadlines')
escaped = [python, '-c', 'import os,time; p=os.fork(); '
           'os.setsid() if p == 0 else None; time.sleep(.8) if p == 0 else time.sleep(5)']
started = time.monotonic()
r = run(escaped, timeout=.03)
assert r['problem'] == 'timeout' and time.monotonic() - started < .7
checks.append('escaped descendant pipe cannot defeat timeout cleanup')
mixed_streams = [python, '-c', 'import sys; print("All terms check.",file=sys.stderr,flush=True); '
                 'print("ERROR after checker verdict",flush=True)']
r = run(mixed_streams, merge_stderr=True)
assert r['out'].splitlines() == [b'All terms check.', b'ERROR after checker verdict'] and r['err'] == b''
checks.append('merged runner preserves verdict chronology across stdout and stderr')
r = run(escaped, timeout=.03, merge_stderr=True)
assert r['problem'] == 'timeout' and r['err'] == b''
checks.append('merged runner timeout handles escaped descendant pipe cleanup')
r = run(['not-an-installed-program-harness-test'], merge_stderr=True)
assert r['problem'] and r['out'] and r['err'] == b''
checks.append('merged launch failure keeps the merged-stream result contract')
invoke('conform.sh', [m, g, '--', 'not-an-installed-program-harness-test'], 1, 'missing executable inconclusive')
invoke('conform.sh', [m, g, '--timeout', '.03', '--', python, '-c', 'import time; time.sleep(10)'], 1, 'per-case timeout bounds execution')
invoke('conform.sh', [m, g, '--lane'], 2, 'missing option value returns instead of looping')
invoke('conform.sh', [m, g, '--oracle-command', json.dumps(echo), '--', *echo], 2, 'original command is refused as port')
m, g = fixture('missing-stderr', 'only\n', {'only': (b'ok\n', b'', 0)})
(g / 'only.err').rename(g / 'only.err.saved')
invoke('first-divergence.sh', ['only', m, g, '--', *echo], 1, 'missing stderr golden cannot pass')
m, g = fixture('capture-input', 'only\t\tabsent-input\n', {})
invoke('golden-capture.sh', [m, g, '--', *echo], 1, 'capture refuses missing input')
assert not (g / 'MANIFEST.txt').exists()
m, g = fixture('capture-good', 'only', {})
invoke('golden-capture.sh', [m, g, '--', *echo], 0, 'name-only capture and EOF row')
invoke('conform.sh', [m, g, '--', *echo], 2, 'captured original identity is enforced')
invoke('floor.sh', [m, g, '--repeat', 2, '--', *echo], 0, 'floor permits intentional oracle comparison')
invoke('floor.sh', [m, g, '--repeat', 1, '--', python, '-c', 'print("ok", flush=True)'], 2,
       'floor refuses a different command even when its outputs match')
invoke('golden-capture.sh', [m, g, '--', *echo], 3, 'silent recapture refused')
relative = root / 'capture-cwd'; relative.mkdir()
(relative / 'original.py').write_text('print("ok")\n')
(relative / 'cases.tsv').write_text('only\n')
invoke('golden-capture.sh', ['cases.tsv', 'gold', '--', python, 'original.py'], 0,
       'capture stores command identity relative to capture cwd', cwd=relative)
invoke('conform.sh', [relative / 'cases.tsv', relative / 'gold', '--', python, relative / 'original.py'], 2,
       'oracle identity stays enforced from a different cwd')
relocated = root / 'relocated-capture'
import shutil
shutil.copytree(relative, relocated)
invoke('conform.sh', ['cases.tsv', 'gold', '--', python, 'original.py'], 2,
       'relocated captured original remains forbidden as a port', cwd=relocated)
invoke('floor.sh', ['cases.tsv', 'gold', '--repeat', 1, '--', python, 'original.py'], 0,
       'relocated original argv remains valid for the floor', cwd=relocated)
orphan = root / 'orphan-gold'; orphan.mkdir(); (orphan / 'only.err').write_bytes(b'precious')
invoke('golden-capture.sh', [m, orphan, '--', *echo], 3,
       'orphan stderr/exit artifacts still require an explicit recapture')
linked = root / 'linked-gold'; linked.mkdir(); (linked / 'only.out').symlink_to(root / 'cwd.in')
invoke('golden-capture.sh', [m, linked, '--repin', 'test', '--', *echo], 2,
       'capture refuses symlink destinations before writing')
assert (root / 'cwd.in').read_bytes() == b'from child cwd\n'
hardlinked = root / 'hardlinked-gold'; hardlinked.mkdir()
os.link(root / 'cwd.in', hardlinked / 'only.out')
invoke('golden-capture.sh', [m, hardlinked, '--repin', 'test', '--', *echo], 2,
       'capture refuses hardlinked destinations without damaging the other name')
assert (root / 'cwd.in').read_bytes() == b'from child cwd\n'
linked_dir = root / 'linked-directory'; linked_dir.symlink_to(linked, target_is_directory=True)
invoke('golden-capture.sh', [m, linked_dir, '--repin', 'test', '--', *echo], 2,
       'capture refuses a symlink directory as its destination')
late_link = root / 'late-linked-gold'; late_link.mkdir()
late_command = [python, '-c', 'from pathlib import Path; '
                f'Path({str(late_link / "only.out")!r}).symlink_to({str(root / "cwd.in")!r}); print("ok")']
invoke('golden-capture.sh', [m, late_link, '--', *late_command], 2,
       'capture rechecks destinations after running the original')
assert (root / 'cwd.in').read_bytes() == b'from child cwd\n'
changed = root / 'changed-input'; changed.write_bytes(b'before')
changed_manifest = root / 'changed.tsv'; changed_manifest.write_text('only\t' + json.dumps([str(changed)]) + '\n')
invoke('golden-capture.sh', [changed_manifest, root / 'changed-gold', '--', python, '-c',
       'import pathlib,sys; pathlib.Path(sys.argv[1]).write_bytes(b"after"); print("ok")'], 1,
       'capture rejects changed fixture provenance')
assert not (root / 'changed-gold' / 'MANIFEST.txt').exists()
changed.write_bytes(b'before')
changed_manifest.write_text('only\t' + json.dumps(['--input=' + str(changed)]) + '\n')
invoke('golden-capture.sh', [changed_manifest, root / 'changed-equals-gold', '--', python, '-c',
       'import pathlib,sys; pathlib.Path(sys.argv[1].split("=",1)[1]).write_bytes(b"after"); print("ok")'], 1,
       'capture fingerprints file paths in equals-style options')
assert not (root / 'changed-equals-gold' / 'MANIFEST.txt').exists()
floor_data = root / 'floor-data'; floor_data.write_text('before')
m, g = fixture('mutating-floor', 'only\t' + json.dumps([str(floor_data)]) + '\n', {'only': (b'ok\n', b'', 0)})
r = invoke('floor.sh', [m, g, '--repeat', 1, '--', python, '-c',
       'import pathlib,sys; pathlib.Path(sys.argv[1]).write_text("after"); print("ok")'], 1,
       'equal floor outputs cannot hide changed input bytes')
assert r['verdict'] == 'INCONCLUSIVE'
empty = root / 'empty.tsv'; empty.write_text('# empty\n')
invoke('conform.sh', [empty, g, '--', *echo], 1, 'empty manifest cannot pass')
left, right = root / 'left', root / 'right'
invoke('budget-compare.py', [fifo, fifo], 2,
       'budget comparator rejects FIFO artifacts before reading', timeout=2)
left.write_text('1000.0 0.0\n'); right.write_text('1001.0 0.01\n')
invoke('budget-compare.py', [left, right, '--abs', '.1', '--rel', '.01'], 0, 'each float independently gets abs OR relative budget')
left.write_text('1e999\n'); right.write_text('1e998\n')
invoke('budget-compare.py', [left, right], 1, 'overflowing float tokens refused')
invoke('budget-compare.py', [left, right, '--abs', 'nan'], 2, 'nonfinite budget refused')
left.write_text('1e-999\n'); right.write_text('1e-998\n')
invoke('budget-compare.py', [left, right], 1, 'underflow cannot erase numeric differences')
left.write_text('-1e308\n'); right.write_text('1e308\n')
invoke('budget-compare.py', [left, right, '--rel', '2'], 0, 'finite relative budget survives overflowing absolute difference')
left.write_text('0.0\n'); right.write_text('0.01\n')
r = invoke('budget-compare.py', [left, right, '--abs', '.1'], 0, 'zero-denominator report is strict JSON')
assert r['max_rel'] is None and r['unbounded_rel']
for a, b, budget_args, expected, label in (
    ('9007199254740992.0\n', '9007199254740993.0\n', [], 1, 'binary64 rounding cannot erase decimal differences'),
    ('1.0\n', '1.00000000000000000001\n', ['--abs', '1e-21'], 1, 'exact decimal comparison exceeds tiny budget'),
    ('0.1\n', '0.3\n', ['--abs', '.2'], 0, 'exact decimal boundary passes'),
    ('1.0\n', '1.00000000000000000001\n', ['--measure'], 0, 'measurement retains tiny decimal deviations'),
    ('name  1.0\n', 'name 1.0\n', ['--abs', '1'], 1, 'budget never normalizes discrete whitespace'),
    ('id=001 1.0\n', 'id=1 1.0\n', ['--abs', '1'], 1, 'nonnumeric bytes remain exact'),
    ('1.0\n', '1.0\r\n', [], 1, 'budget keeps newline bytes exact'),
    ('1e999999999999999999999999\n', '1.0\n', [], 1, 'unsupported exponent is a mismatch, not a traceback')):
    left.write_text(a); right.write_text(b)
    r = invoke('budget-compare.py', [left, right, *budget_args], expected, label)
    if '--measure' in budget_args: assert r['max_abs'] > 0
left.write_text('4.9406564584124654e-324\n'); right.write_text('4.9406564584124655e-324\n')
r = invoke('budget-compare.py', [left, right, '--measure'], 0,
           'subnormal decimal difference is preserved in exact measurement fields')
assert r['max_abs'] is None and r['underflow_abs'] and not r['unbounded_abs']
assert r['max_abs_exact'] != '0/1'
failed = [python, '-c', 'raise SystemExit(7)']
r = invoke('incumbent-bench.sh', ['--runs', 1, '--warmup', 0, '--max-cv', 10000, '--original', *failed, '--port', *failed], 1, 'two failed benchmark arms refused')
assert r['verdict'] == 'RUN_FAILED' and r['ratio'] is None
different_err = [python, '-c', 'import sys; print("ok"); print("different", file=sys.stderr)']
invoke('incumbent-bench.sh', ['--runs', 1, '--warmup', 0, '--max-cv', 10000, '--original', *echo, '--port', *different_err], 1, 'benchmark compares stderr')
warm_code = ('from pathlib import Path; p=Path("bench-warm-marker"); '
             'print("ok" if p.exists() else "warmup-difference"); p.touch()')
r = invoke('incumbent-bench.sh', ['--runs', 1, '--warmup', 1, '--max-cv', 10000,
           '--original', python, '-c', warm_code, '--port', *echo], 1,
           'benchmark includes warmup outputs in stability checks')
assert r['verdict'] == 'NONDETERMINISTIC_ORIGINAL' and r['ratio'] is None
bench_input = root / 'bench-input'; bench_input.write_text('before')
r = invoke('incumbent-bench.sh', ['--runs', 1, '--warmup', 0, '--max-cv', 10000,
           '--original', python, '-c', 'from pathlib import Path; import sys; '
           'Path(sys.argv[1]).write_text("after"); print("ok")', bench_input, '--port', *echo], 1,
           'benchmark refuses changed explicit source/input files')
assert r['verdict'] == 'INPUT_CHANGED' and r['ratio'] is None
proposed = root / 'argv-proposed.tsv'
invoke('argv-explore.sh', ['--out', proposed, '--file', 'file with spaces', '--', python, '-c',
                         'import sys; print(repr(sys.argv[1:]),file=sys.stderr)'], 0, 'argv exploration emits lossless proposals')
vectors = [json.loads(line.split('\t', 1)[1]) for line in proposed.read_text().splitlines() if not line.startswith('#')]
assert [''] in vectors and ['file with spaces'] in vectors
explore = root / 'explore'
invoke('diff-explore.sh', ['--class', 'argv', '--seeds', 1, '--gen',
    "printf '%s' '[\"\",\"x y\",\"*\"]'", '--out-dir', explore,
    '--original', *cmd, '--port', python, '-c',
    'import json,sys; print(json.dumps(sys.argv[1:]) + "DIFF")'], 1, 'differential exploration preserves argv boundaries')
row = next(explore.glob('*/proposed.tsv')).read_text().split('\t', 1)[1]
assert json.loads(row) == ['', 'x y', '*']
invoke('diff-explore.sh', ['--class', 'argv', '--seeds', 1, '--timeout', '.03', '--gen', 'sleep 10',
    '--out-dir', root / 'timeout', '--original', 'true', '--port', 'true'], 1, 'differential generator timeout is bounded')
r = invoke('diff-explore.sh', ['--class', 'argv', '--seeds', 1, '--gen', "printf '[invalid'",
    '--out-dir', root / 'invalid-generator', '--original', 'true', '--port', 'true'], 1,
    'invalid generated argv is inconclusive execution evidence')
assert r['inconclusive'] == 1
r = invoke('diff-explore.sh', ['--args', '["{input}"]', '--seeds', 1, '--gen', "printf 'before\\n'",
    '--out-dir', root / 'mutating-input', '--original', python, '-c',
    'import pathlib,sys; pathlib.Path(sys.argv[1]).write_text("after"); print("same")',
    '--port', python, '-c', 'print("same")'], 1, 'mutated generated input cannot count as agreement')
assert r['inconclusive'] == 1
r = invoke('diff-explore.sh', ['--class', 'argv', '--seeds', 1, '--gen', "printf 'not-json'",
    '--out-dir', root / 'non-json-generator', '--original', 'true', '--port', 'true'], 1,
    'argv generator cannot silently fall back to word splitting')
assert r['inconclusive'] == 1
lint_manifest = root / 'lint.tsv'
spaced_input = root / 'input with spaces.txt'
spaced_input.write_text('data\n')
lint_manifest.write_text('usage_none\nempty\t[]\t-\tclass-empty\nerror_missing\t[]\t-\tclass-error\n'
                         'edge_1000\t' + json.dumps(['a+b', '', str(spaced_input)]) + '\t' + str(spaced_input) + '\tclass-happy')
r = invoke('cases-lint.sh', [lint_manifest, '--commands', json.dumps(['a+b'])], 0,
           'cases lint shares JSON argv, name-only, dash-stdin, fourth-column and final-row semantics')
assert r['cases'] == 4 and r['classes_missing'] == '' and r['notes'] == 0
lint_manifest.write_text('only\t[]\tabsent-stdin\tclass-annotation')
r = invoke('cases-lint.sh', [lint_manifest], 1, 'cases lint rejects a missing stdin on the final row')
assert r['cases'] == 1 and r['errors'] == 1
lint_manifest.write_text('only\t["a+b"]')
r = invoke('cases-lint.sh', [lint_manifest, '--commands', '["a+b","aaab"]'], 0,
           'cases lint command coverage uses exact argv, not regular expressions')
assert 'happy:a+b' not in r['classes_missing'] and 'happy:aaab' in r['classes_missing']
lint_manifest.write_text('first\nfirst')
invoke('cases-lint.sh', [lint_manifest], 1, 'cases lint rejects duplicate name-only rows')
# Exercise tripwire orchestration with a tiny compiler fixture; no Bend/toolchain
# behavior is mocked by these checks, only the shell harness's pin policy.
trip = root / 'tripwire'; (trip / 'port').mkdir(parents=True)
(trip / 'port' / 'main.bend').write_text('# compiler fixture input\n')
compiler = trip / 'compiler.py'
compiler.write_text('import os,sys\nfrom pathlib import Path\n'
    'if "--version" in sys.argv: print("compiler-fixture"); raise SystemExit(0)\n'
    'p=Path(sys.argv[sys.argv.index("-o")+1])\n'
    'p.write_text("#!"+sys.executable+"\\n"+os.environ.get("HARNESS_RUNTIME", "print(\\\"ok\\\")\\n"))\n'
    'p.chmod(0o755)\n')
trip_env = dict(os.environ, BEND_CLI=f'{python} {compiler}')
inputs = trip / 'inputs.tsv'; inputs.write_text('# empty\n')
invoke('perf-tripwire.sh', ['--pin', '--pin-file', 'pin.txt', inputs], 2,
       'empty tripwire corpus cannot write a green pin', env=trip_env, cwd=trip)
assert not (trip / 'pin.txt').exists()
inputs.write_text('one\nsecond\n')
pin_target = trip / 'precious.txt'; pin_target.write_text('preserve')
(trip / 'linked-pin').symlink_to(pin_target)
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'linked-pin', inputs], 2,
       'tripwire refuses symlink pin output before building', env=trip_env, cwd=trip)
assert pin_target.read_text() == 'preserve'
os.link(pin_target, trip / 'hardlinked-pin')
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'hardlinked-pin', inputs], 2,
       'tripwire refuses hardlinked pin output before building', env=trip_env, cwd=trip)
assert pin_target.read_text() == 'preserve'
os.mkfifo(trip / 'fifo-pin')
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'fifo-pin', inputs], 2,
       'tripwire refuses FIFO pin output without blocking', env=trip_env, cwd=trip, timeout=2)
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'pin.txt', inputs], 0,
       'tripwire records all requested cells', env=trip_env, cwd=trip)
invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 2, '--pin-file', 'pin.txt', inputs], 2,
       'tripwire refuses a changed thread budget', env=trip_env, cwd=trip)
inputs.write_text('one\t["cheaper-workload"]\nsecond\n')
r = invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 1, '--slack', 100, '--pin-file', 'pin.txt', inputs], 3,
           'changed argv cannot clear an unchanged-output timing pin', env=trip_env, cwd=trip)
assert 'one/SEQ-CPU' in r['refused']
inputs.write_text('one\n')
r = invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 1, '--slack', 100, '--pin-file', 'pin.txt', inputs], 1,
           'removing a pinned tripwire case trips the gate', env=trip_env, cwd=trip)
assert 'second/SEQ-CPU' in r['trips'] and 'second/PAR-CPU' in r['trips']
data = trip / 'data.txt'; data.write_text('workload one\n')
inputs.write_text('file\t["data.txt"]\n')
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'data-pin.txt', inputs], 0,
       'tripwire fingerprints file-valued arguments', env=trip_env, cwd=trip)
data.write_text('cheaper workload\n')
r = invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 1, '--slack', 100, '--pin-file', 'data-pin.txt', inputs], 3,
           'changed input bytes cannot clear an unchanged-output timing pin', env=trip_env, cwd=trip)
assert 'file/PAR-CPU' in r['refused']
inputs.write_text('file\t["--input=data.txt"]\n')
invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 1, '--pin-file', 'equals-pin.txt', inputs], 0,
       'tripwire pins equals-style file operands', env=trip_env, cwd=trip)
data.write_text('another cheaper workload\n')
r = invoke('perf-tripwire.sh', ['--runs', 1, '--threads', 1, '--slack', 100, '--pin-file', 'equals-pin.txt', inputs], 3,
           'changed equals-option input bytes refuse comparison', env=trip_env, cwd=trip)
assert 'file/PAR-CPU' in r['refused']
trip_env['HARNESS_RUNTIME'] = ('from pathlib import Path\nimport sys\n'
    'p=Path("trip-warm-"+sys.argv[2]); print("ok" if p.exists() else "warmup-difference"); p.touch()\n')
r = invoke('perf-tripwire.sh', ['--pin', '--runs', 1, '--threads', 2, '--pin-file', 'refused.txt', inputs], 3,
           'tripwire warmup differences refuse pinning', env=trip_env, cwd=trip)
assert r['refused'] and not (trip / 'refused.txt').exists()
for name in checks: print('PASS ' + name)
print(json.dumps({'checks': len(checks), 'scratch': str(root), 'verdict': 'PASS'}))
PY
fi
ROOT="$PWD"; LANE="c-1t"; ORIG=()
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --root || "$1" == --lane ]]; then
    [[ $# -ge 2 && "$2" != --* ]] || { echo "error: $1 needs a value" >&2; exit 2; }
  fi
  case "$1" in
    --root) ROOT="${2:-}"; shift 2;;
    --lane) LANE="${2:-}"; shift 2;;
    --) shift; ORIG=("$@"); break;;
    *) echo "error: unknown option $1" >&2; usage >&2; exit 2;;
  esac
done
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 2
cd "$ROOT" || { echo "error: no such root $ROOT" >&2; exit 2; }
[[ -d goldens && -d port && -d scripts && -d docs && -d perf ]] || { echo "error: run from a port root (docs/ goldens/ port/ perf/ scripts/)" >&2; exit 2; }
[[ "$LANE" == c-1t || "$LANE" == interpreter ]] || { echo "error: --lane is c-1t or interpreter" >&2; exit 2; }
if [[ -n "${BEND_CLI:-}" ]]; then read -ra BEND <<<"$BEND_CLI"
elif command -v bend >/dev/null 2>&1; then BEND=(bend)
else echo "error: no bend on PATH and no BEND_CLI" >&2; exit 2; fi
export BEND_NO_TELEMETRY=1
ROOT="$PWD"
T="$(mktemp -d "${TMPDIR:-/tmp}/hst.XXXXXX")"
sha="$(git rev-parse --short HEAD 2>/dev/null || echo none)"
run_compiler() {
  local seconds="$1"; shift
  python3 -B - "$HERE" "$seconds" "${BEND[@]}" "$@" <<'PY'
import sys
sys.path.insert(0,sys.argv[1])
from case_manifest import run
r=run(sys.argv[3:],timeout=float(sys.argv[2]))
sys.stdout.buffer.write(r['out']); sys.stderr.buffer.write(r['err'])
sys.exit(r['rc'] if r['rc'] is not None else 125)
PY
}
bendv="$(run_compiler 30 --version 2>/dev/null | tail -1)" || { echo 'error: compiler version probe failed' >&2; exit 2; }
[[ -n "$bendv" ]] || { echo 'error: compiler returned no version' >&2; exit 2; }
host="$(uname -s -m 2>/dev/null | tr ' ' '-')"

# the port command: one native build for every copy, or the interpreter lane
if [[ "$LANE" == c-1t ]]; then
  if ! run_compiler 600 port/main.bend -o "$T/x" >"$T/build.log" 2>&1; then
    echo "error: native build of port/main.bend failed: $(head -c 200 "$T/build.log")" >&2; exit 2
  fi
  PORT=("$T/x" --threads 1 --gpu off --)
else
  PORT=(scripts/interp-lane.sh "${BEND[@]}" port/main.bend --)
fi

# the first case whose stdout golden is non-empty (M1 flips a byte of it), and the first law
C=""; C_ANY=""
while IFS= read -r raw || [[ -n "$raw" ]]; do
  l="${raw//$'\t'/$'\x1f'}"; IFS=$'\x1f' read -r nm _rest <<<"$l"
  [[ -z "$nm" || "$nm" == \#* ]] && continue
  [[ -z "$C_ANY" ]] && C_ANY="$nm"
  if [[ -z "$C" && -s "goldens/$nm.out" ]]; then C="$nm"; fi
done <goldens/cases.tsv
[[ -n "$C_ANY" ]] || { echo "error: goldens/cases.tsv has no cases" >&2; exit 2; }
[[ -n "$C" ]] || C="$C_ANY"
L="$(grep -oE '^law [A-Za-z0-9_.]+' port/LAWS.bend 2>/dev/null | head -1 | awk '{print $2}')"

copy() {  # $1 name -> a fresh copy of the port under $T/$1 (legacy linked)
  local d="$T/$1"; mkdir -p "$d"
  cp -RL docs goldens port perf scripts "$d/" 2>/dev/null
  [[ -e legacy ]] && ln -s "$ROOT/legacy" "$d/legacy"
  [[ -f .gitignore ]] && cp .gitignore "$d/"
  printf '%s' "$d"
}
n=0; caught=0; leaked=(); untestable=()
# baseline: each gate on a clean copy; a red gate here makes its mutations UNTESTABLE
B="$(copy base)"
( cd "$B" && scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}" ) >"$T/base.conform.log" 2>&1; b_conform=$?
( cd "$B" && scripts/law-coverage.sh port/LAWS.bend port/PROOF.bend docs/FEATURE_PARITY.md port/main.bend ) >"$T/base.lawcov.log" 2>&1; b_lawcov=$?
( cd "$B" && scripts/claims-lint.sh perf/NEGATIVE-EVIDENCE.md ) >"$T/base.claims.log" 2>&1; b_claims=$?
( cd "$B" && scripts/state-check.sh docs/PORT_STATE.md ) >"$T/base.state.log" 2>&1; b_state=$?
( cd "$B" && scripts/parity-board.sh docs/FEATURE_PARITY.md ) >"$T/base.board.log" 2>&1; b_board=$?
b_manifest=1; [[ -f goldens/MANIFEST.txt ]] && b_manifest=0
printf 'baseline   conform=%s law-coverage=%s claims-lint=%s state-check=%s parity-board=%s manifest=%s (0 = green)\n' \
  "$b_conform" "$b_lawcov" "$b_claims" "$b_state" "$b_board" "$b_manifest"

expect() {  # name baseline_rc wanted_rc dir command...
  local name="$1" base="$2" want="$3" d="$4"; shift 4; n=$((n+1))
  if [[ "$base" -ne 0 ]]; then
    printf 'UNTESTABLE %-24s the gate is already red on the clean copy (exit %s)\n' "$name" "$base"; untestable+=("$name"); return
  fi
  ( cd "$d" && "$@" ) >"$T/$name.log" 2>&1; local rc=$?
  if [[ $rc -eq $want ]]; then
    printf 'CAUGHT     %-24s exit %s\n' "$name" "$rc"; caught=$((caught+1))
  else
    printf 'LEAK       %-24s exit %s, wanted %s: %s\n' "$name" "$rc" "$want" "$(grep -v '^$' "$T/$name.log" | tail -1 | head -c 110)"; leaked+=("$name")
  fi
}

# M1 one byte of the golden flipped
D="$(copy m1)"; python3 - "$D/goldens/$C.out" <<'PY'
import sys
p = sys.argv[1]; b = bytearray(open(p, 'rb').read())
if b: b[0] ^= 0x01
else: b.append(1)
open(p, 'wb').write(bytes(b))
PY
expect M1_golden_edited "$b_conform" 1 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}"
# M2 a missing .err golden
D="$(copy m2)"; mv "$D/goldens/$C_ANY.err" "$D/goldens/$C_ANY.err.aside"
expect M2_missing_err "$b_conform" 1 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}"
# M3 an empty manifest
D="$(copy m3)"; printf '# empty\n' >"$D/goldens/cases.tsv"
expect M3_empty_manifest "$b_conform" 1 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}"
# M4 a renamed case
D="$(copy m4)"; awk -F'\t' -v c="$C_ANY" 'BEGIN{OFS="\t"} $1==c {$1=c"_renamed"} {print}' goldens/cases.tsv >"$D/goldens/cases.tsv"
expect M4_renamed_case "$b_conform" 1 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" -- "${PORT[@]}"
# M5 oracle-on-oracle (the original as the port) must be refused, not passed
if [[ ${#ORIG[@]} -gt 0 ]]; then
  D="$(copy m5)"
  oracle_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${ORIG[@]}")"
  expect M5_oracle_on_oracle "$b_conform" 2 "$D" scripts/conform.sh goldens/cases.tsv goldens --lane "$LANE" --oracle-command "$oracle_json" -- "${ORIG[@]}"
else
  echo "UNTESTABLE M5_oracle_on_oracle      no original command given after --"
  n=$((n+1)); untestable+=(M5_oracle_on_oracle)
fi
# M6 a law whose proof is gone
if [[ -n "$L" ]]; then
  D="$(copy m6)"; awk -v L="def Laws.$L(" '{ if (skip) { if ($0 ~ /^def / || $0 ~ /^law /) skip=0; else next } if (index($0, L) == 1) { skip=1; next } print }' port/PROOF.bend >"$D/port/PROOF.bend"
  expect M6_unproved_law "$b_lawcov" 1 "$D" scripts/law-coverage.sh port/LAWS.bend port/PROOF.bend docs/FEATURE_PARITY.md port/main.bend
  # M7 a proof whose law is gone
  D="$(copy m7)"; awk -v L="law $L:" '{ if (skip) { if ($0 ~ /^law / || $0 ~ /^#/ || $0 ~ /^def /) skip=0; else next } if ($0 == L) { skip=1; next } print }' port/LAWS.bend >"$D/port/LAWS.bend"
  expect M7_ghost_proof "$b_lawcov" 1 "$D" scripts/law-coverage.sh port/LAWS.bend port/PROOF.bend docs/FEATURE_PARITY.md port/main.bend
else
  echo "UNTESTABLE M6_unproved_law M7_ghost_proof   port/LAWS.bend has no law"
  n=$((n+2)); untestable+=(M6_unproved_law M7_ghost_proof)
fi
# M8 a deferral in a ledger
D="$(copy m8)"; printf '\n- Retry predicate: we should revisit later\n' >>"$D/perf/NEGATIVE-EVIDENCE.md"
expect M8_ledger_later "$b_claims" 1 "$D" scripts/claims-lint.sh perf/NEGATIVE-EVIDENCE.md
# M9 an intention instead of a command in PORT_STATE
D="$(copy m9)"; printf '\n## Plan\n\nWe should probably fix the rest later.\n' >>"$D/docs/PORT_STATE.md"
expect M9_state_intention "$b_state" 1 "$D" scripts/state-check.sh docs/PORT_STATE.md
# M10 a present row with no evidence, inserted right under the board's header
D="$(copy m10)"; awk 'BEGIN{hdr=0; ins=0} {print} !ins && tolower($0) ~ /^\| *feature *\|/ {hdr=1; next} hdr && /^\|[[:space:]]*:?-+/ {print "| ghost feature | S1.1 | ghost | - | - | present | harness-selftest M10 |"; hdr=0; ins=1}' docs/FEATURE_PARITY.md >"$D/docs/FEATURE_PARITY.md"
expect M10_present_no_evidence "$b_board" 1 "$D" scripts/parity-board.sh docs/FEATURE_PARITY.md
# M11 a silent re-capture
if [[ ${#ORIG[@]} -gt 0 ]]; then
  D="$(copy m11)"
  expect M11_silent_recapture "$b_manifest" 3 "$D" scripts/golden-capture.sh goldens/cases.tsv goldens -- "${ORIG[@]}"
else
  echo "UNTESTABLE M11_silent_recapture     no original command given after --"
  n=$((n+1)); untestable+=(M11_silent_recapture)
fi

verdict=OK
[[ ${#untestable[@]} -gt 0 ]] && verdict=UNTESTABLE
[[ ${#leaked[@]} -gt 0 ]] && verdict=LEAK
jarr() { local s=""; local x; for x in "$@"; do s+="\"$x\","; done; printf '%s' "${s%,}"; }
j() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1])[1:-1])' "$1"; }
echo "--"
echo "harness-selftest: $caught/$n mutations caught, ${#leaked[@]} leaked, ${#untestable[@]} untestable → $verdict (scratch: $T)"
printf '{"schema":"p2b.harness-selftest.v1","sha":"%s","bend":"%s","host":"%s","lane":"%s","mutations":%d,"caught":%d,"leaked":[%s],"untestable":[%s],"scratch":"%s","verdict":"%s"}\n' \
  "$sha" "$(j "$bendv")" "$host" "$LANE" "$n" "$caught" "$(jarr ${leaked[@]+"${leaked[@]}"})" "$(jarr ${untestable[@]+"${untestable[@]}"})" "$(j "$T")" "$verdict"
[[ "$verdict" == OK ]]
