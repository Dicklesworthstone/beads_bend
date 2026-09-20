#!/usr/bin/env bash
# cases-lint: validate the same manifest syntax consumed by capture/conform.
# usage: cases-lint.sh [goldens/cases.tsv] [--commands "a b"]
# Names are unique safe filenames. Argv accepts JSON string arrays or legacy
# whitespace-separated words. A name-only row has no args; empty or '-' stdin
# means /dev/null. Later columns are annotations, never part of the stdin path.
# Missing argv paths are notes (an intentional missing-file case may need them).
# Name heuristics flag absent usage, empty, error and edge/large classes;
# --commands checks exact first-argument presence, which alone does not prove
# that a command has a successful happy-path test. Commands also accept JSON.
# Exit: 0 OK (notes allowed), 1 invalid manifest/stdin/no cases, 2 usage.
# Last line JSON: cases, errors, notes, classes_missing, verdict.
set -uo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
  exit 0
fi
exec python3 -B - "$(dirname "$0")" "$@" <<'PY'
import argparse, json, re, sys
from pathlib import Path
sys.path.insert(0, sys.argv.pop(1))
from case_manifest import argv, cases
parser = argparse.ArgumentParser()
parser.add_argument('manifest', nargs='?', default='goldens/cases.tsv')
parser.add_argument('--commands', default='')
args = parser.parse_args()
try:
    commands = argv(args.commands)
except ValueError as exc:
    parser.error(str(exc))
errors, notes, missing = [], [], []
try:
    rows = cases(args.manifest)
except (OSError, ValueError) as exc:
    errors.append(str(exc))
    rows = []
if not rows and not errors:
    errors.append('no cases')
for name, arguments, stdin in rows:
    if stdin:
        try:
            regular_input = Path(stdin).is_file()
        except (OSError, ValueError):
            regular_input = False
        if not regular_input:
            errors.append(f'{name}: stdin file {stdin!r} does not exist or is not a regular file')
    for token in arguments:
        if '/' in token or token.endswith(('.csv', '.txt', '.json')):
            try:
                exists = Path(token).exists()
            except OSError:
                exists = False
            if not exists:
                notes.append(f'{name}: path {token!r} does not exist (fine only for an intentional missing-file case)')
names = [row[0].lower() for row in rows]
for label, pattern in [('usage', r'usage|help'), ('empty', r'empty'), ('error', r'bad|error|missing|invalid'),
                       ('edge/large', r'big|large|max|bound|[0-9]{4}')]:
    if not any(re.search(pattern, name) for name in names):
        missing.append(label)
for command in commands:
    if not any(arguments and arguments[0] == command for _, arguments, _ in rows):
        missing.append('happy:' + command)
if missing:
    notes.append('classes/command words without a case by heuristic: ' + ', '.join(missing))
for message in errors:
    print('ERROR ' + message)
for message in notes:
    print('note ' + message)
verdict = 'ERRORS' if errors else 'OK'
print(f'cases-lint: {len(rows)} cases, {len(errors)} errors, {len(notes)} notes -> {verdict}')
print(json.dumps({'cases': len(rows), 'errors': len(errors), 'notes': len(notes),
                  'classes_missing': ','.join(missing), 'verdict': verdict}, allow_nan=False))
sys.exit(1 if errors else 0)
PY
