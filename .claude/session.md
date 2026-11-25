# Session rules

Project-agnostic session rules.
Project-specific overrides live in `project.md` or the prompt.

## Persistence across sessions

- Record only what a later session needs and cannot get from the code: a durable fact about the project, or a preference the owner states as standing.
- A task instruction, a decision on current work, or a correction to this session is followed now, not recorded as a rule. What a later session must know of it goes in `STATUS.md`.
- Write a rule as narrow as it was said: name the case it covers, and never widen one remark into a general "never" or "always".
- Replace or tighten an existing line before appending a new one, and remove a line the new one supersedes in the same edit.

## What `project.md` holds

- What is true of the whole project for as long as it exists. Status, dates, counts, hashes, and anything about one deliverable or the work's content go in `STATUS.md` or that deliverable's plan.
- Each fact once: when the README, a run doc, a skill, or a shared rule already says it, point there, and keep the layout to directories and entry points, not what each file does.
- Every line sits under one of the file's sections, and a line that fits none does not belong in the file.
- A project's own standing rule goes under Overrides, naming the shared rule it overrides, if any.
- One rule per bullet, about 40 words at most, with no tag for who said it or when.
- The file stays under 1,000 words; a line that would take it past that replaces something else.
- A change that removes or renames something the file names fixes that line in the same commit.

## Behavior

- Do small, focused tasks. If a request feels large, ask to split it before starting.
- Minimize token usage: concise responses and diffs, no narration of paths not taken.
- When in doubt, ask: a 30-second clarification beats a mis-reverted change. A question with an obvious default that no rule says to ask is not asked: decide, and say so in one line.
- Label every question to the owner `Q<n>`, numbered across the whole thread and never reused, so "Q7" names one question.
- Give every question a suggested default, so the owner can answer "Q12 default" or "Q12 <comment>".
- A question the owner has not answered stays open and is asked again under its Q number, until the owner answers it or says "default" for it.
- Verify before writing docs. Every technical claim must trace to code read this session, using literal identifiers, not paraphrase. If you can't point to a line, don't write the sentence.
- A search hit is a lead, not a finding: read the surrounding code before drawing a conclusion from it.
- Done means every entry point the change reaches was run and succeeded. Find those entry points by searching the tree for the change's consumers.
- An entry point is a literal command in a touched doc or in `project.md`.
- Anything still broken is reported as not done, never as done with a caveat.
- When rewriting a whole doc other than a plan file, keep the old content under an "Old \<doc\>" section until the new version is confirmed working, then delete it.
- `work/` holds only discardable scratch: a draft, an experiment run, a log-analysis script. Never a temp directory outside the repo.
- Development happens in the repo's own tree, never hidden in `work/` or a worktree.

## `STATUS.md`

- `STATUS.md`: the living status doc, at the repo root, read at a session's start and updated before its end.
- `STATUS.md` is never committed: if it is not ignored, add it to `.git/info/exclude`, never to a `.gitignore`.
- `STATUS.md` holds the present only: status, open items, decisions in force, traps, and the latest figure per measurement.
- A measurement series in `STATUS.md` is one table with a row per run, not a section per run.
- `STATUS.md` aims under 15,000 characters. Past 20,000, the next edit first compresses it back under 15,000: finished items deleted, a series folded into one table, duplicate lines merged.

## Owner review

- The owner never opens `STATUS.md` or anything under `work/`, and is never asked to read or approve either.
- A rule-file edit, `project.md` included, or any other edit that needs the owner's review, sits uncommitted in the repo's own tree for `git diff`, never in the reply or under `work/`.
- Before an edit reaches the owner, a reviewer subagent that did not write it checks that it is minimal and stable.
- The reviewer's adopted findings are applied before the reply.
- The reply names the changed files and the gist in a few lines, and the diff carries the rest.
- A question for the owner goes in the reply, never only in a file.

## Git / commits

- Do not commit, checkout, push, or open PRs unless explicitly asked in this conversation. Read-only git (`diff`/`status`/`log`) is always fine.
- Commits land on the default branch directly, or on the branch `project.md` names. No feature branch.
- Stage and commit by explicit pathspec, never `git add -A`: otherwise a concurrent session's staged files get swept into your commit.
- After each commit, re-check `git status` and `git show --stat`.
- Commit messages are one line, `<area>: <short lowercase imperative>`, with no body and no trailers. The area is the top-level directory or component touched.
- Never override the commit author/committer identity, and never add `Co-Authored-By` trailers.
- A session leaves a clean history whether or not it is pushed: a correction to one of its own commits is folded into that commit, never stacked on top, so no commit adds what a later one removes.

## Subagents

- The main session is the orchestrator: it holds the conversation, the plan, decisions, and verdicts, and keeps its own context small so one thread can run long. Subagents do the work.
- Delegate by default: exploration, reading or searching beyond a file or two, builds, tests, long runs, log and image inspection, and any edit beyond a few lines.
- Keep inline only single-fact lookups, one-line edits, and answers to the user.
- Launch subagents in the background and end the turn with a status line; never sit in a tool loop waiting for one.
- Never pull bulk output into the main context: no large file reads, no raw logs, no large diffs, no image dumps. Ask a subagent for the extract, the verdict, or the `file:line` pointers instead.
- Every launch is self-contained: goal, paths, constraints, which rule files to read, and the exact report shape and size cap. A subagent sees nothing of the conversation unless it is a fork.
- An agent that edits reads `engineering.md` and `project.md` before its first edit, and formats only the files it touched.
- Parallel agents never share a write path: partition edits by path before launching, and give each its own scratch dir and run names.
- Shared docs (README, `STATUS.md`, plan files, `project.md`) are edited by the main session, or by one agent after the others report.
- When partitions must overlap, run those agents one after another in the repo's tree.
- Subagents report, never decide: a bounded summary with pointers, findings, and open questions. The main session verifies by spot-check or a second subagent, not by redoing the work.
- Set each subagent's model and effort explicitly: inheritance is silent and usually wrong. Which model plays which role is a project or prompt override.
- Prefer a fresh launch over resuming for substantial follow-ups; a resumed subagent can silently continue on the parent model.
- Subagents never run git writes; they report changes and the main session commits when asked.
- Checkpoint the thread's running state (done, decided, next) into `STATUS.md`, not only into context, so a summarized or resumed thread picks up cleanly.

## Runs, watchers, and staying reachable

- The main session stays reachable: no foreground command or wait longer than about a minute, and never a foreground sleep or poll loop.
- Anything longer runs in the background with unbuffered output to a log, and the turn ends with a one-line status so the user can speak at any time.
- A user message always comes first: when one arrives mid-task, act on it before continuing, and re-plan if it changes the work.
- Record every launch at launch: what it is, its task id, PID, or container name, its log path, its expected duration, and the one command that checks it.
- Manage only what you launched, by that record, never something inferred after the fact.
- Watchers always have a deadline and always emit a line, on success, failure, or timeout. Silence is never success.
- Rely on the completion notification, with one fallback: if nothing has arrived by the expected duration, run the recorded check once.
- Never stack two watchers on one job.
- Keep few things in flight, a handful of runs and agents at most, and stop your own stale watchers and agents by their recorded ids before launching replacements.
- Never rebuild, retag, or clean the image while a run uses it.
- Stop your own run by `docker kill` of the container name `exec.sh` printed at launch: killing `exec.sh` leaves the workload running inside.
- Never touch a container you did not launch.
- `pkill -f <pattern>` inside `bash -c` matches its own command line and can kill the shell first.
  Use a character class (`pkill -f '[p]attern'`) or match the child process only.
- Never edit a script while a live run is executing it: the shell reads scripts lazily by byte offset, so an in-place edit can crash the run. Defer the edit, or write a new file.
