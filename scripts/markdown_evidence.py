#!/usr/bin/env python3
"""Shared Markdown evidence parsing for the port's structural gates.

visible_lines(text) preserves line numbers while removing fenced/indented code
and HTML comments. Comment delimiters inside code are literal. Up to three
spaces before a heading or table are normalized for the structural gates.
split_row(line, unescape=False) splits table cells on unescaped pipes;
an even number of backslashes leaves a pipe unescaped. These are deliberately
small parsing helpers, not a Markdown renderer or semantic proof checker.

usage: markdown_evidence.py --help
"""
import argparse
import re


def visible_lines(text):
    """Yield visible lines, with hidden content replaced by blank lines."""
    fence, comment, ticks = None, False, 0
    lines = text.split('\n')
    for number, line in enumerate(lines):
        match = re.match(r'^ {0,3}(`{3,}|~{3,})(.*)$', line)
        if fence:
            if match and match.group(1)[0] == fence[0] and len(match.group(1)) >= fence[1] and not match.group(2).strip():
                fence = None
            yield ''
            continue
        if not comment and match and not (match.group(1)[0] == '`' and '`' in match.group(2)):
            fence = (match.group(1)[0], len(match.group(1)))
            ticks = 0
            yield ''
            continue
        if not comment and (line.startswith('    ') or line.startswith('\t')):
            yield ''
            continue
        if not line.strip(): ticks = 0
        visible, index = [], 0
        while index < len(line):
            if comment:
                end = line.find('-->', index)
                if end < 0: break
                comment, index = False, end + 3
                continue
            if line[index] == '\\' and not ticks and index + 1 < len(line):
                visible.append(line[index:index + 2]); index += 2
                continue
            if line[index] == '`':
                end = index + 1
                while end < len(line) and line[end] == '`': end += 1
                size = end - index
                if ticks == size:
                    ticks = 0
                elif not ticks:
                    # An unmatched backtick is literal, not an open code span.
                    # Search only this paragraph; a block boundary ends it.
                    tail = [line[end:]]
                    for following in lines[number + 1:]:
                        if not following.strip() or re.match(r'^ {0,3}(?:[#|]|`{3,}|~{3,})', following): break
                        tail.append(following)
                    if re.search(r'(?<!`)' + '`' * size + r'(?!`)', '\n'.join(tail)):
                        ticks = size
                visible.append(line[index:end]); index = end
                continue
            if not ticks and line.startswith('<!--', index):
                comment, index = True, index + 4
                continue
            visible.append(line[index]); index += 1
        rendered = ''.join(visible)
        yield re.sub(r'^ {1,3}(?=[#|])', '', rendered)


def split_row(line, unescape=False):
    """Return pipe-delimited cells, retaining escapes unless requested otherwise."""
    if line.startswith('    ') or line.startswith('\t'):
        return None
    body = line.strip()
    if not body.startswith('|'):
        return None
    body = body[1:]
    cells, current, index = [], [], 0
    while index < len(body):
        char = body[index]
        if char == '\\' and index + 1 < len(body):
            following = body[index + 1]
            current.extend([following] if unescape and following in '\\|' else [char, following])
            index += 2
            continue
        if char == '|':
            cells.append(''.join(current).strip())
            current = []
        else:
            current.append(char)
        index += 1
    # A final unescaped pipe closes the row; an escaped pipe belongs to a cell.
    if current or not body.endswith('|'):
        cells.append(''.join(current).strip())
    elif not cells:
        cells.append('')
    return cells


if __name__ == '__main__':
    argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter).parse_args()
