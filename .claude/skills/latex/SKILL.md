---
name: latex
description: Build, review, and diff LaTeX papers for any venue class and beamer talks with the repo's own make on the host -- log and font checks, page renders with a page-budget gate, latexdiff against a previous submission, camera-ready preparation. Use for any task on a .tex file, a paper or talk build, a latexdiff, a camera-ready, a beamer deck, or "review the PDF" of a paper or deck. Prose belongs to the writing skill.
user-invocable: true
argument-hint: "[paper or talk dir]"
---

Papers for any venue class, and beamer talks.
Builds run on the host with the repo's own `make`, never inside the container; the container only exports diagrams and renders PDFs.
Follow the repo's layout and the prior repos the owner shows; prose rules are the `writing` skill's.

## Build

- Run the directory's `make` target as the repo defines it. No target: stop and write it with the owner; never add a Makefile from here.
- The log has no `Overfull \hbox` or `\vbox`, `Missing character`, or undefined reference or citation; report what needs rewording instead of rewriting the prose.
- `pdffonts <pdf>` lists no Type 3 font.

## Review

- Render with the `pdf-addon` skill, contact sheet first, and diff against the previous version when one exists.
- Gate on the page budget before anything else: the page holding the references heading, read off the contact sheet, is within the limit the owner gives (ask whether that page counts); report an overrun first.
- Figure text is never smaller than the caption.

## Diff

- Run the repo's diff target when it has one.
- Otherwise `latexdiff --flatten` the revision the owner names (`git archive` into `work/old`) against the current root, and build the result in the paper dir so figures resolve.
- Check that every addition shows as markup in the diff PDF.

## Camera-ready

- The venue's final class options; de-anonymize; the rights block.
- Remove review-only markup and macros.
- Rerun Build and the page gate against the final limit.

## Figures

- `.drawio` sources stay beside their exports; export through the `drawio` skill, one page per call.

## Conventions

- Quotes, pointers, and labels follow `voice.md` of the `writing` skill and the repo's existing source.
- `\vspace`, negative values included, is allowed to fit a page budget and overrides the venue's spacing rules; only the owner's word for a given paper restricts it.

## Requirements

- Host: TeX Live with latexmk, latexdiff, poppler, fontaxes, and mweights; `TEXMFHOME` pointing at `docker/fonts/texmf` (built once with autoinst over `docker/fonts`), and each document loading its families' maps with `\pdfmapfile{+<Family>.map}`.
- Image: the drawio layer (draw.io, poppler, fonts) for export and rendering.
