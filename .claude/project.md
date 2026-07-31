# Project context

<!-- This is the ONE file you fill in per project. session.md and engineering.md
     are shared and agnostic, normally left untouched.
     Keep this lean: durable facts and pointers, not the current task.
     The current focus/goal belongs in the PROMPT (and the living status/plan
     docs), never in this file. Delete any section that doesn't apply. -->

## What this project is

<One short paragraph: what the project is, its goal, and the tracks or components that matter.>

## Vocabulary

<The load-bearing terms a session must know to read the code and talk to you:
 the words you use that aren't obvious from the code. Keep it to real terms, not a glossary dump.>

## Layout

<A short map of where the main pieces live. Point to README.md for the full version
 rather than duplicating it here.>

## Environment & commands

<!-- Everything an agent needs to build/run/test, all through the project runner. -->
- Runner / exec wrapper: <e.g. `./docker/exec.sh "<cmd>"`>
- Build / typecheck: <cmd>
- Lint: <cmd>
- Test / smoke: <cmd>
- Format: `./format/format.sh`
- Full run commands: see `run.md`

## Language & toolchain specifics

<Per-language conventions live in `.claude/rules/*.md` (path-scoped). Put project-wide
 toolchain facts here: compiler versions, feature flags, anything a rule file shouldn't own.>

## Upstream / external (if any)

<What external or upstream code is carried, from where, how it is reproduced, and the regen command. Delete if none.>

## Docs map

<!-- Link the living docs so nothing is duplicated here. Adjust to this project. -->
- `README.md`: orientation + layout
- `run.md`: every run command
- `<PLAN/STATUS>.md`: living per-goal status
- `docs/`: deeper guides

## Overrides to the shared rules

<Anywhere this project deliberately deviates from session.md / engineering.md:
 state the rule and why. If empty, the shared rules apply as written.>
