#!/usr/bin/env python3
"""
PreToolUse hook: block writes to template-owned .claude/, docker/, format/, .gitignore, LICENSE.
Open: work/, .claude/{project.md,settings.local.json}, docker/{Dockerfile,environment.yml}.
Bash: analysis.py finds the paths a command writes; inline code that names one counts as a write.
Unlock: a hand-made .claude/.unlock. Reads the hook JSON on stdin; exit 2 blocks the call.
"""

import json
import os
import sys
from pathlib import Path

# no bytecode cache beside the hook
sys.dont_write_bytecode = True

import analysis

ROOT = Path(__file__).resolve().parents[2]
UNLOCK = ROOT / '.claude' / '.unlock'
OPEN = {
    '.claude/project.md',
    '.claude/settings.local.json',
    'docker/Dockerfile',
    'docker/environment.yml',
}
OWNED = ('.claude/', 'docker/', 'format/')
PATH_TOOLS = {
    'Edit': 'file_path',
    'Write': 'file_path',
    'MultiEdit': 'file_path',
    'NotebookEdit': 'notebook_path',
}
# path-like runs that name a protected path; LICENSE takes only a . or - suffix
TOKEN = r'[\w./~${}*?-]*(?:\.claude/|docker/|format/|\.gitignore|LICENSE(?!\w))[\w./*?\[\]-]*'


def protected(path):
    """Repo-relative path if path is template-owned, else None."""
    p = Path(os.path.realpath(ROOT / path.strip('"\'`(<[{').rstrip('"\'`;:,.)]}>')))
    if not p.is_relative_to(ROOT):
        return None
    rel = p.relative_to(ROOT).as_posix()
    name = rel.rsplit('/', 1)[-1]
    if rel in OPEN or rel.startswith('work/'):
        return None
    if (rel + '/').startswith(OWNED) or name == '.gitignore' or name.startswith('LICENSE'):
        return rel
    return None


def among(test, paths):
    """The paths a test picks, joined for a message."""
    return ', '.join(sorted({r for r in map(test, map(str, paths)) if r}))


if __name__ == '__main__':
    if UNLOCK.exists():
        sys.exit(0)
    hook = json.load(sys.stdin)
    tool, args = hook.get('tool_name', ''), hook.get('tool_input', {})
    found = [args.get(PATH_TOOLS[tool], '')] if tool in PATH_TOOLS else []
    if tool == 'Bash':
        cwd = Path(hook.get('cwd') or ROOT)
        found = analysis.targets(args.get('command', ''), cwd, ROOT, TOKEN)
        if code := among(protected, analysis.CODE):
            analysis.block(
                f'{code} is guarded, and inline code that names it counts as a write; '
                'read it with cat instead.'
            )
    if hits := among(protected, found):
        analysis.block(
            f'{hits} is template-owned. Shared rule files, skills, docker, format, .gitignore and '
            'LICENSE files change only in the template repo (github.com/devansh-dvj/.claude) and '
            'arrive here by sync. Ask the user; only they may create .claude/.unlock.'
        )
