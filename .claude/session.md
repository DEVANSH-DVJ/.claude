# Session rules

How I work in any session on this project.
These are project-agnostic; project-specific overrides live in `project.md` or the prompt.

## Persistence across sessions

Rules or project facts learned mid-session go into the right version-controlled file before the session ends: behavioral to `session.md`, project context to `project.md`, engineering to `engineering.md`.
These files are the durable memory that survives across machines and sessions.

## Behavior

- Do small, focused tasks. If a request feels large, ask to split it before starting.
- Minimize token usage: concise responses and diffs, no narration of paths not taken.
- When in doubt, ask. A 30-second clarification beats a mis-reverted change.
- Verify before writing docs. Every technical claim must trace to code read this session, using literal identifiers, not paraphrase. If you can't point to a line, don't write the sentence.
- A search hit is a lead, not a finding: read the surrounding code before drawing a conclusion from it.
- Preserve old content when rewriting a doc: move it under an "Old \<doc\>" section, and delete only once the new version is confirmed working.

## Git / commits

- Do not commit, checkout, push, or open PRs unless explicitly asked in this conversation. Read-only git (`diff`/`status`/`log`) is always fine.
- Only an explicitly-authorized main agent commits; subagents report changes instead of running git writes. Stage and commit by explicit pathspec, never `git add -A`: otherwise a concurrent session's staged files get swept into your commit. Re-check `git status` and `git show --stat` after.
- Never override the commit author/committer identity, and never add `Co-Authored-By` trailers.
- No AI references anywhere that ships: not in code, comments, filenames, or naming.
- For a living notes or status doc, amend successive edits into its single local commit rather than stacking per-update commits, while the commits are still local-only.

## Subagents

- The main session owns reasoning, planning, verdicts, and decisions. Delegate exploration, long analysis, and summarization to subagents; skip agents when delegation costs more than doing the work inline.
- Set each subagent's model and effort explicitly: inheritance is silent and usually wrong. Which model plays which role is a project or prompt override.
- Prefer a fresh launch over resuming for substantial follow-ups; a resumed subagent can silently continue on the parent model.

## Long runs on a shared machine

- Launch long runs in the background with unbuffered output to a log; rely on the completion notification instead of polling status or logs.
- Manage only processes and containers you launched yourself, identified by a name or PID you recorded at launch, never inferred after the fact.
- `pkill -f <pattern>` inside `bash -c` matches its own command line and can kill the shell first; use a character class (`pkill -f '[p]attern'`) or match the child process only.
- Never edit a script while a live run is executing it: the shell reads scripts lazily by byte offset, so an in-place edit can crash the run. Defer the edit, or write a new file.
