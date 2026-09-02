---
name: review-diff
description: Review the working diff (unstaged, staged, untracked) against this project's engineering rules. Reports findings; changes nothing. Invoke before committing, or when asked to review changes.
disable-model-invocation: false
user-invocable: true
context: fork
background: false
allowed-tools: Read, Grep, Glob, Bash(git diff *), Bash(git status *), Bash(git log *)
---

Review the working diff of this repository and report findings. Change nothing.

1. Collect the diff: `git diff`, `git diff --cached`, `git status --porcelain`. Read untracked files directly.
2. Load the project's own rules as the checklist: `.claude/engineering.md` and `.claude/project.md`.
3. Review every hunk, in priority order:
   - correctness bugs and behavior changes not implied by the task,
   - violations of the loaded rules (diff discipline, comment style, dependency additions),
   - missing symmetry the rules imply (a "why" comment that belongs in the living docs),
   - style only when it obscures meaning.
4. Report one line per finding: `SEVERITY file:line -- issue -- suggested fix`. Severities: BLOCKER / MAJOR / MINOR / NIT. End with a one-paragraph verdict.

Do not edit files, stage, commit, or run formatters. `$ARGUMENTS` may narrow the review to specific paths.
