#!/usr/bin/env python3
"""Advisory Claude Code hooks for a scaffolded Bend port; not a shell sandbox.

usage: hook-guard.py MODE < hook-event.json
Modes: pre-edit, pre-read, pre-bash, post-edit, campaign-bash,
       campaign-prompt, stop, campaign-stop.
Exit 2 blocks a detected violation or failed proof. Missing advisory tools or
files are reported as NOT_RUN and exit 0. Shell checks inspect simple commands,
redirections and common shell wrappers; arbitrary programs can evade them.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
sys.dont_write_bytecode = True
import time
from markdown_evidence import visible_lines

MODES = ('pre-edit', 'pre-read', 'pre-bash', 'post-edit', 'campaign-bash', 'campaign-prompt', 'stop', 'campaign-stop')
READERS = {'cat', 'sed', 'head', 'tail', 'less', 'more', 'bat', 'rg', 'grep', 'awk', 'nl', 'od', 'xxd', 'strings', 'diff', 'view', 'vim', 'vi', 'nano', 'code', 'cp', 'install', 'dd'}
WRITERS = {'cp', 'mv', 'rm', 'tee', 'truncate', 'install', 'dd', 'touch', 'ln'}
PROOF = re.compile(r'All terms check(?:, with [0-9]+ unsafe annotations?)?\.')


def warn(message):
    print(message, file=sys.stderr)


def parts(raw, cwd=None):
    """Lexical and resolved paths, scoped to this port's root, not ancestor names."""
    # Tool paths and quoted shell literals are literal. Shell expansion, where
    # supported, happens in the tokenizer while quote provenance is available.
    path = Path(str(raw))
    if not path.is_absolute(): path = (cwd or Path.cwd()) / path
    return (Path(os.path.abspath(path)), path.resolve())


def under(raw, directory, cwd=None):
    roots = parts(directory)
    return any(path.is_relative_to(root) for path in parts(raw, cwd) for root in roots)


def legacy_source(raw, cwd=None):
    legacy, resolved_legacy = parts('legacy')
    inputs, resolved_inputs = parts('legacy/inputs')
    path, resolved = parts(raw, cwd)
    return (path.is_relative_to(legacy) and not path.is_relative_to(inputs)) or (
        resolved.is_relative_to(resolved_legacy) and
        (not resolved.is_relative_to(resolved_inputs) or resolved_inputs != resolved_legacy / 'inputs'))


def phase_three():
    path = Path('docs/PORT_STATE.md')
    if not path.is_file():
        return False
    from case_manifest import regular_text
    return re.search(r'^\|\s*phase\s*\|\s*`?3(?:`?\s|`?\|)', '\n'.join(visible_lines(regular_text(path))), re.M | re.I) is not None


def segments(command):
    # Keep operator provenance: shlex strips quotes, making the literal argument
    # '>' indistinguishable from a redirect (and ';' from a command separator).
    class Token(str):
        def __new__(cls, value, operator=False):
            obj = super().__new__(cls, value); obj.operator = operator; return obj
    tokens, word, active, quote, i = [], [], False, None, 0
    punctuation = ';&|<>()\n'
    while i < len(command):
        ch = command[i]
        if ch == '$' and quote != "'":
            variable = re.match(r'\$(?:\{([A-Za-z_][A-Za-z0-9_]*)\}|([A-Za-z_][A-Za-z0-9_]*))', command[i:])
            if variable:
                word.append(os.environ.get(variable.group(1) or variable.group(2), ''))
                active = True; i += len(variable.group()); continue
        if ch == '~' and not quote and not active and (i + 1 == len(command) or command[i + 1] in '/ \t\r\n'):
            word.append(str(Path.home())); active = True; i += 1; continue
        if quote:
            if ch == quote: quote = None
            elif ch == '\\' and quote == '"' and i + 1 < len(command) and command[i + 1] in '$`"\\\n':
                i += 1
                if command[i] != '\n': word.append(command[i])
            else: word.append(ch)
        elif ch in "'\"": quote = ch; active = True
        elif ch == '\\':
            i += 1
            if i == len(command): raise ValueError('unfinished escape')
            if command[i] != '\n': word.append(command[i]); active = True
        elif ch == '#' and not active:
            while i < len(command) and command[i] != '\n': i += 1
            continue
        elif ch in ' \t\r' or ch in punctuation:
            if active: tokens.append(Token(''.join(word))); word = []; active = False
            if ch in punctuation:
                op = ch
                for candidate in ('&>>', ';;&', '&&', '||', '>>', '<<', '>&', '<&', '&>', '|&', ';;', ';&'):
                    if command.startswith(candidate, i): op = candidate; break
                i += len(op) - 1
                tokens.append(Token(op, True))
        else: word.append(ch); active = True
        i += 1
    if quote: raise ValueError('unfinished quote')
    if active: tokens.append(Token(''.join(word)))
    result, current = [], []
    for token in tokens:
        if token.operator and all(char in ';&|()\n' for char in token):
            if current:
                result.append(current)
                current = []
            result.append([token])
        else:
            current.append(token)
    if current:
        result.append(current)
    return result


def command_words(words, cwd):
    words = list(words)
    while words and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', words[0]):
        words.pop(0)
    while words and Path(words[0]).name in ('env', 'command', 'builtin', 'sudo'):
        wrapper = words.pop(0)
        while words and (words[0].startswith('-') or re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', words[0])):
            option = words.pop(0)
            name = Path(wrapper).name
            changes_dir = (name == 'env' and option in ('-C', '--chdir')) or (name == 'sudo' and option in ('-D', '--chdir'))
            if changes_dir and words:
                cwd = parts(words.pop(0), cwd)[0]
            elif name in ('env', 'sudo') and option.startswith('--chdir='):
                cwd = parts(option.partition('=')[2], cwd)[0]
            elif (name == 'env' and option.startswith('-C') or name == 'sudo' and option.startswith('-D')) and len(option) > 2:
                cwd = parts(option[2:], cwd)[0]
            consumes = {'env': ('-u', '--unset'), 'sudo': ('-u', '--user', '-g', '--group', '-h', '--host', '-p', '--prompt', '-C', '--close-from')}
            if option in consumes.get(name, ()) and words: words.pop(0)
            if option == '--': break
    return words, cwd


def inspect_shell(command, phase, depth=0, cwd=None):
    """Return (violation, needs-proof, measures). Each segment stands alone."""
    if depth > 4:
        return 'shell wrapper nesting exceeds the advisory parser; split the command', False, False
    try:
        parsed = segments(command)
    except ValueError:
        # Do not certify syntax this deliberately small parser cannot inspect.
        if 'goldens/' in command or (phase and 'legacy/' in command):
            return 'cannot inspect this shell command; use a simple command for protected paths', False, False
        return '', False, False
    proof, measures = False, False
    cwd = cwd or Path.cwd()
    previous, stack, command_cwd = None, [], cwd
    for raw in parsed:
        if len(raw) == 1 and raw[0].operator:
            if raw[0] == '(': stack.append((cwd, previous))
            elif raw[0] == ')' and stack: cwd, previous = stack.pop()
            elif raw[0] in ('|', '|&', '&'): cwd = command_cwd
            continue
        command_cwd = cwd
        for index, token in enumerate(raw[:-1]):
            if token.operator and '>' in token and set(token) <= set('<>&0123456789') and under(raw[index + 1], 'goldens', cwd):
                return 'shell redirection into goldens is refused; use golden-capture.sh', False, False
            if phase and token.operator and token == '<' and legacy_source(raw[index + 1], cwd):
                return 'Phase 3: reading legacy source is refused; resolve the OQ by running the original', False, False
        words, execution_cwd = command_words(raw, cwd)
        if not words:
            continue
        name = Path(words[0]).name
        args = words[1:]
        if name == 'cd':
            while args and args[0] in ('-P', '-L'): args = args[1:]
            if args[:1] == ['--']: args = args[1:]
            if not args: destination = Path.home()
            elif args == ['-']: destination = previous
            elif len(args) == 1 and not args[0].startswith('-'): destination = parts(args[0], cwd)[0]
            else: destination = None
            if destination is not None and destination.is_dir(): previous, cwd = cwd, destination
            continue
        shell_c = next((i for i, arg in enumerate(args) if re.fullmatch(r'-[a-zA-Z]*c[a-zA-Z]*', arg)), None)
        if name in ('bash', 'sh', 'zsh', 'dash') and shell_c is not None:
            index = shell_c
            if index + 1 < len(args):
                error, nested_proof, nested_measures = inspect_shell(args[index + 1], phase, depth + 1, execution_cwd)
                if error:
                    return error, False, False
                proof |= nested_proof
                measures |= nested_measures
        is_writer = name in WRITERS or (name == 'sed' and any(arg.startswith('-i') or arg.startswith('--in-place') for arg in args))
        targets = [arg for arg in args if not arg.startswith('-')]
        if name in ('cp', 'install'):
            explicit = [args[i + 1] for i, arg in enumerate(args[:-1]) if arg in ('-t', '--target-directory')]
            explicit += [arg.split('=', 1)[1] for arg in args if arg.startswith('--target-directory=')]
            explicit += [arg[2:] for arg in args if arg.startswith('-t') and len(arg) > 2]
            targets = explicit or targets[-1:]
        elif name == 'dd':
            targets = [arg.split('=', 1)[1] for arg in args if arg.startswith('of=')]
        if is_writer and any(under(arg, 'goldens', execution_cwd) for arg in targets):
            return 'shell write involving goldens is refused; use golden-capture.sh', False, False
        read_targets = [arg for arg in args if not arg.startswith('-')]
        if name == 'dd': read_targets = [arg.partition('=')[2] for arg in args if arg.startswith('if=')]
        if name in ('rg', 'grep', 'sed', 'awk'):
            read_targets += [arg.partition('=')[2] for arg in args if arg.startswith(('--file=', '--exclude-from='))]
            read_targets += [arg[2:] for arg in args if arg.startswith('-f') and len(arg) > 2]
        if phase and name in READERS and any(legacy_source(arg, execution_cwd) for arg in read_targets):
            return 'Phase 3: reading legacy source is refused; resolve the OQ by running the original', False, False
        if name == 'git' and 'commit' in args:
            proof = True
        measures |= name in ('bench-speedup.sh', 'incumbent-bench.sh') or (name in ('bash', 'sh') and any(Path(arg).name in ('bench-speedup.sh', 'incumbent-bench.sh') for arg in args))
    return '', proof, measures


def check_proof(directory):
    try:
        from case_manifest import run
    except ImportError:
        warn('proof NOT_RUN: scripts/case_manifest.py is unavailable')
        return 0
    proof = directory / 'PROOF.bend'
    try:
        cli = shlex.split(os.environ.get('BEND_CLI', 'bend'))
    except ValueError as exc:
        warn(f'proof gate RED: malformed BEND_CLI: {exc}')
        return 2
    if not proof.is_file() or not cli or shutil.which(cli[0]) is None:
        warn(f'proof NOT_RUN: {proof} or the configured Bend executable is unavailable')
        return 0
    os.environ['BEND_NO_TELEMETRY'] = '1'
    try:
        result = run(cli, ['PROOF.bend'], timeout=120, cwd=directory, merge_stderr=True)
    except (OSError, ValueError) as exc:
        warn(f'proof gate RED: {exc}')
        return 2
    rc = result['rc']
    lines = (result['out'] + result['err']).decode('utf-8', errors='replace').rstrip().splitlines()
    if not result['problem'] and rc == 0 and lines and PROOF.fullmatch(lines[-1]):
        return 0
    warn(f'proof gate RED in {proof} (exit {rc}):\n' + '\n'.join(lines[:20]))
    return 2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=MODES)
    mode = parser.parse_args().mode
    try:
        event = json.load(sys.stdin)
        data = event.get('tool_input') or {}
        if not isinstance(data, dict):
            raise ValueError('tool_input is not an object')
    except (ValueError, AttributeError):
        warn('hook NOT_RUN: malformed event JSON')
        return 0
    path = str(data.get('file_path') or data.get('path') or '')
    if mode == 'pre-edit' and path and under(path, 'goldens'):
        warn('goldens are captured, never edited: use scripts/golden-capture.sh --repin "<reason>"')
        return 2
    if mode == 'pre-read' and path and phase_three() and legacy_source(path):
        warn('Phase 3: legacy source is closed; run the original to resolve an OQ')
        return 2
    if mode == 'post-edit' and path and under(path, 'port') and path.endswith('.bend'):
        return check_proof(Path('port').resolve())
    if mode in ('pre-bash', 'campaign-bash'):
        error, proof, measures = inspect_shell(str(data.get('command') or ''), phase_three())
        if mode == 'pre-bash':
            if error:
                warn(error)
                return 2
            if proof:
                return check_proof(Path('port').resolve())
        elif error:
            warn(error)
            return 2
        elif measures:
            stamp = Path('perf/.sweep-ok')
            age = time.time() - stamp.stat().st_mtime if stamp.is_file() else None
            if age is None or not 0 <= age <= 3600:
                warn('no valid graveyard sweep in the last hour: run scripts/graveyard-sweep.sh and write the experiment card before timing')
                return 2
    if mode == 'campaign-prompt' and re.search(r'faster|optimi[sz]e|speed|lever|perf|benchmark', str(event.get('prompt') or ''), re.I):
        print('porting-to-bend2: parity gate, graveyard sweep, experiment card, kill-switch, fast == spec law, measured capture, ledger, then lanes again. A refused capture is NO_EVIDENCE.')
    if mode in ('stop', 'campaign-stop') and Path('docs/PORT_STATE.md').is_file():
        for script in ('scripts/state-check.sh', 'scripts/claims-lint.sh'):
            if Path(script).is_file() and os.access(script, os.X_OK):
                try:
                    from case_manifest import run
                    result = run([str(Path(script).resolve()), 'docs/PORT_STATE.md'], timeout=30)
                    warn(f"{script}: exit {result['rc']}\n" + '\n'.join((result['out'] + result['err']).decode('utf-8', errors='replace').splitlines()[-6:]))
                except (ImportError, OSError, ValueError) as exc:
                    warn(f'{script}: NOT_RUN: {exc}')
        if mode == 'campaign-stop' and shutil.which('git'):
            for args in (['status', '--porcelain'], ['rev-list', '--count', '@{u}..HEAD']):
                try:
                    result = subprocess.run(['git', *args], capture_output=True, text=True, timeout=15, check=False)
                    warn(f'git {" ".join(args)} (exit {result.returncode}): {result.stdout.strip() or result.stderr.strip() or "clean"}')
                except (OSError, subprocess.TimeoutExpired) as exc:
                    warn(f'git status NOT_RUN: {exc}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
