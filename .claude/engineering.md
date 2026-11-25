# Engineering rules

Project-agnostic engineering conventions.
Project commands, layout, and toolchain specifics live in `project.md`.

## Diff discipline

- Touch only what the task requires. No drive-by refactors, no whitespace churn.
- Prefer editing existing files. Split a file when it turns unwieldy, not by default.
- Don't add a dependency without asking.
- Keep behavioral changes small and focused: land structural prep as its own commit, then the minimal behavioral delta on top.
- One concern per commit.
- Never edit a `.gitignore` or a `LICENSE`: ask first. A machine-local ignore goes in `.git/info/exclude`.

## Comments

- Comments are one-liners: 4-5 words ideal, 8-10 if needed, always to the point. Multi-line comments are a rare exception.
- Write them for the flow of the code: frequent enough that a top-to-bottom reader never hits a gap, sparse enough that they don't force scrolling.
- Reuse vocabulary and phrasing across comments so `grep` lands on related spots, and keep the tone consistent.
- Comment what the code does, or a non-obvious invariant or constraint, never the conversation. No "added for X", no "fixes Y", no "tried Z", no `// previously:`.
- File header: none when the name says the purpose, 4-5 lines normally, 8-10 only for a long or central file. Longer means split the file.
- Keep public-API docstrings short (5 lines max): state the contract, not the history.
- The "why the code is the way it is" does not belong in code. It goes in the living status or plan docs (see Docs discipline).

## Docs discipline

- Never leak session discussion or decision history into any committed file: code, README, configs, or these rule docs. State what a thing IS, not how we arrived at it or what we tried.
- No AI references anywhere that ships: not in code, comments, filenames, naming, or file metadata such as a draw.io `agent` attribute or a document author field.
- Rationale and "why" that must persist go only to the living status or plan docs, kept minimal. Code comments, README, and configs stay free of it.
- An edit to a doc replaces the line it supersedes and deletes a finished or stale item in the same edit. Nothing is appended beside the text it replaces.
- A doc records no history: no dated entry, no per-session note, no finished row kept in full. A finished item is deleted or reduced to one line.
- A list that changes over time (models, targets, machines) lives in one doc, and other docs point there. A new item joins that list, never a sentence as one more clause.
- Don't hoard dead-ends ("tried X, it didn't work"). They go stale and steer future sessions away from now-viable routes. Record what is true and what is next, not the graveyard.

## Build, format, environment

- Build, lint, test, format, and run commands go through the runner `project.md` names, such as a `docker/exec.sh` wrapper.
- The host toolchain is used only where `project.md` says so. LaTeX is the standing exception: `make` for papers and talks runs on the host.
- After editing, run the build or typecheck. Before finishing, run the linter and treat warnings as failures.
- Format edited files with `format/format.sh` before committing.

## Things to avoid

- Speculative generality: extra abstraction, generics, or knobs for futures not reached. Add abstraction at the second use site, not the first.
- Defensive validation inside trusted paths. Validate at the edge, trust internals.
- "Just in case" re-exports or `// removed` placeholders. Delete cleanly.
- Blanket exception handlers or silent fallbacks that mask failures. During research, fail loudly: a stack trace beats a silently wrong result.
- Editing or regenerating a test or golden output to make a change pass, without the owner's word. Fix the change instead.
- Overwhelmingly large files. Split into human-scale files.

## Language style

Conventions that hold in every project.
The formatter configs in `format/` enforce the mechanical part.

- Python: no `main()` wrapper. The entry-point body is inlined under `if __name__ == '__main__':`.
- Python: single quotes for every string; double quotes only for a docstring, a block string, or a string that contains a single quote. The formatter enforces it.

## Prose and house style

Prose and text-file conventions: sentences in any doc, markdown and LaTeX layout, and what every text file must satisfy.

- In markdown, GitHub joins consecutive lines into one paragraph. A line is its own block only as a bullet, a table row, a heading, a fenced line, or with a blank line on each side.
- One sentence per line in markdown (README and docs) and LaTeX (`.tex`). A line break ends a sentence, never wraps one for width.
- In markdown, a paragraph or a list item is best under 200 characters, about two rendered lines.
- A paragraph is rare and the owner's call: one that a session wrote is turned into bullets.
- A paragraph is only for the opening of a doc or a section: what the thing is and why it exists. A reader who skips it loses no fact they need to act on.
- Everything a reader acts on is a bullet, a table row, or a fenced command: what a script does, a flag, an image, a machine, a step, a rule, a knob.
- A bullet carries one fact in one or two sentences. A second fact is a second bullet, and a sub-detail is a nested bullet, one level deep.
- A bullet about a named thing opens with the name in backticks or bold and a colon, so the left edge scans.
- Items that share fields (images, flags, machines, models, targets, status values) are a table with one row per item and one column per field.
- Three or more parallel facts inside a sentence are a bulleted list, one per line. A run of short names may stay inline.
- Prefer two sentences or two bullets over a semicolon between two facts. In LaTeX prose, never a semicolon.
- A shell command goes in a fenced block, one command per line, never inside a sentence. Its flags are bullets under the block.
- A doc longer than a screen has a heading every 5 to 15 bullets, so GitHub's outline navigates it.
- A sentence carries one idea in about 20 words, 30 at most. A chain of `and`, `which`, `whose`, or `so that` clauses is split into sentences.
- Prose that leaves the repo as prose, such as a rebuttal, a report body, or speaker notes, keeps its paragraphs. `project.md` names such files.
- Metadata lines (conference, deadline, status) are one table, never one line per paragraph.
- ASCII only in every text file: code, markdown, configs, and commit messages.
  - No em or en dashes, arrows, curly quotes, bullets, check marks, emoji, or other non-ASCII glyphs.
  - Write `--`, `->`, straight quotes, `...`, and words instead.
  - Binary assets and the third-party trees `project.md` names are the only exceptions.
- Check with the command below. Its output must be empty outside the exceptions above.

  ```
  git ls-files | xargs grep -nIP '[^\x00-\x7F]'
  ```

- Every text file ends with a newline.
