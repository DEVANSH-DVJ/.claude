---
name: delegate
description: How to run a session as an orchestrator -- what to hand to subagents, how to brief them, what report to demand back, and how to keep the main context small enough for a long thread. Use when planning any multi-step, parallel, or exploration-heavy work.
user-invocable: true
---

Orchestration playbook. The main session owns the conversation, the plan, verdicts, and decisions; subagents do the legwork and report back small.

## Split the work

Delegate:

- exploration and search across more than a file or two, and any read of a large file,
- builds, tests, lint, long runs, and reading their logs,
- image and render inspection (images are expensive in context),
- edits beyond a few lines, including mechanical refactors and doc rewrites,
- reviews, summaries, and verification passes.

Keep in the main session:

- the plan, the decision, the verdict, and the running state of the thread,
- single-fact lookups where the file or symbol is already known,
- one-line edits,
- the reply to the user.

## Pick the launch

- Fresh general-purpose agent for a self-contained task with a complete brief; the default.
- Read-only `Explore` agent for "where is X" and "how does Y work" questions; it returns pointers, not file dumps.
- Fork only when the task needs the thread's context (a long discussion, a design already argued through); it inherits everything and always runs on the parent model, so keep forks rare.
- Every launch runs in the background.
  Rely on the completion notification, never poll.
- Independent tasks launch in parallel from one message; dependent tasks run in sequence.
- Set model and effort explicitly on every launch: cheaper tiers for mechanical dev and test work, the strong tier for judgment and hard analysis.
  - A launch that sets neither inherits them silently, which is usually wrong.
- Which model plays which role is set by the project or the owner's prompt.
  The tiers above hold where neither sets it.

## Write the brief

Every subagent prompt is self-contained and states:

1. the goal, in one or two sentences, and what "done" means,
2. the paths, symbols, or commands involved, and the project runner to use,
3. the rule files to read first: `.claude/engineering.md` and `.claude/project.md`,
4. the constraints: touch only these paths, no new dependencies, no git writes, report changes instead of committing,
5. the report shape and its size cap.

## Demand a bounded report

Ask for this shape, capped at a few hundred words unless the task is a review:

- Result: one paragraph, the answer or outcome first.
- Changes: `file:line` per edit, one line each.
- Evidence: the commands run and their pass or fail, one line each.
- Open questions: anything the main session must decide.

Never pull bulk output into the main context: no large file read, raw log, large diff, or image dump.
Ask the subagent for the extract, the verdict, or `file:line` pointers instead.

Anything bigger (a full log, a long diff, a rendered image set) goes to a file under `work/` and the report names the path.
The subagent's final report is not shown to the user; relay what matters in your own words.

## Stay reachable

- Foreground budget is about a minute per tool call; a build, test suite, render batch, or subagent goes to the background and the turn ends with a status line.
- Log every launch in the reply as one line: `<what> | <task id, pid, or name> | <log path> | expect <N> min | check: <command>`.
- A watcher runs in the background with a deadline, so a hung job still produces a notification:

  ```bash
  timeout <deadline>s bash -c 'until <done-test>; do sleep 5; done'; echo "<what>: exit $?"
  ```

  `<done-test>` is a shell test such as `test -f <report path>`, and exit 124 means the deadline hit.

- Never stack two watchers on one job.
- If a notification is late, run the recorded check once on the next turn; if the job is dead, say so and relaunch rather than waiting further.
- Stop by recorded id only: `TaskStop` for agents and watchers, and `docker kill <name>` for a run, with the name from exec.sh's `container: <name>` line.
- `kill <pid>` is only for a host process not launched through `exec.sh`: killing `exec.sh` leaves the workload running inside.
- Manage only what you launched, by its record, and never touch a container you did not launch.
- Keep a handful of runs and agents in flight at most.
  Stop your own stale ones by their recorded ids before launching replacements.
- A user message mid-task is acted on before the task continues; if it invalidates a running job, stop that job by its id, then relaunch.
- Never rebuild, retag, or clean the image while a run uses it.
- `pkill -f <pattern>` inside `bash -c` matches its own command line and can kill the shell first.
  Use a character class (`pkill -f '[p]attern'`) or match the child process only.
- Never edit a script while a live run is executing it: the shell reads it lazily by byte offset, so an in-place edit can crash the run.
  Defer the edit, or write a new file.

## After the report

- Verify by spot-check (one targeted question, one file, or one command) or by a second subagent that did not do the work.
- Never redo the work in the main context.
- Checkpoint the running state (done, decided, next) in the project's living status doc (`PLAN.md` when the project uses the plans skill), so a summarized or resumed session picks up cleanly.
- For a substantial follow-up, launch fresh with an updated brief rather than resuming: a resumed subagent can silently continue on the parent model.

## Keep agents out of each other's way

- Partition before launching: each parallel agent owns a disjoint set of paths, named in its brief as the only paths it may write.
  Two agents with a write path in common run in sequence.
  - Each works in the repo's own tree, never in a worktree.
- Shared docs (README, status and plan docs, `project.md`) are edited by the main session, or by one agent after the others have reported.
- Scratch and runs are per agent: its own `work/<task>/` dir, unique container and log names, and never the same build or test target in the same tree as another agent at the same time.
- Formatting is per touched file: `./docker/exec.sh "./format/format.sh <paths>"`, run from the repo root with repo-relative paths.
  - The whole-tree mode is for the main session, with no unstaged or untracked change.
- No agent runs git writes, so no two agents stage files at the same time.
  The main session commits by pathspec when asked, after reading the reports.

## Pitfalls

- A brief that says "look at the conversation" gets nothing; forks are the only launch that sees it.
- Whether a fresh subagent loads `CLAUDE.md` and its includes is undocumented.
  A skill that loads only for matching file paths, such as `comment-style`, may not trigger inside one either.
  - Treat the rules as absent, and name the ones that apply in the brief, with the checks (format, lint, build) to run before it reports.
