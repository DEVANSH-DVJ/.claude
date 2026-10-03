# Voice

The owner's prose rules for papers, slides, posters, speaker notes, and docs.
A project's own voice files, when the owner's prompt or `project.md` names them, and the owner's comments win where they disagree with this file.
Numbers on length describe the owner's typical shape, never limits, and reviewers never count.

## Structure

- A section opens with a signpost, "In this section, we first ... Next, ... Finally, ...", each step with its pointer, and a subsection with "Here, we ..." or one framing sentence.
- A paragraph has one topic, opens on it and never with "Then", typically runs two to four sentences, and stands on its own; no block paragraphs.
- A paragraph closes on a consequence ("Therefore, ...", "Thus, ..."), a pointer, a deferral ("We defer X to Appendix B."), or the claim in italics.
- Every "what" carries its "why" in the same paragraph, attached with "since", "Therefore,", "Note that", or "For example,".
- A concrete example goes wherever the reader would otherwise imagine one, and intuition comes before formalism ("Formally, let ...").
- The reader never meets a term before its definition, a number before the object it measures, or a figure reference that does not say what the figure shows.
- A sentence that only restates the previous one is cut, whoever wrote it, and so is detail the target reader does not need.
- A design is stated with its positive reason, never framed against an alternative nobody raised.
- A takeaway, the boxed or italic claim that closes an evaluation paragraph, is one claim with its number and its named comparison, never a trailing scope tail.
- A sentence that waits on a result keeps its placeholder; the prose never admits incompleteness.
- Run-in headings are `\textbf{Title Case Noun Phrase.}` of one to four words with a period, prose on the next line, about one per two paragraphs; never one per paragraph, never a question, never a colon.

## Sentences

- Open on what the reader already holds and end on the new information, since the end of a sentence is its stress position.
- The agent is the subject and the action is the verb, close together; an abstraction does not "keep", "carry", or "supply" things.
- "We" makes design choices, definitions, and observations; the system or its named part does the mechanism; passives appear only in definitional formulas ("is formulated as").
- In an evaluation, "we" is right, what was run is in the past tense, and claims are in the present.
- A pronoun "this" or "it" never points at a whole previous sentence; name the thing.
- Sentences vary and typically run 12 to 30 words.
- A run of three clipped declaratives is a defect, and so are a long chain of subordinate clauses, a punchline of a few words, ", so" chains, sentence-medial "therefore", "X, not Y" tails, and clefts ("That is what ...").

## Punctuation and glosses

- A colon follows only a counted noun, before its exhaustive list: "three stages: synthesis, collection, and training"; it never joins two clauses, and a partial list opens with "including" instead.
- A comma is preferred to any dash; an em-dash is rare, always spaced " --- ", and only for an appositive after a complete clause.
- "(i) ..., (ii) ..., and (iii) ..." marks parallel cases, at most three and often two, never (iv), while "(1) ..., (2) ..., (3) ..." marks stages referred to again by number.
- Sequences run "First, ... Next, ... Then, ... Finally, ..."; never "Second," or "Third,".
- Semicolons almost never appear; when one does, it carries "; instead," or "; rather,".
- Parentheses hold pointers, instances, symbols, and abbreviations, never commentary or hedges.
- Double quotes (``...'' in LaTeX) mark only a coined label; never single quotes.
- "X, i.e., Y" mid-sentence, with both commas, restates a definition, and "(e.g., X)" inside parentheses gives an instance; never "e.g." in running text, "In other words", or "that is".
- A new term is italic at its definition, named with "termed", "We call X \textit{Y}", or "X, i.e., ..."; keep the italic macro the file already uses.
- A paragraph carries at most one single-word stress ("\textit{all}", "\textit{one}"); bold is only for run-in headings and a headline number in an evaluation.

## Numbers

- "8K", "1M", and "5.7 MB" take a space, "50\%" is glued, ranges read "10--50", speedups read "12x", never `$\times$`, and thousands take no separator (`1000`, `12000`).
- Counts up to nine are words unless tied to a unit or a result.
- Each number appears once, in the sentence about the object it measures, and every ratio names what it divides by.
- A number keeps its value of record; a missing one is a placeholder, never an estimate.

## Figures and captions

- A figure sentence has the figure as subject and says in full what it shows: "Fig.~\ref{fig:overview} shows how the compiler lowers one kernel to the device.", never "Figure 3 shows the loop.".
- A caption opens with a noun phrase ("Overview of ...", "Snippet of ...") and adds one or two full sentences with the color key or a "Note that" caveat.
- The color key makes the colored objects the subjects, "Rose boxes are the inputs, and the blue box is the scheduler.", never "Rose marks A, blue B."; diagrams and plots share one palette with one meaning per color.
- Text never repeats what a figure shows: a caption that narrates the figure's boxes is cut.
- A code excerpt shows its source lines verbatim, never re-wrapped or re-indented; a long line is elided at its end with `...`.

## Citations and pointers

- A section pointer sits in parentheses after the phrase it supports, "(\S\ref{...})", or reads "as discussed in \S\ref{...}"; never the word "Section".
- "Fig.~\ref", "Table~\ref", "Eq.~\ref", and "Algorithm~\ref" take a non-breaking space; panels read "Fig.~\ref{x} (a)"; appendices go by letter.
- "~\cite{...}" is tied to the named thing, before punctuation, at every mention of a named system, which is introduced as "Name~\cite{name}, a one-clause gloss".
- "Prior works" is plural, and a URL goes in a footnote, never in prose.

## Slides and posters

- Slide and poster text is short phrases in the owner's words, never sentences copied from the paper; full sentences live in the speaker notes.
- One idea per slide: an element that serves a second message is cut or moves to the notes.
- Few words: typically a headline and up to four short lines, with the figure carrying the story; a line that wraps to a second typeset line is revised.
- The title is in the owner's own title style; a clever assertion headline, a slogan, or a punchline is revised even when true.
- No body line restates the title, explains, qualifies, disclaims, or narrates; no semicolon-joined clauses, no metaphors, no slogan rhythm.
- The reason, the caveat, the scope, the second example, and the aside belong in the notes; the slide keeps the claim, the number, and the picture.
- Every name comes from the plan's glossary; never coin an abbreviation or a category label for a slide.
- Every number is measured and carries no mark or footnote; numbers go on a plot with each value at its bar, and no slide is a table alone.
- A poster result reads "name: value (ratio)" or "A vs B" with the comparison named, rounded and loose.
- A statement ends with a period, a label or other fragment never does, and no card ends on a closing sentence.
- Emphasis matches importance: big numbers, their own tiles, and the accent color go only to major results.
- No shape, type, or spec strings in prose or labels; a label names the thing, and a supporting statement is a logo or a few words.
- What ships is ready: no placeholder, TODO, asterisk, hedge, or caution note, and a number the sources do not give is left out, not marked.

## Speaker notes

- A note is what the owner says aloud, in the first person and the spoken phrasing of the owner's earlier notes, never terse written prose.
- A note says what its slide cannot (why it matters, how it connects to the last point, what to look at, and what it means) and never reads out what the slide already shows.
- A note runs as long as its point needs, and a figure is walked along its flow in plain words, with no pile of jargon and no numbers beyond the slide's point.
- The notes in order are one argument, the problem, why it is hard, the insight, how it works, the evidence, and what it changes; build pages are one slide revealed in steps, so their notes continue one thought.
- Each point is said once; a repetition is cut unless it is a deliberate callback.
- A note is said in one breath to a room: stacked clauses, paper phrasing, parentheses, and read-out lists of nouns are revised.
- A formulaic opener ("To summarize,", "Now,", "So,") or a closing tagline stays only where the owner's own notes do the same.
- Cues such as `<next slide>` and `<pause>` sit inline where the owner's earlier notes put them; the cue spellings, the title note, and the register of a given talk live in the talk's voice file, when the owner's prompt or `project.md` names one.

## Connectives

- "Therefore," and "Thus," conclude, "However," contrasts, and "Furthermore," adds.
- "Note that" flags a caveat mid-paragraph, but not in an introduction, where a contrast opens with "However," and a consequence with "Therefore,".
- "For example," introduces a named, concrete instance, and "This is analogous to X" or "Similar to X," relates the work to known machinery.
- "Intuitively," then "Formally," frame an informal statement and its formal one, and "In summary," closes a section or a long argument.
- A trailing ", showing ..." or ", with X <participle>" tail carries a takeaway where a second sentence would be heavier.
- Never "Hence", "Consequently", "Nevertheless", "On the other hand", "Importantly", "Overall", "Crucially", "In order to", "so-called", "dubbed", or "see Section".
- Never "In contrast", "Because", or a habitual "Given X," at the start of a sentence.

## Vocabulary

- The venue's words, never the codebase's: no internal tool, variable, or run vocabulary in prose, and no "decision" as a noun.
- Each project keeps its glossary where the owner's prompt or `project.md` says, every brief names it, and one thing has one name everywhere, in its settled form.
- No absolute ("only", "all", "every", "no one") that the sources do not back, no stress on a point the story does not need, and no loaded or commanding words.
- Do not introduce contractions, article slips, "a.k.a.", "w.r.t.", "as per", or "upto".
- American spelling, ASCII only, and one sentence per line in `.tex` and `.md`.
