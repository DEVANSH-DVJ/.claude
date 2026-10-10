#!/usr/bin/env python3
"""
Run the protect.py hook against the case table beside this file and report mismatches.
The hook and its analysis.py go to a scratch root, so ROOT is that root and no unlock file applies.
The root holds docker/ and work/, beside a sibling repo and a home directory for the cd cases.
Case line: expect<TAB>command[<TAB>cwd]; \\n, \\\\, @ROOT@, @TILDE@ and "@Tool path" expand.
Usage: python3 test/hook/run_cases.py [hook]
Without an argument the hook is .claude/hooks/protect.py of this repo.
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
VERDICT = {0: 'ALLOW', 2: 'BLOCK'}

if __name__ == '__main__':
    hook = Path(sys.argv[1]) if len(sys.argv) > 1 else HOOK
    cases = bad = 0
    with tempfile.TemporaryDirectory() as tmp:
        # scratch root with the hook in place
        root = Path(tmp).resolve() / 'repo'
        home = root.parent / 'home'
        tilde = '~/' + os.path.relpath(root, home)
        copy = root / '.claude' / 'hooks' / 'protect.py'
        # directories the cd cases move into
        away = (root.parent / 'other-repo', home / 'PROJECTS' / 'other-repo')
        for made in (copy.parent, root / 'docker', root / 'work', *away):
            made.mkdir(parents=True)
        shutil.copy(hook, copy)
        # the analysis module beside the hook goes along
        if (module := hook.with_name('analysis.py')).exists():
            shutil.copy(module, copy.parent)
        for n, line in enumerate((HERE / 'cases.tsv').read_text().splitlines(), 1):
            # section names and blank lines hold no case
            if line.startswith('#') or not line.strip():
                continue
            expect, shown, *rest = line.split('\t')
            # expand the escapes of the case table
            command = re.sub(r"\\([\\n])", lambda m: '\n' if m[1] == 'n' else '\\', shown)
            command = command.replace('@ROOT@', str(root)).replace('@TILDE@', tilde)
            cwd = str(root / rest[0] if rest else root)
            event = {'tool_name': 'Bash', 'tool_input': {'command': command}, 'cwd': cwd}
            # "@Tool path" sends a path tool call
            if m := re.fullmatch(r"@(\w+) (.+)", command):
                key = 'notebook_path' if m[1] == 'NotebookEdit' else 'file_path'
                event = {'tool_name': m[1], 'tool_input': {key: m[2]}, 'cwd': cwd}
            run = subprocess.run(
                [sys.executable, str(copy)],
                input=json.dumps(event),
                capture_output=True,
                text=True,
                check=False,
                env={**os.environ, 'HOME': str(home)},
            )
            got = VERDICT.get(run.returncode, f"ERROR({run.returncode})")
            cases += 1
            if got != expect:
                bad += 1
                where = f" [cwd={rest[0]}]" if rest else ''
                print(f"MISMATCH line {n}: expect {expect} got {got}{where}: {shown}")
    print(f"TOTAL: {cases} cases, {cases - bad} pass, {bad} mismatch")
    sys.exit(1 if bad else 0)
