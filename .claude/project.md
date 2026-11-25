# Project context

<!-- The project's own context file, written by the rules under "What project.md holds" in session.md.
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
- `STATUS.md`: the living status doc, as `session.md` defines it
- <`run.md` for run commands, `notes/` for deeper guides, or whatever this project keeps; delete what does not exist>

## Environment & commands

<How to build, lint, test, format, and run this project: the exact commands, through the project runner (e.g. `./docker/exec.sh "<cmd>"`).>

## Machines

<Optional: one bullet per machine, named by its ssh alias alone, and which one commits and which ones measure. Delete the section when the laptop is the only machine.>

## Language & toolchain specifics

<Anything a session needs beyond the defaults: toolchain versions, feature flags, per-language style not covered by `format/`.>

## Subagents

<Which model plays which role: the main session, writers, readers, and how many run at once. Delete when per-launch model and effort suffice.>

## Overrides to the shared rules

<One bullet per standing rule of this project, naming the shared rule it overrides, if any. If empty, the shared rules apply as written.>
