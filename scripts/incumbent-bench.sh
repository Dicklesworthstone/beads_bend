#!/usr/bin/env bash
# incumbent-bench: interleave ORIGINAL and PORT in AB/BA pairs, with medians
# and sample CV (sample standard deviation / mean). Every successful run must
# agree on stdout AND stderr. Nonzero exits never produce a speedup claim.
# usage: incumbent-bench.sh [--runs N] [--warmup W] [--max-cv PCT]
#          [--pin TEXT] [--tag TEXT] [--timeout S]
#          --original <cmd...> --port <cmd...>
# Defaults: runs=5 pairs, warmup=1, max-cv=5, timeout=60s per invocation.
# Exit: 0 MEASURED, 3 REFUSED_CV, 1 failed/mismatched runs, 2 usage.
# ratio is original median / port median, and is null for every refusal.
# A missing --pin makes the result maintenance evidence, not a public claim.
# Explicit executable/argument files are fingerprinted before and after all
# runs; changes return INPUT_CHANGED without a ratio. Pin transitive imports
# and implicit inputs separately: these cannot be discovered from argv alone.
set -uo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
  exit 0
fi
exec python3 -B - "$(dirname "$0")" "$@" <<'PY'
import argparse, hashlib, json, math, os, platform, statistics, sys
from datetime import datetime, timezone
sys.path.insert(0, sys.argv.pop(1))
from case_manifest import command_provenance, positive, run

def nonnegative(text):
    n = int(text)
    if n < 0: raise argparse.ArgumentTypeError('must be nonnegative')
    return n

def finite_cv(text):
    n = float(text)
    if not math.isfinite(n) or n < 0: raise argparse.ArgumentTypeError('must be finite and nonnegative')
    return n

try:
    raw = sys.argv[1:]
    oi, pi = raw.index('--original'), raw.index('--port')
    original, port = raw[oi + 1:pi], raw[pi + 1:]
    if oi >= pi or not original or not port: raise ValueError('original and port commands are required')
    parser = argparse.ArgumentParser()
    parser.add_argument('--runs', type=nonnegative, default=5)
    parser.add_argument('--warmup', type=nonnegative, default=1)
    parser.add_argument('--max-cv', type=finite_cv, default=5.0)
    parser.add_argument('--timeout', type=positive, default=60.0)
    parser.add_argument('--pin', default='')
    parser.add_argument('--tag', default='')
    args = parser.parse_args(raw[:oi])
    if args.runs < 1: raise ValueError('--runs must be positive')
    commands = {'original': original, 'port': port}
    try:
        before = {arm: command_provenance(command) for arm, command in commands.items()}
    except OSError:
        before = None
    samples, warm = {'original': [], 'port': []}, {'original': [], 'port': []}
    for _ in range(args.warmup):
        for arm in commands: warm[arm].append(run(commands[arm], timeout=args.timeout))
    for pair in range(args.runs):
        for arm in ('original', 'port', 'port', 'original'):
            samples[arm].append(run(commands[arm], timeout=args.timeout))
        print(f'pair {pair + 1}/{args.runs}', file=sys.stderr)
    result = {'tag': args.tag, 'pin': args.pin, 'max_cv': args.max_cv, 'ratio': None,
              'fingerprint': {'uname': platform.platform(), 'cpu': platform.processor(),
                              'cores': os.cpu_count(), 'date': datetime.now(timezone.utc).isoformat()}}
    signatures = {}
    for arm, runs in samples.items():
        times = [r['seconds'] * 1000 for r in runs]
        mean = statistics.mean(times)
        cv = 100 * statistics.stdev(times) / mean if len(times) > 1 and mean > 0 else 0.0
        signatures[arm] = {(r['out'], r['err'], r['rc']) for r in warm[arm] + runs}
        result[arm] = {'cmd': commands[arm], 'median_ms': statistics.median(times), 'cv_pct': cv,
                       'exit': runs[0]['rc'], 'sha': hashlib.sha256(runs[0]['out']).hexdigest(),
                       'stderr_sha': hashlib.sha256(runs[0]['err']).hexdigest(), 'samples': len(runs)}
    all_runs = warm['original'] + warm['port'] + samples['original'] + samples['port']
    try:
        unchanged = before is not None and before == {arm: command_provenance(command) for arm, command in commands.items()}
    except OSError:
        unchanged = False
    verdict = ('RUN_FAILED' if any(r['problem'] or r['rc'] != 0 for r in all_runs) else
               'INPUT_CHANGED' if not unchanged else
               'NONDETERMINISTIC_ORIGINAL' if len(signatures['original']) != 1 else
               'NONDETERMINISTIC_PORT' if len(signatures['port']) != 1 else
               'OUTPUT_MISMATCH' if signatures['original'] != signatures['port'] else
               'REFUSED_CV' if any(result[a]['cv_pct'] > args.max_cv for a in commands) else 'MEASURED')
    if verdict == 'MEASURED':
        result['ratio'] = result['original']['median_ms'] / result['port']['median_ms']
    result['verdict'] = verdict
    result['provenance'] = before
    result['claim_pinned'] = bool(args.pin.strip())
    if not result['claim_pinned']: print('note: no incumbent pin; maintenance evidence only', file=sys.stderr)
    print(f"ratio original/port = {result['ratio']}   verdict {verdict}")
    print(json.dumps(result, allow_nan=False))
    sys.exit(0 if verdict == 'MEASURED' else 3 if verdict == 'REFUSED_CV' else 1)
except (ValueError, OSError) as exc:
    print(f'error: {exc}', file=sys.stderr)
    sys.exit(2)
PY
