#!/usr/bin/env python3
"""
PreToolUse hook: block edits to template-owned files.
Protected: .claude/, docker/, format/, every .gitignore, every LICENSE file.
Open: .claude/project.md, .claude/settings.local.json, docker/Dockerfile, docker/environment.yml,
and everything under work/.
Unlock: a .claude/.unlock file, created by hand, never by an agent.
Bash: analysis.py finds the paths a command would write; a protected one blocks it.
A target known only at run time counts every protected path the command names.
Reads the hook JSON on stdin; exit 2 blocks the call.
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
# names that mark a protected path in command text
NAMES = r"\.claude/|docker/|format/|\.gitignore|LICENSE"
# path-like runs that name a protected path; LICENSE takes only a . or - suffix
TOKEN = r"[\w./~${}*?-]*(?:\.claude/|docker/|format/|\.gitignore|LICENSE(?!\w))[\w./*?\[\]-]*"


def protected(path):
    """Repo-relative path if path is template-owned, else None."""
    p = Path(path.strip("\"'`(<[{").rstrip("\"'`;:,.)]}>"))
    if not p.is_absolute():
        p = ROOT / p
    try:
        rel = Path(os.path.realpath(p)).relative_to(ROOT).as_posix()
    except ValueError:
        return None
    name = rel.rsplit('/', 1)[-1]
    if rel in OPEN or rel.startswith('work/'):
        return None
    if (rel + '/').startswith(OWNED) or name == '.gitignore' or name.startswith('LICENSE'):
        return rel
    return None


if __name__ == '__main__':
    if UNLOCK.exists():
        sys.exit(0)
    hook = json.load(sys.stdin)
    tool = hook.get('tool_name', '')
    args = hook.get('tool_input', {})
    hits = []
    if tool in PATH_TOOLS:
        rel = protected(args.get(PATH_TOOLS[tool], ''))
        hits = [rel] if rel else []
    elif tool == 'Bash':
        cwd = Path(hook.get('cwd') or ROOT)
        found = analysis.targets(args.get('command', ''), cwd, ROOT, TOKEN, NAMES)
        hits = sorted({r for r in map(protected, {str(f) for f in found}) if r})
    if hits:
        print(
            f"blocked: {', '.join(hits)} is template-owned. Shared rule files, skills, docker, format, .gitignore and LICENSE files "
            "change only in the template repo (github.com/devansh-dvj/.claude) and arrive here by sync. "
            "Ask the user; only they may create .claude/.unlock.",
            file=sys.stderr,
        )
        sys.exit(2)
