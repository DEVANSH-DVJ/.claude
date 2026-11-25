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
4. Re-check with `git diff --cached --stat`.
   If anything unrelated, another agent's file, or a large mixed diff is staged, resolve it before step 5:
   - A staged path outside this commit's scope, the session's own or another agent's, stays staged and is never unstaged: step 5 commits only the named paths.
   - More than one concern inside the scope: narrow the pathspec to one concern, commit it, and repeat from step 2 for the next.
   - Two concerns, or another agent's edit, inside one file: do not commit that file, report it, and commit the rest.
5. Commit: `git commit -m "<area>: <short lowercase imperative>" -- <paths>`.
   `git commit -- <paths>` commits each path's working-tree content, not the staged copy, so edit nothing after step 4.
6. Verify: `git status --short` and `git show --stat HEAD`.

Message format: one line, no body, no trailers.

- The area is the top-level directory or component the commit touches (`docker:`, `.claude:`, `docs:`, `scripts:`, a package name).
- The rest is a short lowercase imperative that says what changed.
  A separator, if needed, is `--`, never an em or en dash.
- Examples:
  - `docker: add the dev image for the pptx toolchain`
  - `.claude: drop the upstream/external rules`
  - `format.sh: exclude .venv`
