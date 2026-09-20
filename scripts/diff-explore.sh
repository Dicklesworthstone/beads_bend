#!/usr/bin/env bash
# diff-explore: generate inputs, compare ORIGINAL and PORT, then minimize
# mismatches while preserving which streams differ. Goldens stay untouched.
# usage: diff-explore.sh --args '<JSON argv or words containing {input}>'
#          [--class lines|csv|ints|argv] [--seeds N | --minutes M]
#          [--start-seed S] [--size N] [--lang python|js|go|rust|c]
#          [--gen 'command with {seed}'] [--out-dir legacy/inputs/gen]
#          [--no-minimize] [--timeout S] --original <cmd...> --port <cmd...>
# --port is last. Class argv consumes the generator's JSON array directly.
# Default timeout=5s per command; --minutes also bounds generation and shrinking.
# Infrastructure failures are INCONCLUSIVE, never ordinary equal results or
# shrink predicates. Proposed rows use JSON arrays without flattening argv.
# Exit 0 no mismatch/inconclusive run, 1 findings, 2 usage. Last line strict JSON.
set -uo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
  exit 0
fi
exec python3 -B - "$(dirname "$0")" "$@" <<'PY'
import argparse, hashlib, json, os, platform, shlex, sys, tempfile, time
from datetime import datetime, timezone
from pathlib import Path
scripts = Path(sys.argv.pop(1)).resolve()
sys.path.insert(0, str(scripts))
from case_manifest import WHERE, argv, classify, positive, regular_bytes, regular_text, run

try:
    raw = sys.argv[1:]
    oi, pi = raw.index('--original'), raw.index('--port')
    original, port = raw[oi + 1:pi], raw[pi + 1:]
    if oi >= pi or not original or not port: raise ValueError('both original and port commands are required')
    parser = argparse.ArgumentParser()
    parser.add_argument('--args', default='')
    parser.add_argument('--class', dest='kind', choices=['lines', 'csv', 'ints', 'argv'], default='lines')
    bounds = parser.add_mutually_exclusive_group()
    bounds.add_argument('--seeds', type=int, default=20)
    bounds.add_argument('--minutes', type=positive)
    parser.add_argument('--start-seed', type=int, default=1)
    parser.add_argument('--size', type=int)
    parser.add_argument('--lang', choices=['python', 'js', 'go', 'rust', 'c'])
    parser.add_argument('--gen')
    parser.add_argument('--out-dir', default='legacy/inputs/gen')
    parser.add_argument('--no-minimize', action='store_true')
    parser.add_argument('--timeout', type=positive, default=5.0)
    args = parser.parse_args(raw[:oi])
    if args.seeds < 1 or args.start_seed < 0 or args.size is not None and args.size < 1:
        raise ValueError('seeds/size must be positive and start-seed nonnegative')
    template = argv(args.args)
    if args.kind != 'argv' and not any('{input}' in x for x in template):
        raise ValueError('--args must contain {input} outside argv mode')
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    scratch = Path(tempfile.mkdtemp(prefix='dx.'))
    log = out / 'explore.log'
    seen = set(log.read_text().splitlines()) if log.exists() else set()
    old_sigs = {line.split('\t')[1] for line in seen if len(line.split('\t')) > 1}
    start = time.monotonic()
    deadline = start + args.minutes * 60 if args.minutes else float('inf')
    def bounded(command, arguments=()):
        left = deadline - time.monotonic()
        if left <= 0:
            return dict(problem='exploration deadline reached', out=b'', err=b'', rc=None)
        return run(command, arguments, timeout=min(args.timeout, left))
    def arguments(path):
        if args.kind != 'argv':
            return [x.replace('{input}', str(path)) for x in template]
        text = regular_text(path)
        if not text.lstrip().startswith('['):
            raise ValueError('argv generator must emit a JSON string array')
        return argv(text)
    def compare(path):
        av = arguments(path)
        before = regular_bytes(path)
        oracle = bounded(original, av)
        try:
            unchanged = regular_bytes(path) == before
        except OSError:
            unchanged = False
        if not unchanged:
            oracle['problem'] = 'original changed the generated input; isolate mutating programs before comparison'
        actual = bounded(port, av)
        try:
            unchanged = regular_bytes(path) == before
        except OSError:
            unchanged = False
        if not unchanged:
            actual['problem'] = 'generated input changed during comparison'
        if oracle['problem'] or actual['problem']:
            return None, actual, oracle
        fields = tuple(k for k in ('rc', 'out', 'err') if oracle[k] != actual[k])
        return fields, actual, oracle
    seeds = mismatches = inconclusive = new = dup = 0
    files = []
    seed = args.start_seed
    while time.monotonic() < deadline and (args.minutes or seeds < args.seeds):
        command = ['bash', '-c', args.gen.replace('{seed}', str(seed))] if args.gen else [
            sys.executable, '-B', str(scripts / 'case-gen.py'), '--class', args.kind, '--seed', str(seed)]
        if not args.gen:
            if args.size is not None: command += ['--size', str(args.size)]
            if args.lang: command += ['--lang', args.lang]
        generated = bounded(command)
        seeds += 1
        if generated['problem'] or generated['rc'] != 0:
            inconclusive += 1
            print(f'INCONCLUSIVE seed={seed}: generator {generated["problem"] or generated["err"]!r}')
            seed += 1
            continue
        source = scratch / f'in.{seed}'
        source.write_bytes(generated['out'])
        try:
            kind, actual, oracle = compare(source)
        except (OSError, ValueError) as exc:
            inconclusive += 1
            print(f'INCONCLUSIVE seed={seed}: invalid generated arguments: {exc}')
            seed += 1
            continue
        if kind is None:
            inconclusive += 1
            print(f'INCONCLUSIVE seed={seed}: original={oracle["problem"]!r} port={actual["problem"]!r}')
            seed += 1
            continue
        if not kind:
            seed += 1
            continue
        mismatches += 1
        minimum = source
        if not args.no_minimize and args.kind != 'argv':
            lines = source.read_bytes().splitlines(keepends=True)
            chunk = len(lines) // 2
            candidate_id = 0
            while chunk >= 1 and time.monotonic() < deadline:
                progressed, offset = False, 0
                while offset < len(lines) and time.monotonic() < deadline:
                    smaller = lines[:offset] + lines[offset + chunk:]
                    candidate_id += 1
                    candidate = scratch / f'candidate.{seed}.{candidate_id}'
                    candidate.write_bytes(b''.join(smaller))
                    new_kind, new_actual, new_oracle = compare(candidate)
                    if new_kind == kind:
                        lines, minimum = smaller, candidate
                        actual, oracle, progressed = new_actual, new_oracle, True
                    else:
                        offset += chunk
                if not progressed: chunk //= 2
        cls, detail = classify(actual, oracle)
        # A unique artifact directory preserves earlier runs with the same seed.
        artifact = Path(tempfile.mkdtemp(prefix=f'{args.kind}-{seed}.', dir=out))
        saved = artifact / ('input.json' if args.kind == 'argv' else 'input.txt')
        saved.write_bytes(minimum.read_bytes())
        sig = f'{cls}:{WHERE[cls]}:{hashlib.sha256(saved.read_bytes()).hexdigest()}'
        status = 'DUP' if sig in old_sigs else 'NEW'
        dup += status == 'DUP'
        new += status == 'NEW'
        old_sigs.add(sig)
        with log.open('a') as stream:
            stream.write(f'{datetime.now(timezone.utc).isoformat()}\t{sig}\tseed={seed}\t{saved}\n')
        # Preserve the observed pair and the command used to observe it; paths
        # may affect a program, so capture/retest the proposed saved path itself.
        for label, result in (('original', oracle), ('port', actual)):
            (artifact / f'{label}.out').write_bytes(result['out'])
            (artifact / f'{label}.err').write_bytes(result['err'])
            (artifact / f'{label}.exit').write_text(str(result['rc']) + '\n')
        (artifact / 'observation.json').write_text(json.dumps({'observed_input': str(minimum),
            'original': original, 'port': port, 'argv': arguments(minimum), 'class': cls, 'detail': detail}, indent=2) + '\n')
        case_name = 'gen_' + artifact.name.replace('-', '_').replace('.', '_')
        row = f'{case_name}\t{json.dumps(arguments(saved))}\n'
        (artifact / 'proposed.tsv').write_text(row)
        print(f'MISMATCH seed={seed} {status} {cls} -> {WHERE[cls]}: {detail[:160]}')
        print('proposed row: ' + row.rstrip('\n'))
        files.append(str(saved))
        seed += 1
    if seeds == 0:
        inconclusive += 1
        print('INCONCLUSIVE: no generated case ran before the deadline')
    rev = bounded(['git', 'rev-parse', '--short', 'HEAD'])
    bend = shlex.split(os.environ.get('BEND_CLI', 'bend'))
    version = bounded(bend, ['--version']) if bend else dict(out=b'')
    result = dict(schema='p2b.diff-explore.v1', sha=rev['out'].decode().strip(),
        bend=version['out'].decode(errors='replace').strip(), host=platform.platform(),
        **{'class': args.kind}, seeds=seeds, mismatches=mismatches, inconclusive=inconclusive,
        new=new, dup=dup, cases=files, minutes=(time.monotonic() - start) / 60,
        verdict='INCONCLUSIVE' if inconclusive else 'DIFFERENCES' if mismatches else 'NO_DIFFERENCE_OBSERVED')
    print(json.dumps(result, allow_nan=False))
    sys.exit(1 if mismatches or inconclusive else 0)
except (ValueError, OSError) as exc:
    print(f'error: {exc}', file=sys.stderr)
    sys.exit(2)
PY
