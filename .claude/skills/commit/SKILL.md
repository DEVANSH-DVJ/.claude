---
name: commit
description: Guided safe commit -- stage explicit paths, check the diff, commit by pathspec with a clean message. User-invoked only.
disable-model-invocation: true
user-invocable: true
argument-hint: [paths...]
allowed-tools: Bash(git status *), Bash(git diff *), Bash(git add -- *), Bash(git commit *), Bash(git show *), Read
---

Make one focused, safe commit. Never override author identity, never add Co-Authored-By trailers, never use `git add -A` / `git commit -a`.

1. Show state: `git status --short` and `git diff --stat`.
2. Decide scope: one concern per commit. If `$ARGUMENTS` names paths, use them; otherwise propose an explicit pathspec and confirm with the user.
3. Stage by explicit pathspec: `git add -- <paths>`.
4. Re-check: `git diff --cached --stat`. Confirm nothing unrelated, or another agent's files, got staged.
5. Commit: `git commit -m "<imperative subject, no em-dash, describes the change>" -- <paths>`.
6. Verify: `git show --stat HEAD`.

If anything looks off (unrelated staged files, a large mixed diff), stop and ask before committing.
