#!/usr/bin/env python3
"""
Run protect.py and the scratch.py beside it on the case table here and report mismatches.
The hooks go to a scratch root in work/, beside a home for the ~ cases.
Case line: expect<TAB>command[<TAB>cwd]; \\n, \\\\, @ROOT@, @TILDE@ and "@Tool arg" expand.
BLOCK is exit 2 with "blocked:" on stderr; any other nonzero exit is an ERROR.
Usage: python3 test/hook/run_cases.py [hook], where hook defaults to .claude/hooks/protect.py.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
HOOK = HERE.parents[1] / '.claude' / 'hooks' / 'protect.py'
# the tool_input key an "@Tool arg" line fills
KEYS = {'NotebookEdit': 'notebook_path', 'EnterWorktree': 'name', 'Agent': 'isolation'}

if __name__ == '__main__':
    hook = Path(sys.argv[1]) if len(sys.argv) > 1 else HOOK
    cases = bad = 0
    # the scratch root goes in work/, outside /tmp
    (work := HERE.parents[1] / 'work').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=work) as tmp:
        # scratch root with the hook in place
        root = Path(tmp).resolve() / 'repo'
        home = root.parent / 'home'
        tilde = '~/' + os.path.relpath(root, home)
        copy = root / '.claude' / 'hooks' / 'protect.py'
        # directories the hooks and the cd cases need
        for made in (copy.parent, root / 'docker', root / 'work', home):
            made.mkdir(parents=True)
        shutil.copy(hook, copy)
        # analysis.py and scratch.py beside the hook go along
        for name in ('analysis.py', 'scratch.py'):
            if (module := hook.with_name(name)).exists():
                shutil.copy(module, copy.parent)
        for n, line in enumerate((HERE / 'cases.tsv').read_text().splitlines(), 1):
            # section names and blank lines hold no case
            if line.startswith('#') or not line.strip():
                continue
            expect, shown, *rest = line.split('\t')
            # expand the escapes of the case table
            command = re.sub(r'\\([\\n])', lambda m: '\n' if m[1] == 'n' else '\\', shown)
            command = command.replace('@ROOT@', str(root)).replace('@TILDE@', tilde)
            cwd = str(root / rest[0] if rest else root)
            event = {'tool_name': 'Bash', 'tool_input': {'command': command}, 'cwd': cwd}
            # "@Tool arg" sends a tool call
            if m := re.fullmatch(r'@(\w+) (.+)', command):
                tool_input = {KEYS.get(m[1], 'file_path'): m[2]}
                event = {'tool_name': m[1], 'tool_input': tool_input, 'cwd': cwd}
            # every hook runs, up to a nonzero exit
            for h in [copy, copy.with_name('scratch.py')]:
                run = subprocess.run(
                    [sys.executable, str(h)],
                    input=json.dumps(event),
                    capture_output=True,
                    text=True,
                    check=False,
                    env={**os.environ, 'HOME': str(home)},
                )
                if run.returncode:
                    break
            got = 'ALLOW' if not run.returncode else f'ERROR({run.returncode})'
            got = 'BLOCK' if run.returncode == 2 and 'blocked:' in run.stderr else got
            cases += 1
            if got != expect:
                bad += 1
                where = f' [cwd={rest[0]}]' if rest else ''
                print(f'MISMATCH line {n}: expect {expect} got {got}{where}: {shown}')
    print(f'TOTAL: {cases} cases, {cases - bad} pass, {bad} mismatch')
    sys.exit(1 if bad else 0)
