---
name: beamer
description: Write, build, and review a LaTeX beamer talk deck -- one frame per file, builds as separate files with no overlays, draw.io figures whose pages are the builds, a speaker note on every page, and the page-by-page render check. Use for any task that writes, edits, builds, or reviews slides of a beamer deck. Log and font checks belong to the latex skill, export to the drawio skill, renders to the pdf-addon skill, and slide text and notes to the writing skill.
user-invocable: true
argument-hint: "[deck dir]"
---

# Beamer deck loop

A deck is the directory holding its `main.tex`, which inputs one file per PDF page from `tex/`, in reading order.
`project.md` says where a project keeps its decks and how it builds them.

## Files

- One frame per file: `tex/NN-<section>/NN-MM-<name>.tex`.
- A build (animation step) is its own file with a `-A`, `-B`, ... suffix and its own PDF page, so the deck needs no overlays; a bare `NN-MM-<name>.tex` never sits beside suffixed ones.
- A build repeats its predecessor and changes only what the step reveals or highlights.
- Titles, positions, and figure sizes are identical across the builds of one slide; text a later build reveals is held by `\phantom{...}` until then, so no page jumps.
- `main.tex` stays minimal: the class, the `utils/` inputs, the title metadata, `\section{}`, and one `\input{tex/...}` per page in reading order.
- `utils/packages.tex` holds packages and fonts, `utils/style.tex` the theme and palette, and `utils/defines.tex` the macros; a slide file never inlines a colour hex or a font size.
- A font package that sets only the roman family is paired with `\renewcommand{\sfdefault}{\rmdefault}`, since beamer sets its text in sans.
- Every frame carries a speaker note, what is said aloud on that page, with the cues `<next slide>`, `<quick next slide>`, and `<pause>`.
- A figure not drawn yet is a visible placeholder box, listed in the plan doc until drawn; the delivered PDF holds none.

## Figures

- Diagrams are draw.io only, never TikZ; a figure from a paper or an earlier deck is reworked for the slide flow as a build sequence, never included as is.
- A diagram redrawn from a source page is matched to a render of that page for fonts, sizes, centering, alignment, and spacing, and is accepted only after an independent reviewer compares the pair.
- The builds of a diagram are the pages of one `figures/<name>.drawio`, page 1 being build A, each exported to `figures/<name>-<A|B|...>.pdf` with the drawio skill.
- Every page of a build set starts its cell list with the same invisible frame rectangle (`fillColor=none;strokeColor=none;`) at the same geometry, so the cropped PDFs share one size and position.
- The export normalizes each PDF through `pdftocairo`, which blackens masked images such as an SVG with masks; embed such an image as an RGBA PNG.
- draw.io text uses the deck's text font and the palette of `utils/style.tex`.
- Every build of a figure is included at the same slide-relative width, such as `width=0.9\textwidth`.

## Review

1. Render with the pdf-addon skill: the contact sheet first, then every page in scope one by one at projector resolution, about 200 dpi.
2. A reviewer that did not make the pages checks each one for text past the frame, overlap, a line break inside a phrase, alignment, spacing, sizes that differ between pages, a build that jumps, and colours outside the palette.
3. Text the audience must read is legible at slide size; a label the speech explains may be small.
4. The slides PDF embeds only the families `utils/` loads, math fonts, and fonts embedded in figure PDFs; the latex skill holds the font check.
5. The notes match the deck page for page, and the plan doc's word budget holds.
