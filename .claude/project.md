# Project context

<!-- This is the ONE file you fill in per project.
     session.md and engineering.md are shared and agnostic, normally left untouched.
     Keep this lean: durable facts and pointers, not the current task, and not a spec.
     Trust the setup agent to fill each section for this project; do not over-prescribe.
     The current focus or goal belongs in the PROMPT and the living status/plan docs, never here.
     Delete any section that doesn't apply. -->

## What this project is

<One short paragraph: what the project is, its goal, and the tracks or components that matter.>

## Vocabulary

<The load-bearing terms a session must know to read the code and talk to you, and that aren't obvious from the code.>

## Layout

<A short map of where the main pieces live; point to README.md for the full version rather than duplicating it.>

## Environment & commands

<How to build, run, and test this project: the exact commands, run through the project runner (e.g. `./docker/exec.sh "<cmd>"`), plus `./format/format.sh` to format.>

## Language & toolchain specifics

<Anything a session needs beyond the defaults: toolchain versions, feature flags, per-language style not covered by `format/`.>

## Upstream / external (if any)

<Any external or upstream code the project carries, and how it is kept in sync. Delete if none.>

## Docs map

<!-- Link the living docs so nothing is duplicated here. Adjust to this project.
     Avoid a top-level docs/ folder: it collides with docker/ on tab-completion. Prefer notes/, guides/, or reference/. -->
- `README.md`: orientation + layout
- `run.md`: every run command
- `<PLAN/STATUS>.md`: living per-goal status
- `notes/`: deeper guides

## Overrides to the shared rules

<Anywhere this project deliberately deviates from session.md / engineering.md, state the rule and why. If empty, the shared rules apply as written.>
