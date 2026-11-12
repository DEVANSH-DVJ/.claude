#!/usr/bin/env python3
"""
PreToolUse hook: block writes to /tmp, /var/tmp and /dev/shm, here or over ssh, scp and rsync.
Bash: analysis.py finds the paths a command writes; inline code that names one counts as a write.
Blocked outright: mktemp, git worktree, EnterWorktree, and an Agent with a worktree.
Paths resolve after .. and symlinks. Reads stay open, and a repo in a temp folder writes itself.
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
# temp folders, resolved
TEMPS = [os.path.realpath(t) for t in ('/tmp', '/var/tmp', '/dev/shm')]
# path runs that leave the repo: absolute, home or parent
TOKEN = r'(?:/[\w.-]|~(?!\w)|\.\.(?!\w))[\w./*?-]*'


def temp(paths, cwd):
    """The paths in a temp folder and outside the repo once resolved, joined for a message."""
    real = {Path(os.path.realpath(cwd / str(p))) for p in paths}
    hits = [r for r in real if any(map(r.is_relative_to, TEMPS)) and not r.is_relative_to(ROOT)]
    return ', '.join(sorted(map(str, hits)))


if __name__ == '__main__':
    if UNLOCK.exists():
        sys.exit(0)
    hook = json.load(sys.stdin)
    tool, args = hook.get('tool_name', ''), hook.get('tool_input', {})
    cwd = Path(hook.get('cwd') or ROOT)
    # where scratch and development go instead
    work = f"put scratch in the repo's work/, {ROOT}/work/ here, and develop in the repo itself"
    if tool == 'EnterWorktree' or args.get('isolation') == 'worktree':
        analysis.block(f'a worktree lives outside the repo tree; {work}.')
    found = []
    if tool in ('Edit', 'Write', 'MultiEdit', 'NotebookEdit'):
        found = [args.get('notebook_path' if tool == 'NotebookEdit' else 'file_path', '')]
    elif tool == 'Bash':
        found = analysis.targets(args.get('command', ''), cwd, ROOT, TOKEN)
        if analysis.CMDS & {'mktemp', 'git worktree'}:
            analysis.block(f'mktemp and git worktree are blocked outright; {work}.')
        if code := temp(analysis.CODE, cwd):
            analysis.block(
                f'{code} is in a temp folder, and inline code that names it counts as a write; '
                'read it with cat instead.'
            )
    if hits := temp(found + analysis.REMOTE, cwd):
        analysis.block(f'{hits} is in a temp folder; {work}.')
