# Engineering rules

Project-agnostic engineering conventions.
Project commands, layout, and toolchain specifics live in `project.md`.

## Diff discipline

- Touch only what the task requires. No drive-by refactors, no whitespace churn.
- Prefer editing existing files. Split a file when it turns unwieldy, not by default.
- Don't add a dependency without asking.
- Keep behavioral changes small and focused: land structural prep as its own commit, then the minimal behavioral delta on top.
- One concern per commit.
- Never edit a `.gitignore` or a `LICENSE`; ask. A machine-local ignore goes in `.git/info/exclude`.

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
- An edit to a doc replaces the line it supersedes and deletes a finished or stale item in the same edit. Nothing is appended beside the text it replaces.
- A doc records no history: no dated entry, no per-session note, no finished row kept in full. A finished item is deleted or reduced to one line.
- A list that changes over time (models, targets, machines) lives in one doc, and other docs point there. A new item joins that list, never a sentence as one more clause.
- Don't hoard dead-ends ("tried X, it didn't work"). They go stale and steer future sessions away from now-viable routes. Record what is true and what is next, not the graveyard.
- When rewriting a doc, preserve the old text under an "Old \<doc\>" section until the new version is confirmed working (see `session.md`).

## Build, format, environment

- All build / lint / test / run commands go through the project's runner (e.g. a `docker/exec.sh` wrapper), never the host toolchain directly. The exact commands live in `project.md`. LaTeX is the one exception: `make` for papers and talks runs on the host.
- After editing, run the build or typecheck. Before finishing, run the linter and treat warnings as failures.
- Format edited files before committing, using the project's formatter (`format/format.sh`). Per-language style lives in `format/`.

## Things to avoid

- Speculative generality: extra abstraction, generics, or knobs for futures not reached. Add abstraction at the second use site, not the first.
- Defensive validation inside trusted paths. Validate at the edge, trust internals.
- "Just in case" re-exports or `// removed` placeholders. Delete cleanly.
- Blanket exception handlers or silent fallbacks that mask failures. During research, fail loudly: a stack trace beats a silently wrong result.
- Overwhelmingly large files. Split into human-scale files.

## Language style

Conventions that hold in every project; the formatter configs in `format/` enforce the mechanical part.

- Python: no `main()` wrapper. The entry-point body is inlined under `if __name__ == '__main__':`.
- Python: single quotes for every string; double quotes only for a docstring, a block string, or a string that contains a single quote. The formatter enforces it.

## Prose and house style

- One sentence per line in markdown (README and docs) and LaTeX (`.tex`); a line break ends a sentence, never wraps one for width.
- A sentence carries one idea in about 20 words, 30 at most. Split a chain of `and`, `which`, `whose`, or `so that` clauses into sentences.
- Three or more parallel items (targets, flags, variants, file roles, status values) are a bulleted list, one per line, never a comma or semicolon list inside a sentence.
- Per-item data (name, default, meaning; one row per model or target) is a table, not a run of sentences or one section per item.
- Bullets are the default in a doc: each fact, rule, step, or item is one bullet of one or two sentences.
- A paragraph is for the intro of a doc or section, or an argument whose sentences must run in order: one to four sentences, then a blank line, since consecutive lines render as one.
- A shell command goes in a fenced block, never inside a sentence.
- ASCII only in every text file: no em or en dashes, arrows, curly quotes, bullets, check marks, emoji, or other non-ASCII glyphs, in code, markdown, configs, or commit messages. Write `--`, `->`, straight quotes, `...`, and words instead. Binary assets are the only exception.
- Check with `git ls-files | xargs grep -nP '[^\x00-\x7F]'`; the output must be empty.
- Every text file ends with a newline.
