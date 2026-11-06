# Project context

<!-- This is the ONE file you fill in per project.
     session.md and engineering.md are shared and agnostic, normally left untouched.
     Keep this lean: durable facts and pointers, not the current task, and not a spec.
     The current focus or goal belongs in the PROMPT and the living status/plan docs, never here.
     Delete any section that doesn't apply. -->

## What this project is

<One short paragraph: what the project is, its goal, and the tracks or components that matter.>

## Vocabulary

<The load-bearing terms a session must know to read the code and talk to you, and that aren't obvious from the code.>

## Layout

<A short map of where the main pieces live; point to README.md for the full version rather than duplicating it.>

## Docs map

<!-- One bullet per living doc this project keeps, so nothing is duplicated here.
     Avoid a top-level docs/ folder: it collides with docker/ on tab-completion. Prefer notes/. -->

- `README.md`: orientation + layout
- <`run.md` for run commands, `notes/` for deeper guides, or whatever this project keeps; delete what does not exist>

## Environment & commands

<How to build, run, and test this project: the exact commands, run through the project runner (e.g. `./docker/exec.sh "<cmd>"`), plus `./format/format.sh` to format.>

## Machines

<Optional: one bullet per machine, named by its ssh alias alone, and which one commits and which ones measure. Delete the section when the laptop is the only machine.>

## Language & toolchain specifics

<Anything a session needs beyond the defaults: toolchain versions, feature flags, per-language style not covered by `format/`.>

## Subagents

<Which model plays which role here: the main session, the agents that write, the agents that only read, and how many run at once. Delete the section when the shared rule, model and effort set explicitly per launch, is enough.>

## Overrides to the shared rules

<Anywhere this project deliberately deviates from session.md / engineering.md, state the rule and why. If empty, the shared rules apply as written.>
