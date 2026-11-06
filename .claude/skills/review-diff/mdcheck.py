#!/usr/bin/env python3
"""Flag markdown blocks that render as a blob on GitHub.

A block is a paragraph (consecutive plain lines) or a list item with
its continuation lines; its size is the characters GitHub renders.
Prints path:start-end: size for every block over LIMIT; exit 1 if any.
"""
import re
import subprocess
import sys

LIMIT = 240
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


def check(path, limit=LIMIT):
    """Print every oversize block of one file; return their count."""
    lines = open(path, encoding='utf-8').read().split('\n')
    hits = [b for b in blocks(lines) if b[2] > limit]
    for start, end, size, _ in hits:
        print(f'{path}:{start}-{end}: {size} chars')
    return len(hits)


if __name__ == '__main__':
    args = sys.argv[1:]
    limit = LIMIT
    if args[:1] == ['--limit']:
        limit = int(args[1])
        args = args[2:]
    # no paths: every tracked markdown file
    if not args:
        out = subprocess.run(['git', 'ls-files', '-z', '--', '*.md'], capture_output=True, text=True, check=True)
        args = [p for p in out.stdout.split('\0') if p]
    sys.exit(1 if sum(check(p, limit) for p in args) else 0)
