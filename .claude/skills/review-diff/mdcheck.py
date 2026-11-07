#!/usr/bin/env python3
"""Flag markdown blocks that render as a blob on GitHub.

A block is a paragraph (consecutive plain lines) or a list item with
its continuation lines; its size is the characters GitHub renders.
Prints path:start-end: size for every block over LIMIT, as leads.
With --diff, only blocks that touch a line the working tree added or changed
against HEAD count, so an untouched paragraph is never a lead.
"""
import re
import subprocess
import sys

LIMIT = 200
ITEM = re.compile(r'^\s*(?:[-*+]|\d+[.)])\s+')
OTHER = re.compile(r'^\s*(?:#|\||---\s*$)')
QUOTE = re.compile(r'^\s*(?:>\s?)+')


def blocks(lines):
    """Yield (start, end, size, opening) for each paragraph or list item."""
    fence = False
    front = lines[:1] == ['---']
    comment = False
    start = size = 0
    opening = True
    in_item = False
    for i, raw in enumerate(lines, 1):
        # a quoted line renders like an unquoted one
        raw = QUOTE.sub('', raw)
        s = raw.strip()
        # an html comment never renders
        if comment or s.startswith('<!--'):
            comment = '-->' not in s
            s = ''
        elif front:
            front = i == 1 or s != '---'
            s = ''
        elif s.startswith(('```', '~~~')):
            fence = not fence
            s = ''
        elif fence or OTHER.match(s):
            # the opening ends at the first `##`
            opening = opening and not s.startswith('## ')
            s = ''
        item = bool(ITEM.match(raw))
        # a bullet or a break ends the open block
        if (item or not s) and start:
            yield start, i - 1, size, opening and not in_item
            opening = opening and in_item
            start = size = 0
        if not s:
            continue
        if item:
            s = ITEM.sub('', raw).strip()
            in_item = True
        elif not start:
            in_item = False
        start = start or i
        size += len(s) + 1
    if start:
        yield start, len(lines), size, opening and not in_item


def changed_lines(path):
    """Line numbers the working tree added or changed against HEAD; None if untracked."""
    tracked = subprocess.run(['git', 'ls-files', '--error-unmatch', '--', path], capture_output=True)
    if tracked.returncode:
        return None
    out = subprocess.run(['git', 'diff', '-U0', 'HEAD', '--', path], capture_output=True, text=True, check=True)
    changed = set()
    # hunk header: @@ -a,b +c,d @@ ; d defaults to 1
    for m in re.finditer(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', out.stdout, re.M):
        start, count = int(m.group(1)), int(m.group(2) or 1)
        changed.update(range(start, start + count))
    return changed


def check(path, limit=LIMIT, diff=False):
    """Print every oversize block of one file; return their count."""
    lines = open(path, encoding='utf-8').read().split('\n')
    hits = [b for b in blocks(lines) if b[2] > limit]
    if diff:
        changed = changed_lines(path)
        if changed is not None:
            hits = [b for b in hits if any(n in changed for n in range(b[0], b[1] + 1))]
    for start, end, size, _ in hits:
        print(f'{path}:{start}-{end}: {size} chars')
    return len(hits)


if __name__ == '__main__':
    args = sys.argv[1:]
    limit = LIMIT
    diff = False
    while args and args[0].startswith('--'):
        if args[0] == '--limit':
            limit = int(args[1])
            args = args[2:]
        elif args[0] == '--diff':
            diff = True
            args = args[1:]
        else:
            sys.exit(f'unknown flag: {args[0]}')
    # no paths: every tracked markdown file
    if not args:
        out = subprocess.run(['git', 'ls-files', '-z', '--', '*.md'], capture_output=True, text=True, check=True)
        args = [p for p in out.stdout.split('\0') if p]
    for p in args:
        check(p, limit, diff)
