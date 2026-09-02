# Engineering rules

Project-agnostic engineering conventions.
Project commands, layout, and any language-specific conventions live in `project.md`.

## Diff discipline

- Touch only what the task requires. No drive-by refactors, no whitespace churn.
- Prefer editing existing files. Split a file when it turns unwieldy, not by default.
- Don't add a dependency without asking.
- Keep behavioral changes small and focused: land structural prep as its own commit, then the minimal behavioral delta on top.
- One concern per commit.

## Comments

- Comments are one-liners: 4-5 words ideal, 8-10 if needed, always to the point. Multi-line comments are a rare exception.
- Write them for the flow of the code: frequent enough that a top-to-bottom reader never hits a gap, sparse enough that they don't force scrolling.
- Reuse vocabulary and phrasing across comments so `grep` lands on related spots, and keep the tone consistent.
- Comment what the code does, or a non-obvious invariant or constraint, never the conversation. No "added for X", no "fixes Y", no "tried Z", no `// previously:`.
- File header: 0 lines when the name makes the purpose obvious; 4-5 for a normal header; 8-10 only for a long or central file. If it wants more than that, split the file.
- Keep public-API docstrings short (5 lines max): state the contract, not the history.
- The "why the code is the way it is" does not belong in code. It goes in the living docs below.

## Docs discipline

- Never leak session discussion or decision history into any committed file: code, README, configs, or these rule docs. State what a thing IS, not how we arrived at it or what we tried.
- Rationale and "why" that must persist go only to the living status/plan docs, kept minimal; code comments and core files (README, configs) stay free of it.
- Those living docs are prunable: trim them to only what is critical for future review. A lossy prune is fine and expected.
- Don't hoard dead-ends ("tried X, it didn't work"). They go stale and steer future sessions away from now-viable routes. Record what is true and what is next, not the graveyard.
- When rewriting a doc, preserve the old text under an "Old \<doc\>" section until the new version is confirmed working (see `session.md`).

## Build, format, environment

- All build / lint / test / run commands go through the project's runner (e.g. a `docker/exec.sh` wrapper), never the host toolchain directly. The exact commands live in `project.md`.
- After editing, run the build or typecheck. Before finishing, run the linter and treat warnings as failures.
- Format edited files before committing, using the project's formatter (`format/format.sh`). Per-language style lives in `format/`.

## Things to avoid

- Speculative generality: extra abstraction, generics, or knobs for futures not reached. Add abstraction at the second use site, not the first.
- Defensive validation inside trusted paths. Validate at the edge, trust internals.
- "Just in case" re-exports or `// removed` placeholders. Delete cleanly.
- Blanket exception handlers or silent fallbacks that mask failures. During research, fail loudly: a stack trace beats a silently wrong result.
- Overwhelmingly large files. Split into human-scale files.

## Prose and house style

- One sentence per line, with no character limit, in markdown (README and docs) and LaTeX (`.tex`). Never hard-wrap mid-sentence for width.
- ASCII only in every text file: no em or en dashes, arrows, curly quotes, bullets, check marks, emoji, or other non-ASCII glyphs, in code, markdown, configs, or commit messages. Write `--`, `->`, straight quotes, `...`, and words instead. Binary assets are the only exception.
- Check with `git ls-files | xargs grep -nP '[^\x00-\x7F]'`; the output must be empty.
