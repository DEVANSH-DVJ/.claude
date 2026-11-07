---
name: writing
description: Draft, revise, or review a prose deliverable the owner asks for -- a paper, slide text, a poster, speaker notes, or a doc -- one unit at a time through a review loop of plan, draft, a two-reader voice review, a fidelity check, adjudication, apply, further rounds, and a final whole-piece read, in the shape the owner confirms first. Use when the owner asks to draft or review such a piece, or asks for the loop, a voice review, or a fidelity check; a doc edit that rides along with a code change does not use it.
user-invocable: true
argument-hint: <deliverable path> [paper|slides|poster|notes|docs]
---

# Writing loop

Prose in the owner's voice is drafted once from a plan, then reviewed one unit at a time until no must-fix remains.

- The main session orchestrates: it adjudicates, applies or launches an applier, and commits when asked. Subagents read and report.
- The house prose rules are in `voice.md`, and the launch texts are in `briefs/`.
- The owner's prompt or the repo's `project.md` names, when they exist:
  - the project's voice files, exemplars, and glossary
  - model overrides
  - the script tool
- Otherwise the loop proceeds without them.
- It serves a new piece, a redraft the owner asked for, or a revision.
- A wording fix the owner dictates needs no loop and is applied as given.
- The full loop is the default shape, not a mandate: before the first round, the session proposes the shape and the owner confirms it.
- What sets the shape: the piece's state, the urgency, the scope of the review, and which units are frozen.
- A shape may drop a pass, run one pass alone, or cover the open units only.

## Vocabulary

- Owner: the person whose voice the piece is in; their comments bind.
- Unit: the piece of text one round reviews (see the table); its id is `u<NN>-<name>`, assigned in `plan.md`, and distinct from the loop dir `<slug>`.
- Element: the smallest thing a reviewer gives a verdict on, a sentence, a line, a label, a caption.
- Witness: the text the unit must stay faithful to; owner-last is the owner's last version before the loop.
- Frozen: a unit the owner has reviewed and approved, marked in `plan.md`. A prior piece counts as frozen only when the owner names it.
- Any other draft, an earlier session's included, is unreviewed prose and never stands as the owner's voice.
- Must or nit: a finding's severity, must for meaning, clarity, or a plan fact, nit for taste.
- Clean: a unit with no must left; decided: an item the owner has ruled on or a call recorded in `decisions.md`.
- Upstream: a finding about a clean unit, raised while reviewing a later one.
- Voice verdicts are KEEP, REVISE, CUT, MOVE, OWNER; fidelity verdicts are SAME, CHANGED, NEW, UNSUPPORTED, WRONG, MISATTRIBUTED, OWNER-FACT, plus a DROPPED list.

## Units

| Medium        | Unit                                  | Elements                                      | Render                                                                         |
| ------------- | ------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------ |
| Paper         | paragraph                             | sentence                                      | page PNG via `pdf-addon`, only when the paragraph references a figure or table |
| Slides        | slide, with all its builds            | title, line, label, caption, its speaker note | slide PNG via `pptx-addon` or `pdf-addon`                                      |
| Poster        | band, one full-width row of the sheet | heading, title, tile, chart label, caption    | sheet PNG at a dpi where the band reads                                        |
| Speaker notes | the whole talk                        | each page's note and each hand-off            | page renders beside the script                                                 |
| Docs          | section                               | sentence and heading                          | none                                                                           |

- Units run top-down, one at a time; the next opens only when the current one is clean.
- A paper's section titles, captions, and floats belong to the unit whose text they sit beside.
- A paragraph's page is found with `./docker/exec.sh "pdftotext -layout '<pdf>' -" | awk '/\f/{p++} index($0,"<first words>"){print p+1; exit}'`; a beamer frame's page, by the same search on its title.
- A beamer slide with builds `-A`, `-B` is one unit, and its `\speakernote` text is an element of it in a slides loop and part of the whole talk in a speaker-notes loop.
  - The script is `perl -0ne 'print "$2\n\n" while /\\speakernote(\{((?:[^{}]++|(?1))*)\})/g' tex/*/*.tex`, or the tool the owner's prompt or `project.md` names.

Decks (`.pptx`):

- The unit is one slide, and its text is the slide's XML part plus its notesSlide part.
- Those parts are unpacked to `work/loop/<slug>/deck/` with `.claude/skills/pptx-addon/scripts/unpack.py` and mapped by `slidemap.py`.
- The witness is the same parts from the owner-last deck.
- The applier edits those parts, packs in place with `pack.py`, and `pptcheck.py` must exit 0.
- The scope proof is `deckdiff.py old.pptx new.pptx` listing only those parts.
- Renders come from pptx-addon's `render.py`.

## Roles

Defaults, which the owner's prompt or the repo's `project.md` may override.

- Every launch runs in the background as `subagent_type: general-purpose`, except a writer launched as a fork when the thread holds the plan discussion.
- Every launch sets the model, and the effort where the launch mechanism accepts it.

| Role     | Model           | Effort | Brief                                                                       |
| -------- | --------------- | ------ | --------------------------------------------------------------------------- |
| writer   | Opus, or a fork | high   | `briefs/writer-brief.md`                                                    |
| voice-a  | Fable           | high   | `briefs/review-brief.md`; voice-a and voice-b never see each other's report |
| voice-b  | Opus            | high   | `briefs/review-brief.md`                                                    |
| fidelity | Opus            | high   | `briefs/fidelity-brief.md`                                                  |
| applier  | Opus            | medium | `briefs/applier-brief.md`                                                   |
| final    | Fable           | high   | `briefs/final-read-brief.md`                                                |

## Loop records

Everything the loop writes lives in `work/loop/<slug>/` at the repo root, never committed.

- `<slug>`: the deck's file stem for a `.pptx`, else the deliverable's directory name with spaces and colons replaced by `-`.
- If `work/` is not ignored, ask the owner to ignore it. Never edit a `.gitignore` yourself.
- Rounds are numbered per unit, r1 to r3; after r3 what remains goes to the owner.
- `decisions.md` gets a unit's calls as they are made at adjudication, and the record closes when the unit is clean or sent to the owner.
- In-flight state lives in `rounds/` and in the Loop position block, the summary at the top of `decisions.md` shown below.

Every report is written to `rounds/` the moment its agent finishes, as:

| Report                         | For                                                                                  |
| ------------------------------ | ------------------------------------------------------------------------------------ |
| `rounds/<unit>-r<k>-<role>.md` | voice-a, voice-b, fidelity, and the applier of round k                               |
| `rounds/all-r0-writer.md`      | the writer                                                                           |
| `rounds/all-r0-applier.md`     | a build-only applier (an applier launched with no changes, only to build and render) |
| `rounds/all-rF-final.md`       | the final read                                                                       |

- `plan.md`: the unit list with ids, each unit's job, the facts it must carry with their `path:line` sources, the glossary; a committed project plan, when one exists, is referenced instead.
- `owner-comments.md`: the owner's comments verbatim, from the conversation, filed per unit or under "All".
  - A note the owner leaves in the source is not for the loop: never read as a comment, never edited, never removed.
  - A line marked `Decided:` is closed.
- `witness/<name>.owner-last.<ext>`: the owner's last version before the loop.
  - It comes from the working tree when that differs from HEAD and the owner confirms the edits are theirs, else from `git show HEAD:<path>`.
- `witness/<name>.<label>.<ext>`: an older second witness. Owner-last wins where they differ.
- `briefs/<unit>-r<k>-<role>.md`: every filled brief, saved here before its launch, so a round can be relaunched exactly.
- `rounds/`: the reports, named as above.
- `pre/<unit>-r<k>/`: the applier's copy of the write paths before its edit.
- `decisions.md`: the Loop position block, rewritten after every launch, apply, and commit, then one record per unit.

Loop position block:

- Unit: <id and heading>
- Stage: <planning | drafting | round <k> launched | adjudicating | applier launched | clean, next unit | final read launched | done>
- Uncommitted: <edited paths not yet committed>
- In flight: <role, model, task id, launched at, expected minutes, check command, report file>
- Last commit: <subject, or none>
- Open owner questions: <unit ids>

Per-unit record; drop a line only when it has nothing to hold:

- Round <k>: each non-KEEP finding by element, with the verdict and severity.
- Adopted: per change, the exact old text and the exact new text.
- Calls: each cut or tie-break made here, and its reason.
- Owner questions: asked, and the answer once it lands.
- Rebuild: build line, layout verdict, output freshness, clean or what is still wrong.
- Commit: the subject, or "not asked".

## The loop

1. Plan.
   - Write `plan.md` or reference the project's plan.
   - Collect `owner-comments.md`.
   - Save the witnesses before anything changes.
   - Create `decisions.md`.
   - Before any sentence is drafted, `plan.md` lists the owner's approved text on the subject (the prompt, the frozen units, the prior pieces the owner names) as the voice sample and first source.
   - Settle with the owner any call only the owner can make.
   - End with a current build and render. When the build is long, a build-only applier makes it.
2. Draft, when the piece is new or rejected.
   - The writer drafts the whole piece from the plan in one pass, builds, renders, and reports the passages it is least sure of.
   - A skeleton or outline of headings and placeholder sentences is a draft like any other, and its units get the same voice and fidelity rounds.
3. Round k: voice pair and fidelity, launched in one message, each with its filled brief and its own report file.
   Fidelity runs whenever the unit's text changed since it last passed, and is skipped otherwise.
4. Adjudicate in the main session by the rules below, and record every call in `decisions.md`.
5. Apply.
   - A few lines: exact-string edits in the main session, then a build-only applier.
   - More: the applier, with the exact old and new text of every adopted change; it builds and renders.
   - No change is reported as in the output until the applier's build has run on it and the output is newer than its sources.
6. Round k+1, whenever round k changed the text.
   - After musts were applied: the voice pair plus fidelity.
   - After a nits-only apply: fidelity alone.
   - Readers never build. They confirm the output is newer than its sources, view the render the applier made, and judge every element again.
7. Next unit, once this one is clean or sent to the owner.
   An Upstream finding is adjudicated like any other and, when adopted, reopens its unit through steps 5 and 6.
8. Final read, when every unit is clean: the final reader goes through the whole piece as its audience would.
   Its adopted fixes go through steps 5 and 6 for each unit they touch; a second final read runs only when the owner asks.

## Adjudication

- An owner comment is applied, not weighed; a proposal that contradicts one is dropped.
- A decided item is not reopened: a `Decided:` line, a call in `decisions.md`, or a unit the owner edited.
- Both readers agree: adopt verbatim.
  They differ: prefer the wording that matches the owner's own earlier text or exemplars, then the shorter.
- A must raised by one reader is applied unless the other reader explicitly KEEPs the same element; then the orchestrator decides and records why.
- Readers split on severity: the higher one holds.
- KEEP against REVISE with a replacement: adopt the replacement only when it fixes a stated must, else KEEP.
- The owner's earlier wording is a tie-break, not a shield: a restatement is cut whoever wrote it.
- The owner's exact wording is applied as given, substituting only the value the sources give; it is never expanded with a clause or trimmed of a name.
- Every term is the owner's, from the prompt, the frozen units, or the glossary.
  A term a reader proposes is recorded as a finding, never adopted as a rename.
- Never adopt text that adds a fact no witness or source states; a fidelity NEW that is a textbook gloss the plan asked for may stay.
- A fidelity WRONG, CHANGED, or MISATTRIBUTED is corrected from its source first, and the voice rewrite goes on top of the corrected text.
- A DROPPED claim is restored unless the owner dropped it or the plan moves it elsewhere.
- A cut on text the owner has not flagged is the orchestrator's call, made and recorded, never queued for the owner.
- An OWNER verdict, or an UNSUPPORTED only the owner can settle, goes to `decisions.md` as a question; the unit keeps its current text, and the loop moves on.

## Exit criteria

- A unit is clean when its last round has no must left, fidelity leaves nothing WRONG, CHANGED, or MISATTRIBUTED unresolved, and no text changed since fidelity last passed; declined nits do not block.
- After round 3, whatever is still open goes to the owner as a question and the unit closes with its current text.
- The piece is done when every unit is clean and each must of the final read is applied or recorded as an owner question.

## Commits

The loop commits only when the owner asks, by the rules in `session.md`; `work/loop/` is never committed, and a file the owner edits by hand changes only in the lines asked for, in a commit of its own.

## Resume after compaction

1. Read this file, then the Loop position block and the last three records of `decisions.md`, `owner-comments.md`, and the plan entry of the unit in review.
2. Run `git status --short <deliverable>`.
3. Find the unit by its heading with `grep -n`, never by a recorded line number.
4. For each agent in flight, run its check command; if its report file is missing after its expected minutes, relaunch the last round from its saved brief.
5. Then report the unit, its stage, what is uncommitted, and what was relaunched.
6. Wait for the owner's go unless told to run unattended.

Resume prompt, for the owner to paste as the first message after a compaction:

```
Continue the writing loop on <deliverable>. Follow the Resume section of .claude/skills/writing/SKILL.md with the records in work/loop/<slug>/, report where the loop is, then <wait for my go | continue unattended to the end>.
```

## Launching a brief

Fill every `<...>` in the brief, save the filled copy under `work/loop/<slug>/briefs/`, then launch it as the prompt with the role's model and effort.
