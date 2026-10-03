# Writer brief

## Launch

- Piece: <what the deliverable is, its audience, and its venue or room>; medium: <paper | slides | poster | notes | docs>.
- Write paths, and nothing else: <the source files the draft goes into>.
- Plan and glossary: work/loop/<slug>/plan.md, or <the project's plan file>.
- Voice files: `.claude/skills/writing/voice.md`, then <the project's voice files the owner's prompt or project.md names | none>; exemplars: <the owner's earlier work to calibrate on>.
- Witness: work/loop/<slug>/witness/<name>.owner-last.<ext> | none for a new piece.
- Owner comments: work/loop/<slug>/owner-comments.md.
- Build and render: <commands, through the project runner, or make on the host for LaTeX>; output: <the built file>; renders: <paths>.
- Report file: work/loop/<slug>/rounds/all-r0-writer.md, at most 40 lines.

You draft the whole piece once, in the owner's voice, from the plan; the loop then reviews it unit by unit.

## Read first, fully, in this order

1. `.claude/engineering.md`, `.claude/project.md`, and `.claude/skills/comment-style/SKILL.md`, before your first edit.
2. The voice files, then the exemplars, until you hear the owner's cadence.
3. The owner comments: each binds.
4. The plan: every unit's job, the facts it must carry with their sources, and the glossary.
5. The witness, when there is one: every number, label, citation, placeholder, and inline owner note in it survives into the draft.

## Rules

- One pass over the whole piece, unit by unit in plan order; do not polish a unit twice.
- Every fact comes from the plan's sources or the witness; invent nothing, estimate nothing, and leave a placeholder where a value is missing.
- Every name comes from the glossary, in its settled form.
- Keep the file's own markup: its macros, its escaped specials, one sentence per line, ASCII only.
- Never edit outside the write paths, never touch an owner's inline note, never run git.

## Then

1. Build with the launch's command; it finishes clean.
2. Render and view the output with the Read tool; nothing clipped, overflowing, or missing.
3. `grep -nP '[^\x00-\x7F]' <write paths>` prints nothing.

## Report

- Per unit, one line: its id and what it now says, in five to ten words.
- The passages you are least sure of, each quoted with the doubt in one line.
- Every placeholder you left, with what it waits for.
- The build line and the render paths.

Write the report to the report file and return only the doubts and the placeholders.
