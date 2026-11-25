---
name: latex
description: Build, review, and diff LaTeX papers for any venue class and beamer talks with the repo's own make on the host -- log and font checks, page renders with a page-budget gate, latexdiff against a previous submission, camera-ready preparation. Use for any task on a .tex file, a paper or talk build, a latexdiff, a camera-ready, a beamer deck, or "review the PDF" of a paper or deck. Prose belongs to the writing skill. Deck structure, builds, and notes belong to the beamer skill.
user-invocable: true
argument-hint: "[paper or talk dir]"
---

Papers for any venue class, and beamer talks.

- Builds run on the host with the repo's own `make`, never inside the container. The container only exports diagrams and renders PDFs.
- Follow the layout of this repo and of any earlier paper repo the owner points to.
- Prose rules are the `writing` skill's.

## Build

- Run the directory's `make` target as the repo defines it.
- With no target, stop: a Makefile is written only together with the owner, never added on your own.
- The log has no `Overfull \hbox` or `\vbox`, `Missing character`, or undefined reference or citation.
  Where a fix needs the prose reworded, report what needs rewording instead of rewriting it.
- `pdffonts <pdf>` lists no Type 3 font.

## Review

- Render with the `pdf-addon` skill, contact sheet (one image of every page as a thumbnail) first, and diff against the previous version when one exists.
- Gate on the page budget before anything else.
  - On the contact sheet, the page holding the references heading must be within the limit the owner gives.
  - Ask the owner whether that page itself counts toward the limit, and report an overrun first.
- Figure text is never smaller than the caption.

## Diff

- Run the repo's diff target when it has one.
- Otherwise, with `<rev>` the revision the owner names and `<root>` the root `.tex` file's name without `.tex`:

  ```bash
  mkdir -p work/old
  git archive <rev> <paper dir> | tar -x -C work/old
  latexdiff --flatten work/old/<paper dir>/<root>.tex <paper dir>/<root>.tex > <paper dir>/diff.tex
  ```

- Build `diff.tex` in the paper dir so figures resolve.
- Check that every addition shows as markup in the diff PDF.

## Camera-ready

- Set the venue's final class options.
- De-anonymize.
- Add the copyright or license block the venue supplies.
- Remove review-only markup and macros.
- Rerun the Build steps and the page-budget check against the final limit.

## Figures

- `.drawio` sources stay beside their exports; export through the `drawio` skill, one page per call.

## Conventions

- Quotes, pointers, and labels follow `voice.md` of the `writing` skill and the repo's existing source.
- `\vspace`, negative values included, is allowed to fit a page budget and overrides the venue's spacing rules; only the owner's word for a given paper restricts it.

## Requirements

- Host: TeX Live with latexmk, latexdiff, poppler, fontaxes, and mweights.
  - `TEXMFHOME` points at `docker/fonts/texmf`, which the template ships prebuilt by autoinst from `docker/fonts`.
  - Each document loads its families' maps with `\pdfmapfile{+<Family>.map}`.
- Image: the Dockerfile's drawio block (draw.io, poppler, fonts) for export and rendering.
