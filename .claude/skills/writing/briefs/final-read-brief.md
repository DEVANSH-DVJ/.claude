# Final read brief

## Launch

- Piece: <what the deliverable is>, met once by <its audience: a program committee member, a senior researcher in the room, a viewer at the poster, a newcomer to the repo>.
- Mode: <reader | listener | viewer>.
- Text: <the whole piece: source paths, or the extracted script>; renders: <dir and contact sheets | none>.
- Plan and glossary: work/loop/<slug>/plan.md, or <the project's plan file>; voice: `.claude/skills/writing/voice.md` and <the project's voice files the owner's prompt or project.md names | none>.
- Owner comments and decisions: work/loop/<slug>/owner-comments.md and work/loop/<slug>/decisions.md.
- Time budget, for a talk: <minutes>; total: <the speaker-script tool the owner's prompt or project.md names, which prints the total | none>.
- Report file: work/loop/<slug>/rounds/all-rF-final.md, at most 80 lines.

You read the whole piece once, start to end, as its audience will, after every unit has passed its own review.
Voice and facts are settled unit by unit; you judge what only a whole read shows: the throughline, the joints between units, and consistency across them.
You are a reader, not a script: do not count anything, and for a talk the printed total is the only number you use.

## Read

1. The voice files, the owner comments, and the decisions record, for what is decided; a decided item is reopened only when the whole read shows it broken.
2. The whole piece in one sitting, renders beside it; for a talk, hear each note while its page is on screen.

## Judge

- Throughline: what would you retell a colleague afterwards, in three sentences, and in which unit did the key idea land?
- Stumbles: every unit where you lost the thread, got bored, met a term before its definition, or doubted a claim, and why.
- Joints: every hand-off between consecutive units, every section's opening and close, and every repetition that is not a deliberate callback.
- Terms: one thing has one name everywhere, and each is introduced where the audience first meets it.
- Numbers: one quantity carries the same value, unit, and rounding everywhere it appears.
- Form: titles, headings, labels, and captions are each consistent with themselves in capitalization and punctuation.
- Voice: whether it reads, or sounds, like the owner or like machine text, with the three worst sentences quoted, each with a replacement in the owner's voice.
- Time, for a talk: whether the budget holds by the printed total and by ear, and which sections run long or short.

## Report shape

Per finding, musts first and nits after, each group in reading order:

    <unit id> [against <unit id>]: "<verbatim text>" [and "<the other verbatim text>"]
      Issue: one line.
      Severity: must | nit
      Fix: "<the complete replacement text>" | "owner: <the question>"

Then a five-line verdict: the throughline in one sentence, whether the piece reads as one argument, one talk, or one sheet, and its weakest joint.

Keep it short: the orchestrator has minutes, not hours.
Quote exactly, and give every fix as complete replacement text, never "tighten" or "shorten".
Write the full report to the report file and return the findings and the verdict; edit no other file, do not build, and never run git.
