#!/usr/bin/env bash
# argv-explore: probe the ORIGINAL's argument surface, group results by exit
# and first stderr line, and propose one case per distinct signature.
# usage: argv-explore.sh [--commands "a b"] [--flags "--x --y"]
#          [--file PATH] [--out proposed.tsv] [--timeout S] -- <original cmd...>
# Default timeout=5s. JSON argv arrays in proposed rows preserve every argument
# boundary, including empty strings and paths containing spaces. A timeout is
# inconclusive execution evidence, not proof that an argument was accepted.
# Exit: 0 report produced, 2 usage. Goldens are never changed.
set -uo pipefail
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  sed -n '2,/^set -/p' "$0" | sed '$d; s/^# \{0,1\}//'
  exit 0
fi
exec python3 -B - "$(dirname "$0")" "$@" <<'PY'
import argparse, json, sys, tempfile
from pathlib import Path
sys.path.insert(0, sys.argv.pop(1))
from case_manifest import argv, positive, run
try:
    raw = sys.argv[1:]
    split = raw.index('--')
    command = raw[split + 1:]
    if not command: raise ValueError('original command is required after --')
    parser = argparse.ArgumentParser()
    parser.add_argument('--commands', default='')
    parser.add_argument('--flags', default='')
    parser.add_argument('--file')
    parser.add_argument('--out', default='./argv-proposed.tsv')
    parser.add_argument('--timeout', type=positive, default=5.0)
    args = parser.parse_args(raw[:split])
    file = args.file
    if file is None:
        file = str(Path(tempfile.mkdtemp(prefix='argv.')) / 'input.txt')
        Path(file).write_text('x,1\n')
    shapes = [('none', []), ('dashdash', ['--']), ('h', ['-h']), ('help', ['--help']),
              ('v', ['-v']), ('version', ['--version']), ('unknown_cmd', ['frobnicate']),
              ('unknown_flag', ['--no-such-flag']), ('empty_arg', ['']), ('unicode_arg', ['héllo']),
              ('file_only', [file]), ('missing_file', ['/nonexistent/path.txt'])]
    for ci, c in enumerate(argv(args.commands)):
        for name, tail in [('alone', []), ('file', [file]), ('missing', ['/nonexistent/path.txt']),
                           ('extra', [file, 'extra']), ('extra2', [file, 'extra', 'more']),
                           ('num', ['4']), ('nums', ['4', '10']), ('neg', ['-1', '10']),
                           ('zero', ['0', '0']), ('float', ['1.5', '2']),
                           ('huge', ['99999999999999999999', '1']), ('plus', ['+4', '10']),
                           ('fullwidth', ['１２', '3']), ('dashdash', ['--', file])]:
            shapes.append((f'cmd{ci}_{name}', [c] + tail))
        for fi, f in enumerate(argv(args.flags)):
            for name, tail in [('noval', [file, f]), ('bad', [file, f, 'x']), ('neg', [file, f, '-1']),
                               ('zero', [file, f, '0']), ('twice', [file, f, '1', f, '2']),
                               ('eq', [file, f + '=2']), ('before', [f, '2', file]), ('extra', [file, f, '2', 'extra'])]:
                shapes.append((f'cmd{ci}_flag{fi}_{name}', [c] + tail))
    groups, inconclusive = {}, 0
    for name, arguments in shapes:
        result = run(command, arguments, timeout=args.timeout)
        first = result['err'].split(b'\n', 1)[0]
        key = (result['rc'], first, result['problem'])
        groups.setdefault(key, []).append((name, arguments))
        inconclusive += bool(result['problem'])
    with Path(args.out).open('w', encoding='utf-8') as stream:
        stream.write('# name\tJSON argv; one representative per (exit, first stderr line, infrastructure status)\n')
        for (rc, first, problem), members in groups.items():
            print(f'exit={rc} stderr={first!r} status={problem or "observed"}: ' + ', '.join(n for n, _ in members))
            name, arguments = members[0]
            stream.write(f'argv_{name}\t{json.dumps(arguments, ensure_ascii=True)}\n')
    print(json.dumps(dict(shapes=len(shapes), signatures=len(groups), inconclusive=inconclusive, proposed=args.out)))
except (ValueError, OSError) as exc:
    print(f'error: {exc}', file=sys.stderr)
    sys.exit(2)
PY
