---
name: commit
description: Guided safe commit -- stage explicit paths, check the diff, commit by pathspec with a clean message. Use when the user asks to commit.
user-invocable: true
argument-hint: "[paths...]"
allowed-tools: Bash(git status *), Bash(git diff *), Bash(git add -- *), Bash(git commit *), Bash(git show *), Read
---

Make one focused, safe commit. Never override author identity, never add Co-Authored-By trailers, never use `git add -A` / `git commit -a`.

1. Show state: `git status --short` and `git diff --stat`.
2. Decide scope: one concern per commit. If `$ARGUMENTS` names paths, use them; otherwise choose an explicit pathspec covering what this task changed.
3. Stage by explicit pathspec: `git add -- <paths>`.
4. Re-check: `git diff --cached --stat`. Confirm nothing unrelated, or another agent's files, got staged.
5. Commit: `git commit -m "<area>: <short lowercase imperative>" -- <paths>`.
6. Verify: `git show --stat HEAD`.

Message format: one line, no body, no trailers.
The area is the top-level directory or component the commit touches (`docker:`, `.claude:`, `docs:`, `scripts:`, a package name); the rest is a short lowercase imperative that says what changed, with `--` rather than a dash if a separator is needed.
Examples: `docker: add the dev image for the pptx toolchain`, `.claude: drop the upstream/external rules`, `format.sh: exclude .venv`.

If anything looks off (unrelated staged files, a large mixed diff), do not commit -- report the concern and continue.
