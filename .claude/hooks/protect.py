#!/usr/bin/env python3
"""
PreToolUse hook: block edits to template-owned files.
Protected: .claude/, docker/, format/, every .gitignore, every LICENSE file.
Open: .claude/project.md, .claude/settings.local.json, docker/Dockerfile, docker/environment.yml.
Unlock: a .claude/.unlock file, created by hand, never by an agent.
Reads the hook JSON on stdin; exit 2 blocks the call.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UNLOCK = ROOT / ".claude" / ".unlock"
OPEN = {
    ".claude/project.md",
    ".claude/settings.local.json",
    "docker/Dockerfile",
    "docker/environment.yml",
}
OWNED = (".claude/", "docker/", "format/")
PATH_TOOLS = {
    "Edit": "file_path",
    "Write": "file_path",
    "MultiEdit": "file_path",
    "NotebookEdit": "notebook_path",
}

# path-like runs that name a protected path
TOKEN_RE = re.compile(
    r"[\w./~${}*?-]*(?:\.claude/|docker/|format/|\.gitignore|LICENSE)[\w./*?\[\]-]*"
)
# a verb counts as a command only at a command position
CMD = r"(?:^|[;&|(]\s*|\n\s*|\bsudo\s+|\bxargs\s+(?:-\S+\s+)*)"
# commands that write: redirects onto a protected path, in-place edits, file ops, one-liners, git reverts
WRITE_RE = re.compile(
    r">[>|]?\s*[\"']?\S*(?:\.claude/|docker/|format/|\.gitignore|LICENSE)" + "|" + CMD + r"(?:"
    r"(?:tee|mv|cp|rm|ln|install|rsync|truncate|chmod|chown|touch|mkdir|dd|patch)\b"
    r"|sed\s+(?:-\S*i|--in-place)"
    r"|perl\s+-\S*i"
    r"|python[0-9.]*\s+(?:-\s*<<|<<|-c\b)"
    r"|(?:perl|ruby|node)\s+-e\b"
    r"|git\s+(?:checkout|restore|rm|mv|stash|clean|apply)\b"
    r")"
)


def protected(path):
    """Repo-relative path if path is template-owned, else None."""
    p = Path(path.strip("\"'`(<[{").rstrip("\"'`;:,.)]}>"))
    if not p.is_absolute():
        p = ROOT / p
    try:
        rel = p.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return None
    name = rel.rsplit("/", 1)[-1]
    if rel in OPEN:
        return None
    if rel.startswith(OWNED) or name == ".gitignore" or name.startswith("LICENSE"):
        return rel
    return None


if __name__ == "__main__":
    if UNLOCK.exists():
        sys.exit(0)
    hook = json.load(sys.stdin)
    tool = hook.get("tool_name", "")
    args = hook.get("tool_input", {})
    hits = []
    if tool in PATH_TOOLS:
        rel = protected(args.get(PATH_TOOLS[tool], ""))
        hits = [rel] if rel else []
    elif tool == "Bash":
        cmd = args.get("command", "")
        if WRITE_RE.search(cmd):
            hits = sorted({r for r in map(protected, TOKEN_RE.findall(cmd)) if r})
    if hits:
        print(
            f"blocked: {', '.join(hits)} is template-owned. Shared rule files, skills, docker, format, .gitignore and LICENSE files "
            "change only in the template repo (github.com/devansh-dvj/.claude) and arrive here by sync. "
            "Ask the user; only they may create .claude/.unlock.",
            file=sys.stderr,
        )
        sys.exit(2)
