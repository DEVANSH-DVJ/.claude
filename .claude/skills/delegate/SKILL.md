---
name: delegate
description: How to run a session as an orchestrator -- what to hand to subagents, how to brief them, what report to demand back, and how to keep the main context small enough for a long thread. Use when planning any multi-step, parallel, or exploration-heavy work.
user-invocable: true
---

Orchestration playbook. The main session owns the conversation, the plan, verdicts, and decisions; subagents do the legwork and report back small.
The standing rules are in `session.md`; this is the how-to.

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
- Read-only explorer for "where is X" and "how does Y work" questions; it returns pointers, not file dumps.
- Fork only when the task needs the thread's context (a long discussion, a design already argued through); it inherits everything and always runs on the parent model, so keep forks rare.
- Background for anything long; rely on the completion notification, never poll.
- Independent tasks launch in parallel from one message; dependent tasks run in sequence.
- Set model and effort explicitly on every launch: cheaper tiers for mechanical dev and test work, the strong tier for judgment and hard analysis.

## Write the brief

Every subagent prompt is self-contained and states:

1. the goal, in one or two sentences, and what "done" means,
2. the paths, symbols, or commands involved, and the project runner to use,
3. the rule files to read first (`.claude/engineering.md`, `.claude/project.md`, the comment doctrine),
4. the constraints: touch only these paths, no new dependencies, no git writes, report changes instead of committing,
5. the report shape and its size cap.

## Demand a bounded report

Ask for this shape, capped at a few hundred words unless the task is a review:

- Result: one paragraph, the answer or outcome first.
- Changes: `file:line` per edit, one line each.
- Evidence: the commands run and their pass or fail, one line each.
- Open questions: anything the main session must decide.

Anything bigger (a full log, a long diff, a rendered image set) goes to a file under `work/` and the report names the path.
The subagent's final report is not shown to the user; relay what matters in your own words.

## Stay reachable

- Foreground budget is about a minute per tool call; a build, test suite, render batch, or subagent goes to the background and the turn ends with a status line.
- Log every launch in the reply as one line: `<what> | <task id, pid, or name> | <log path> | expect <N> min | check: <command>`.
- Watchers exit on their own: `timeout <deadline>s bash -c 'until <done-test>; do sleep 5; done'; echo "<what>: exit $?"`, so a hung job still produces a notification at the deadline.
- If a notification is late, run the recorded check once on the next turn; if the job is dead, say so and relaunch rather than waiting further.
- Stop by recorded id only: `TaskStop` for agents and watchers, `kill <pid>` for shells, `docker rm -f <name>` for containers.
- A user correction mid-task is applied before the task continues; if it invalidates a running job, stop that job by its id, then relaunch.

## After the report

- Verify by spot-check (one targeted question, one file, one command) or by a second subagent with the verifier role; never redo the work in the main context.
- Record decisions and next steps in the living status doc when the thread is long, so a summarized or resumed session picks up cleanly.
- For a substantial follow-up, launch fresh with an updated brief rather than resuming; a resumed subagent can silently continue on the parent model.

## Keep agents out of each other's way

- Partition before launching: each parallel agent owns a disjoint set of paths, named in its brief as the only paths it may write. Two agents with a write path in common run in sequence, or one of them gets a worktree.
- Shared docs (README, status and plan docs, `project.md`) are edited by the main session, or by one agent after the others have reported.
- Scratch and runs are per agent: its own `work/<task>/` dir, unique container and log names, and never the same build or test target in the same tree as another agent at the same time.
- Formatting is per touched file (`./format/format.sh <paths>`); the whole-tree mode is for the main session on a clean tree.
- No agent runs git writes, so the index is never contended; the main session commits by pathspec after reading the reports.

## Footguns

- A brief that says "look at the conversation" gets nothing; forks are the only launch that sees it.
- Whether a fresh subagent loads `CLAUDE.md` and its includes is undocumented, and path-scoped skills may not trigger inside one; treat the rules as absent and name the ones that apply in the brief, with the checks (format, lint, build) to run before it reports.
