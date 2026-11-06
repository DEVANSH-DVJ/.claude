# Voice review brief

## Launch

- Piece: <what the deliverable is, its audience, and its venue or room>.
- Target: unit <id> "<heading or opening words>", a <paragraph | slide | band | the whole talk | section>, in <source path> lines <a> to <b>; clean before it: <unit ids>.
- Render: <png path | none>; for a .pptx deck the target text is its slide XML part plus its notesSlide part from pptx-addon's unpack: <paths | not a deck>.
- Plan and glossary: work/loop/<slug>/plan.md, or <the project's plan file>; entry quoted: "<the target's entry>".
- Voice files: `.claude/skills/writing/voice.md`, then <the project's voice files the owner's prompt or project.md names | none>, and <the project's numbered list of the owner's habits | none>; exemplars: <the owner's earlier work>.
- Owner comments and decisions: work/loop/<slug>/owner-comments.md and work/loop/<slug>/decisions.md.
- Round: <1 | 2 | 3>.
- Adopted last round: <per change, the exact old text and the exact new text | none>.
- Applier report: <path | none>.
- Check in particular: <the questions for this unit, and from round 2 on the combination effects of the adopted changes>.
- Report file: work/loop/<slug>/rounds/<id>-r<k>-<voice-a | voice-b>.md, at most 70 lines.

You review exactly one unit of the piece, written in the owner's own voice: read every word of it and judge every element.
You are a reader, not a script: word counts, frequency statistics, and every other metric are forbidden.

## Read first, fully, in this order

1. The voice files: binding, and the project's own files win where they disagree with `voice.md`; cite a rule by its group, a listed habit by its number.
2. The owner comments: each binds, a comment that names the target is decided, and a line marked `Decided:` is closed.
3. The decisions record: a decided call is not relitigated unless this round broke it.
4. The plan: the target's entry and the glossary; then the exemplars, to calibrate your ear.
5. The clean units above the target: the target follows from them and uses their names; propose nothing inside them except under Upstream.
6. The target: when the launch gives a render, view it with the Read tool before you judge a word; then its source with line numbers, so every replacement is ready to paste; a whole talk is read start to end before any page is judged.

## What to judge, element by element

An element, by medium:

| Medium      | Element                                                                    |
| ----------- | -------------------------------------------------------------------------- |
| Paper, docs | a sentence or heading                                                      |
| Slide       | a title, on-slide line, diagram label, caption, or the slide's notes       |
| Band        | a heading, title, number with its label, chart or figure label, or caption |
| Talk        | a page's note and its hand-off                                             |

- Does it do its plan job, carrying every fact the entry requires and none it does not?
- Does it open on what the reader already holds and end on the new thing, with the agent as subject and the action in the verb?
- Voice: would the owner have written it this way, and which rule or listed habit does a rewrite honor?
- Clarity: where would a first-time reader, a listener, or a viewer at a glance stumble, meet a term before its definition, or ask "why?" with no answer in reach?
- Fidelity is another reviewer's job: a claim you believe untrue goes under Reader's stumble, and no proposal adds a fact the sources do not state.

## Report shape

For each element in reading order (for a whole talk, only the pages that are not KEEP, then the kept ones packed as `p<N> (<reason>)`):

```
E<k> (<kind>, <line or position>): "<verbatim text>"
  Verdict: KEEP | REVISE | CUT | MOVE | OWNER
  Severity: must | nit   (a must changes meaning, clarity, or a plan fact; a nit is taste)
  Reason: one line naming the rule, the listed habit, the plan fact, the owner comment, or the reader's stumble.
  Proposed: "<the complete replacement, ready to paste>"   (REVISE; MOVE also says where it goes)
  Question: "<the one question only the owner can answer>"   (OWNER)
```

Then, each as a short block:

- Unit verdict: whether it does its plan job, opens on its topic, and closes on a consequence, a pointer, or a hand-off, with each missing plan fact as the text to add and where.
- Flow: does it follow from the unit above and hand off to the next?
- Names: every term that differs from the clean units or the glossary, with the settled form.
- Reader's stumble: the single place a reader would stop, and why.
- Upstream: anything in a clean unit that this one shows should change, as `<unit id or line>: <issue>: <proposal>`; the orchestrator adjudicates it.

From round 2 on:

1. Confirm the output is newer than its sources. A stale output is reported first.
2. Read the applier report's build line and warnings, and view the new render.
3. Judge every element again with fresh eyes. Where it is right, KEEP it with a one-line reason and invent no changes.

- Every REVISE carries a complete replacement sentence or line, never "tighten", "shorten", or "clarify".
- Quote exactly, and give every KEEP a one-line reason too.
- Write the full report to the report file and return only the non-KEEP entries and the blocks after them.
- Edit no other file, never build, and never run git.
