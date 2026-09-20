#!/usr/bin/env bash
# perf-tripwire: maintenance regression checks for port/main.bend.
# usage: perf-tripwire.sh [--pin] [--threads N] [--runs 3] [--slack 1.15]
#          [--timeout S] [--pin-file perf/PIN.txt] [perf/PIN-INPUTS.tsv]
# Builds once, warms each SEQ/PAR CPU cell, then records median wall seconds,
# maximum sampled RSS (KB), and SHA-256 of complete stdout AND stderr bytes.
# Any failed/unstable cell is REFUSED in comparison as well as pin mode.
# Warmup outputs must agree too; removed pinned cells TRIP, and an empty
# input manifest is a usage error that cannot write a pin.
# Pin v2 rows: name, mode, seconds, rss_kb, stdout_sha256, stderr_sha256.
# Pins also require thread and per-case argv/input-hash metadata. Older pins
# without it require explicit recapture; changed workloads are REFUSED.
# Default per-run timeout 60s. Exit 0 OK/PINNED, 1 TRIP/unpinned, 2 usage/build,
# 3 REFUSED. This maintenance check is not a speedup claim protocol.
set -uo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
  exit 0
fi
exec python3 -B - "$(dirname "$0")" "$@" <<'PY'
import argparse, hashlib, json, math, os, platform, re, shlex, shutil, statistics, subprocess, sys, tempfile
from datetime import datetime, timezone
from pathlib import Path
scripts = str(Path(sys.argv.pop(1)).resolve())
sys.path.insert(0, scripts)
from case_manifest import argument_files, cases, file_record, positive, regular_text, run, writable_file

def positive_int(text):
    value = int(text)
    if value < 1: raise argparse.ArgumentTypeError('must be positive')
    return value

def input_records(manifest):
    records = {}
    for name, arguments, stdin in manifest:
        files = {operand: file_record(operand)['sha256'] for operand in argument_files(arguments)}
        records[name] = {'argv': arguments, 'stdin': stdin, 'files': files}
    return records

worker = '''import hashlib,json,resource,sys
sys.path.insert(0,sys.argv[1])
from case_manifest import run
r=run(sys.argv[3:],timeout=float(sys.argv[2]))
rss=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
print(json.dumps(dict(s=r['seconds'],rss=int(rss/1024 if sys.platform=='darwin' else rss),rc=r['rc'],problem=r['problem'],stdout=hashlib.sha256(r['out']).hexdigest(),stderr=hashlib.sha256(r['err']).hexdigest())))'''

try:
    parser = argparse.ArgumentParser()
    parser.add_argument('--pin', action='store_true')
    parser.add_argument('--threads', type=positive_int, default=os.cpu_count() or 4)
    parser.add_argument('--runs', type=positive_int, default=3)
    parser.add_argument('--slack', type=positive, default=1.15)
    parser.add_argument('--timeout', type=positive, default=60.0)
    parser.add_argument('--pin-file', default='perf/PIN.txt')
    parser.add_argument('inputs', nargs='?', default='perf/PIN-INPUTS.tsv')
    args = parser.parse_args()
    if args.slack < 1: raise ValueError('--slack must be at least 1')
    manifest = cases(args.inputs)
    if not manifest: raise ValueError('tripwire input manifest has no cases')
    if any(row[2] for row in manifest): raise ValueError('tripwire inputs use argv only; stdin is not supported')
    if not Path('port/main.bend').is_file(): raise ValueError('run from the port root (port/main.bend)')
    bend = shlex.split(os.environ.get('BEND_CLI', 'bend'))
    if not bend: raise ValueError('BEND_CLI is empty')
    os.environ['BEND_NO_TELEMETRY'] = '1'
    pinfile, old, pinned_inputs, pinned_threads = Path(args.pin_file), {}, None, None
    if args.pin and not writable_file(pinfile):
        raise ValueError('pin destination must be a regular file without symlinks or hardlinks')
    inputs_before = input_records(manifest)
    if not args.pin:
        if not pinfile.is_file(): raise ValueError(f'no pin at {pinfile}; run with --pin')
        for line in regular_text(pinfile).splitlines():
            if line.startswith('# perf-tripwire v2 '):
                thread_field = re.search(r'\bthreads=(\d+)\b', line)
                pinned_threads = int(thread_field[1]) if thread_field else None
            if line.startswith('# inputs: '):
                if pinned_inputs is not None: raise ValueError('duplicate pin input metadata')
                pinned_inputs = json.loads(line[len('# inputs: '):])
            if not line or line.startswith('#'): continue
            fields = line.split('\t')
            if len(fields) != 6 or not all(len(x) == 64 and all(c in '0123456789abcdef' for c in x) for x in fields[4:]):
                raise ValueError('old or invalid pin format; recapture a v2 full-output pin with --pin')
            key = tuple(fields[:2])
            if fields[1] not in ('SEQ-CPU', 'PAR-CPU'): raise ValueError(f'invalid pin mode {fields[1]!r}')
            if key in old: raise ValueError(f'duplicate pin cell {key}')
            sec, rss = float(fields[2]), int(fields[3])
            if not math.isfinite(sec) or sec <= 0 or rss < 0: raise ValueError(f'invalid pin measurements for {key}')
            old[key] = (sec, rss, fields[4], fields[5])
        if not isinstance(pinned_inputs, dict) or pinned_threads is None:
            raise ValueError('pin lacks input/thread provenance; recapture explicitly with --pin')
        if pinned_threads != args.threads:
            raise ValueError(f'pin used --threads {pinned_threads}; comparison requested {args.threads}')
    scratch = Path(tempfile.mkdtemp(prefix='tripwire.'))
    binary = str(scratch / 'x')
    built = run(bend, ['port/main.bend', '-o', binary], timeout=max(300.0, args.timeout))
    if built['problem'] or built['rc'] != 0:
        raise ValueError('build failed: ' + built['err'].decode(errors='replace')[:300])
    rev = run(['git', 'rev-parse', '--short', 'HEAD'])
    sha = rev['out'].decode().strip() if rev['rc'] == 0 else 'none'
    version = run(bend, ['--version'])
    bendv = version['out'].decode(errors='replace').strip()
    rows, trips, unpinned, refused = [], [], [], []
    for name, argv, _ in manifest:
        for mode, threads in (('SEQ-CPU', 1), ('PAR-CPU', args.threads)):
            cmd = [binary, '--threads', str(threads), '--gpu', 'off', '--'] + argv
            warm = run(cmd, timeout=args.timeout)
            samples = []
            for _ in range(args.runs):
                measured = run([sys.executable, '-B', '-c', worker, scripts, str(args.timeout)] + cmd,
                               timeout=args.timeout + 5)
                if measured['problem'] or measured['rc'] != 0:
                    samples.append(dict(s=0, rss=0, rc=None, problem='measurement worker failed', stdout='', stderr=''))
                else:
                    samples.append(json.loads(measured['out']))
            sec = statistics.median(r['s'] for r in samples)
            rss = max(r['rss'] for r in samples)
            signatures = {(r['stdout'], r['stderr']) for r in samples}
            signatures.add((hashlib.sha256(warm['out']).hexdigest(), hashlib.sha256(warm['err']).hexdigest()))
            signature = (samples[0]['stdout'], samples[0]['stderr'])
            key, label = (name, mode), f'{name}/{mode}'
            bad = warm['problem'] or warm['rc'] != 0 or any(r['problem'] or r['rc'] != 0 for r in samples) or len(signatures) != 1
            flag = 'OK'
            if bad:
                refused.append(label)
                flag = 'REFUSED (failed or unstable run)'
            elif not args.pin:
                if key not in old:
                    unpinned.append(label)
                    flag = 'UNPINNED'
                elif pinned_inputs.get(name) != inputs_before[name]:
                    refused.append(label)
                    flag = 'REFUSED (argv or input bytes differ from pin)'
                else:
                    psec, prss, pout, perr = old[key]
                    if sec > psec * args.slack or rss > prss * args.slack or signature != (pout, perr):
                        trips.append(label)
                        flag = 'TRIP (time, maximum RSS, stdout or stderr changed)'
            rows.append((name, mode, sec, rss, *signature))
            print(f'{label:28} {sec:.8f}s {rss}KB {flag}')
    written = False
    if input_records(cases(args.inputs)) != inputs_before:
        refused.append('inputs changed during measurement')
    if not args.pin:
        for name, mode in sorted(set(old) - {(r[0], r[1]) for r in rows}):
            label = f'{name}/{mode}'
            trips.append(label)
            print(f'{label:28} TRIP (pinned cell removed from input manifest)')
    verdict = 'REFUSED' if refused else 'TRIP' if trips or unpinned else 'PINNED' if args.pin else 'OK'
    if args.pin and not refused:
        if not writable_file(pinfile):
            raise ValueError('pin destination changed to a link or special file during measurement')
        pinfile.parent.mkdir(parents=True, exist_ok=True)
        if pinfile.exists():
            backup = Path(tempfile.mkdtemp(prefix='pin-before-repin.')) / pinfile.name
            shutil.copy2(pinfile, backup)
            print(f'previous pin preserved at {backup}')
        with pinfile.open('w') as stream:
            stream.write(f'# perf-tripwire v2 date={datetime.now(timezone.utc).isoformat()} sha={sha} threads={args.threads} runs={args.runs}\n')
            stream.write('# inputs: ' + json.dumps(inputs_before, sort_keys=True, separators=(',', ':')) + '\n')
            stream.write('# name\tmode\tseconds\trss_kb\tstdout_sha256\tstderr_sha256\n')
            for row in rows: stream.write('\t'.join(map(str, row)) + '\n')
        written = True
    result = dict(schema='p2b.perf-tripwire.v2', sha=sha, bend=bendv, host=platform.platform(), threads=args.threads,
                  cells=len(rows), trips=trips, unpinned=unpinned, refused=refused, pin_written=written, verdict=verdict)
    print(json.dumps(result, allow_nan=False))
    sys.exit(0 if verdict in ('OK', 'PINNED') else 3 if verdict == 'REFUSED' else 1)
except (ValueError, OSError) as exc:
    print(f'error: {exc}', file=sys.stderr)
    sys.exit(2)
PY
