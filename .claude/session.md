# Session rules

How I work in any session on this project.
These are project-agnostic; project-specific overrides live in `project.md` or the prompt.

## Persistence across sessions

- Record only what a later session needs and cannot get from the code: a durable fact about the project, or a preference the owner states as standing.
- An instruction for the task at hand, a decision about current work, or a correction to this session is followed now and not recorded as a rule; if a later session must know it, it goes in the living status doc.
- Before adding or changing a line in a rule file, show the owner the exact line and its place, and write it only on a yes.
- Write a rule as narrow as it was said: name the case it covers, and never widen one remark into a general "never" or "always".
- Replace or tighten an existing line before appending a new one, and remove a line the new one supersedes in the same edit.

## What `project.md` holds

- What is true of the whole project for as long as it exists: no status, dates, counts, or commit hashes, and nothing about one deliverable or the content of the work; those go in the status doc or that deliverable's plan.
- Each fact once: when the README, a run doc, a skill, or a shared rule already says it, point there, and keep the layout to directories and entry points, not what each file does.
- Every line sits under one of the file's sections; a project's own standing rule goes under Overrides, naming the shared rule it overrides when it does; a line that fits no section does not belong in the file.
- One rule per bullet, about 40 words at most, with no tag for who said it or when.
- The file stays under 1,000 words; a line that would take it past that replaces something else.
- A change that removes or renames something the file names fixes that line in the same commit.

## Behavior

- Do small, focused tasks. If a request feels large, ask to split it before starting.
- Minimize token usage: concise responses and diffs, no narration of paths not taken.
- When in doubt, ask. A 30-second clarification beats a mis-reverted change.
- Verify before writing docs. Every technical claim must trace to code read this session, using literal identifiers, not paraphrase. If you can't point to a line, don't write the sentence.
- The living status doc holds the present only: status, open items, decisions in force, traps, and the latest figure per measurement. An update replaces the line it supersedes.
- The status doc takes no dated or per-session entry. A measurement series worth keeping is one table with a row per run, not a section per run.
- The status doc aims under 15,000 characters. Past 20,000, the next edit first compresses it back under 15,000: finished items deleted, a series folded into one table, duplicate lines merged.
- A search hit is a lead, not a finding: read the surrounding code before drawing a conclusion from it.
- Preserve old content when rewriting a doc: move it under an "Old \<doc\>" section, and delete only once the new version is confirmed working.
- Drafts and scratch files live in the repo's gitignored `work/`, where the owner can follow them in the editor; never in a temp directory outside the repo.

## Git / commits

- Do not commit, checkout, push, or open PRs unless explicitly asked in this conversation. Read-only git (`diff`/`status`/`log`) is always fine.
- Only an explicitly-authorized main agent commits; subagents report changes instead of running git writes. Stage and commit by explicit pathspec, never `git add -A`: otherwise a concurrent session's staged files get swept into your commit. Re-check `git status` and `git show --stat` after.
- Commit messages are one line, `<area>: <short lowercase imperative>`, where the area is the directory or component touched; no body, no trailers.
- Never override the commit author/committer identity, and never add `Co-Authored-By` trailers.
- A session leaves a clean history whether or not it is pushed: a correction to one of its own commits is folded into that commit, never stacked on top, so no commit adds what a later one removes.
- No AI references anywhere that ships: not in code, comments, filenames, naming, or file metadata such as a draw.io `agent` attribute or a document author field.
- For a living notes or status doc, amend successive edits into its single local commit rather than stacking per-update commits, while the commits are still local-only.

## Subagents

- The main session is the orchestrator: it holds the conversation, the plan, decisions, and verdicts, and keeps its own context small so one thread can run long. Subagents do the work.
- Delegate by default: exploration, reading or searching beyond a file or two, builds, tests, long runs, log and image inspection, and any edit beyond a few lines. Keep inline only single-fact lookups, one-line edits, and answers to the user.
- Launch subagents in the background and end the turn with a status line; never sit in a tool loop waiting for one.
- Never pull bulk output into the main context: no large file reads, no raw logs, no full diffs, no image dumps. Ask a subagent for the extract, the verdict, or the `file:line` pointers instead.
- Every launch is self-contained: goal, paths, constraints, which rule files to read, and the exact report shape and size cap. A subagent sees nothing of the conversation unless it is a fork.
- An agent that edits reads `engineering.md`, `project.md`, and the comment doctrine before its first edit, formats only the files it touched, and reports every change as `file:line`.
- Parallel agents never share a write path: partition edits by path before launching, give each its own scratch dir and run names, and leave shared docs (README, status, `project.md`) to the main session. When partitions must overlap, give the agent a worktree and bring its diff back afterwards.
- Subagents report, never decide: a bounded summary with pointers, findings, and open questions. The main session verifies by spot-check or a second subagent, not by redoing the work.
- Set each subagent's model and effort explicitly: inheritance is silent and usually wrong. Which model plays which role is a project or prompt override.
- Prefer a fresh launch over resuming for substantial follow-ups; a resumed subagent can silently continue on the parent model.
- Subagents never run git writes; they report changes and the main session commits when asked.
- Checkpoint the thread's running state (done, decided, next) into the living status doc, not only into context, so a summarized or resumed thread picks up cleanly.

## Runs, watchers, and staying reachable

- The main session stays reachable: no foreground command or wait longer than about a minute, and never a foreground sleep or poll loop. Anything longer runs in the background with unbuffered output to a log, and the turn ends with a one-line status so the user can speak at any time.
- A user message always comes first: when one arrives mid-task, act on it before continuing, and re-plan if it changes the work.
- Record every launch at launch: what it is, its task id, PID, or container name, its log path, its expected duration, and the one command that checks it. Manage only what you launched, by that record, never something inferred after the fact.
- Watchers always have a deadline and always emit a line, on success, failure, or timeout. Silence is never success.
- Rely on the completion notification, with one fallback: if nothing has arrived by the expected duration, run the recorded check once. Never poll in a loop, never stack watchers on the same job.
- Keep few things in flight, a handful of runs and agents at most, and stop your own stale watchers and agents by their recorded ids before launching replacements.
- `pkill -f <pattern>` inside `bash -c` matches its own command line and can kill the shell first; use a character class (`pkill -f '[p]attern'`) or match the child process only.
- Never edit a script while a live run is executing it: the shell reads scripts lazily by byte offset, so an in-place edit can crash the run. Defer the edit, or write a new file.
