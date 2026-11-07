---
name: plans
description: Write, read, run, or close a session plan -- one committed prompt file per planned session that says what must be true and never how, beside the local `PLAN.md` status doc. Use when a session writes, reads, runs, or closes a plan file.
user-invocable: true
---

A plan system: one committed prompt file per planned session, and one local status doc every session reads and updates.
The standing rules are in `session.md`, and this skill holds the plan format and a session's life around it.

## Files

- `plans/<NN>-<slug>.md`: one session's prompt, saying what the session is for and how it knows it is done.
- `plans/README.md`: the committed index, holding the line table and the sequence table.
- The plan files are the committed record: terse, and free of session history.
- `PLAN.md`: the living status doc of `session.md`, at the repo root and never committed, holding:
  - the status, and the latest figure per measurement
  - the traps a session reads before starting
  - the owner's decisions in force, one numbered row each, with the reasoning behind them
- `PLAN.md` is kept out of the index by a line in `.git/info/exclude`, never in `.gitignore`, like `work/`.

## Numbers and the sequence

- A plan's number has two digits, and its tens digit, the decade, names its line of work.
- One decade is one line of work, and the line table in `plans/README.md` names each line by its decade.
- The sequence table in `plans/README.md` lists each open plan as one row: `#`, `file`, `line`, and `status`.
- `status`: when the plan runs, such as `next` or `after <NN>`, or what is left of a plan done in part.
- Within a line, plans run in numeric order unless `status` says otherwise.
- Lines run side by side when their sessions cannot collide, and `project.md` says what keeps two lines apart.
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
- `## Hints`, optional: at most five bullets under the fixed caveat, each pointing to one of these:
  - a reference tree or a doc
  - a decision, a trap, or a measurement in `PLAN.md`

## What a plan says

- A plan says what must be true when the session ends, never how to get there.
- The session finds its own route and its own impact radius from the latest state of the tree.
- A plan names none of these:
  - a function, a field, an env var, a CLI flag, or a command
  - an agent model or role
  - a file outside a Hints bullet and the Shared files line
- A plan has no questions section: launching a session is the owner's go-ahead for everything its plan names.
- The session still asks first about anything the shared rules or `project.md` say to ask about and its plan does not name.

## Fixed text

- The preamble, the closing bullet of `## Done`, and the caveat under `## Hints` are word for word the same in every plan file.
- The preamble, three lines right under the title:

```
Read the rules in `.claude/` and the `plans` skill, then `plans/README.md`.
Then read `PLAN.md` and `README.md`.
Reply in one line before starting.
```

- The closing bullet of `## Done`:

```
- Done means every entry point the change reaches runs, as `.claude/session.md` says.
  Anything still broken is reported as not done, never as done with a caveat.
```

- The caveat, the first lines under `## Hints`:

```
The lines below were written before the session and may be stale, wrong, or no longer applicable.
Verify each against the tree before relying on it, and take any route not listed here.
```

## Session kinds

- `Build, learning from <a worked example>.`: the session learns from that example and from the tree, and lands the change the way the example landed.
- `Figure-out: <the open question>, settled with the owner, then built.`: the session brings evidence and proposes.
  - It records each decision the owner makes as a numbered row in `PLAN.md`.
  - Its first proof is the smallest thing that shows the decision holds.
  - It hands the rest to a build: its own second half when its kind line ends "then built", and a later plan otherwise.
  - Its kind line drops ", then built" when nothing is built.
- `Measure: nothing in the repo changes but a fix found along the way, and the figures go to PLAN.md.`: the session lands only that fix.

## A session's start and end

- The owner launches a session with one plan file as its prompt.
- It reads what the preamble names, `PLAN.md`'s traps and decisions among them, and replies in one line.
- It runs as an orchestrator by `session.md` and `/delegate`, and drives the work to completion.
- It never yields waiting on a notification that is not coming, and never ends with work half done.
- It leaves three things behind:
  - the change
  - a current `PLAN.md`, updated by the status-doc rules of `session.md`
  - its plan file deleted, or rewritten to what is still open if the plan moved
- A finished plan's file and its sequence row are deleted in one edit, never kept with a `done` marker.
  Git history is where a past session lives.
- Anything still broken is reported as not done, and its plan file stays.

## What `project.md` sets

A project states these under Overrides in `project.md`, and the default holds where it states none.

| Setting                                                        | Default                       |
| -------------------------------------------------------------- | ----------------------------- |
| the plan directory                                             | `plans/`                      |
| the length cap of a plan file, in lines or characters          | none                          |
| the wording of the fixed text, and docs the preamble adds      | as above                      |
| columns the sequence table adds, such as a goal                | none                          |
| what keeps two lines apart, such as paths or machines          | none                          |
| a store for raw measurements beside `PLAN.md`                  | none                          |
| whether a session commits as each piece lands                  | the git rules of `session.md` |
| machines, upstream trees, and directories a session may create | none                          |
| plan parts beyond these, such as a link to a release list      | none                          |
