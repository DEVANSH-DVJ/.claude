---
name: plans
description: Write, read, run, or close a session plan -- one committed prompt file per planned session that says what must be true and never how, beside the local `STATUS.md`. Use when a session writes, reads, runs, or closes a plan file.
user-invocable: true
---

A plan system: one committed prompt file per planned session, and the local `STATUS.md` every session reads and updates.
This skill holds the plan format and a session's life around it.

## Files

- `plans/<NN>-<slug>.md`: one session's prompt, saying what the session is for and how it knows it is done.
- `plans/README.md`: the committed index, holding the line table (one row per line of work) and the sequence table.
- The plan files are the committed record: terse, and free of session history.
- `STATUS.md`: the living status doc that `session.md` defines, holding the owner's decisions in force as one numbered row each, with the reasoning behind them.

## Numbers and the sequence

- A plan's number has two digits, and its tens digit, the decade, names its line of work.
- One decade is one line of work, and the line table in `plans/README.md` names each line by its decade.
- The sequence table in `plans/README.md` lists each open plan as one row: `#`, `file`, `line`, and `status`.
- `status`: when the plan runs, such as `next` or `after <NN>`, or what is left of a plan done in part.
- Within a line, plans run in numeric order unless `status` says otherwise.
- Two lines run side by side only when their sessions cannot collide.
- `project.md` sets what keeps two lines apart, as the settings table at the end lists.
- A session that writes, moves, or deletes a plan file edits its row in the same edit.

## A plan file

- Title: `# <NN>. <Title in sentence case>`, then the fixed preamble.
- `## Kind`: one line, the kind line of one of the session kinds below.
- `## Goal`: two to four bullets on what must be true at the end, as a user or reader observes it.
  The last says what does not change.
- `## Done`: two to four observable results that close the session, never a list of commands.
  Its last bullet is the fixed closing bullet.
- `## Shared files`, optional: one line naming the shared files the session may edit without asking.
- `## Non-goals`, optional: what the session does not do, one bullet each.
- `## Hints`, optional: at most ten bullets under the fixed caveat, each stating one of these in full:
  - what a committed file or a reference tree (a checkout of another project that the session reads and never changes) shows, naming it
  - a decision in force, a trap, or a measured figure with its setting

## What a plan says

- A plan says what must be true when the session ends, never how to get there.
- The session finds its own route, and everything the change affects, from the latest state of the tree.
- A plan names no function, field, env var, CLI flag, command, agent model, or role.
- It names a file only in the fixed text, the worked example of the Kind line, a Hints bullet, or the Shared files line.
- A plan file is committed, so it names no uncommitted file: nothing under `work/`, and `STATUS.md` only in the fixed preamble and the Measure kind line.
- A hint writes out the decision, trap, or figure in full, never as a reference such as "decision 7 in `STATUS.md`".
- A plan has no questions section: launching a session is the owner's go-ahead for everything its plan names.
- The session still asks first about these, unless its plan names them:
  - adding a dependency
  - editing a `.gitignore`, a `LICENSE`, or a rule file under `.claude/`
  - changing a test or a golden output to make a change pass
  - committing, checking out, pushing, or opening a PR
  - anything else the shared rules or `project.md` say to ask about

## Fixed text

- The preamble, the closing bullet of `## Done`, and the caveat under `## Hints` are word for word the same in every plan file.
- The preamble, three lines right under the title:

```
Read the rules in `.claude/` and the `plans` skill, then `plans/README.md`.
Then read `STATUS.md` and `README.md`.
Reply in one line before starting.
```

- The closing bullet of `## Done`:

```
- Done means every entry point the change reaches was run and succeeded.
  - Find those entry points by searching the tree for the change's consumers.
  - An entry point is a literal command in a touched doc or in `project.md`.
  - Anything still broken is reported as not done, never as done with a caveat.
```

- The caveat, the first lines under `## Hints`:

```
The lines below were written before the session and may be stale, wrong, or no longer applicable.
Verify each against the tree before relying on it, and take any route not listed here.
```

## Session kinds

- `Build, learning from <a worked example>.`: the session learns from that example and from the tree, and lands the change the way the example landed.
  - A worked example is a past commit or file that made a similar change.
- `Figure-out: <the open question>, settled with the owner, then built.`: the session brings evidence and proposes.
  - It records each decision the owner makes as a numbered row in `STATUS.md`.
  - Its first proof is the smallest thing that shows the decision holds.
  - Its kind line ends with ", then built" only when the session builds the rest itself.
    Without it, a later plan builds the rest, or nothing is built.
- `Measure: nothing in the repo changes but a fix found along the way, and the figures go to STATUS.md.`: the session lands only that fix.

## A session's start and end

- The owner launches a session with one plan file as its prompt.
- It reads what the preamble names, `STATUS.md`'s traps and decisions among them, and replies in one line.
- It runs as an orchestrator by the `delegate` skill: subagents do the work, and the session keeps the plan and the verdicts.
  It drives the work to completion.
- It never ends its turn to wait unless a job it launched is still running to send the notification, and never ends with work half done.
- It leaves three things behind:
  - the change
  - a current `STATUS.md`, by the rules in `session.md`
  - its plan file deleted, or, if part of the plan is left for later, rewritten to what is still open
- A finished plan's file and its sequence row are deleted in one edit, never kept with a `done` marker.
  Git history is where a past session lives.
- Anything still broken is reported as not done, and its plan file stays.

## What `project.md` sets

A project states these in `project.md`, machines under Machines and the rest under Overrides, and the default holds where it states none.

| Setting                                                         | Default                  |
| --------------------------------------------------------------- | ------------------------ |
| the plan directory                                              | `plans/`                 |
| the length cap of a plan file, in lines or characters           | none                     |
| the wording of the fixed text, and docs the preamble adds       | as above                 |
| columns the sequence table adds, such as a goal                 | none                     |
| what keeps two lines apart, such as paths or machines           | none                     |
| a store for raw measurements beside `STATUS.md`                 | none                     |
| whether a session commits as each piece lands                   | only when the owner asks |
| machines, reference trees, and directories a session may create | none                     |
| plan parts beyond these, such as a link to a release list       | none                     |
