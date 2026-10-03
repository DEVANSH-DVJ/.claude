---
name: pptx-addon
description: Edit slide decks (.pptx) a few slides at a time -- render to PNG, map slide numbers to XML parts, unpack, edit, pack, prove the untouched slides unchanged, re-render. Use for any task that reads, edits, or reviews a .pptx. Building a deck from HTML or filling a template belongs to the pptx skill of the document-skills plugin.
---

# Deck editing loop

A .pptx is a ZIP of XML parts plus media: edit the parts, render, look, repeat.
This skill carries the loop and its scripts.
Building a deck from HTML, filling a template deck, and schema validation belong to Anthropic's `pptx` skill, invoked as `/document-skills:pptx`.
`.claude/settings.json` registers its marketplace and enables the plugin; if it is missing on a machine, run `/plugin marketplace add anthropics/skills` and `/plugin install document-skills@anthropic-agent-skills`.

## Environment

Every command runs through the project runner from the repo root:

```bash
./docker/exec.sh "<command>"
```

Scripts live at `.claude/skills/pptx-addon/scripts/`; paths in this file are repo-relative.
Trust only container renders; a host without the image's fonts wraps text differently.
Scratch (unpacked XML, text dumps) goes in `work/`, renders in `render/`; keep both gitignored.

Slide numbers are 1-based like PowerPoint.
`ppt/slides/slideN.xml` numbering is file identity, not deck order; `slidemap.py` gives the order-to-part mapping.

## The loop

Use this for every "change slides X..Y" request. Change only what was asked; every other part stays byte-identical.

1. **Render and read** the current deck. Look at `grid.png` first, then the PNGs of the slides in scope.
   ```bash
   ./docker/exec.sh "python .claude/skills/pptx-addon/scripts/render.py deck_v6.pptx --grid"
   ./docker/exec.sh "python .claude/skills/pptx-addon/scripts/slidemap.py deck_v6.pptx"
   ./docker/exec.sh "markitdown deck_v6.pptx > work/deck_v6.md"
   ```
   A `font SUBSTITUTED: X -> Y` line on stderr means the render is not faithful; fix the image's fonts before judging layout.
2. **Scope**: map the requested slide numbers to parts with `slidemap.py`. Those parts, and any media they add, are the only files you may change.
3. **Edit**: unpack, edit the slide XML, pack.
   ```bash
   ./docker/exec.sh "python .claude/skills/pptx-addon/scripts/unpack.py deck_v6.pptx work/deck_v6"
   ./docker/exec.sh "python .claude/skills/pptx-addon/scripts/pack.py work/deck_v6 deck_v7.pptx"
   ```
   `pack.py` refuses malformed XML and checks that python-pptx opens the result.
   Use python-pptx directly only for scripted bulk changes; it re-serializes every part.
4. **Prove scope** against the version you started from:
   ```bash
   ./docker/exec.sh "python .claude/skills/pptx-addon/scripts/deckdiff.py deck_v6.pptx deck_v7.pptx"
   ```
   Only the in-scope slide parts may show as `changed`.
5. **Re-render the slides you touched** and inspect each PNG:
   ```bash
   ./docker/exec.sh "python .claude/skills/pptx-addon/scripts/render.py deck_v7.pptx --slides 3-5 --grid"
   ```
   Check for text overflowing its box or the slide edge, overlapping text or shapes, misaligned titles, columns, or icons, low contrast, wrong line wraps, and leftover placeholder text.
   If anything is off, go back to step 3. Stop only when every touched slide is clean.
6. **Check PowerPoint parity** before hand-off; a clean render is not enough (see below):
   ```bash
   ./docker/exec.sh "python .claude/skills/pptx-addon/scripts/pptcheck.py deck_v7.pptx"
   ```
   Fix every hit (step 3) until it exits 0.
7. **Report** which slides changed, what changed on each, and anything noticed on out-of-scope slides but left alone (factual errors, typos, layout bugs).

## Scripts

- `render.py deck.pptx [--slides 1,3-5] [--dpi 110] [--grid --cols 4] [--out DIR]`: PDF plus `slide-NN.png` per requested slide into `render/<deck path>/`, with font substitution warnings on stderr.
- `slidemap.py deck.pptx`: `slide N -> ppt/slides/slideM.xml` with each slide's title.
- `unpack.py deck.pptx work/<name>`: extracts the ZIP and pretty-prints every XML part.
- `pack.py work/<name> out.pptx`: reverses the pretty print, zips, and checks the result.
- `deckdiff.py old.pptx new.pptx`: lists added, removed, and changed parts, ignoring XML whitespace and attribute order.
- `pptcheck.py deck.pptx [...]`: flags what PowerPoint lays out differently from LibreOffice (an `<a:endParaRPr>` before the paragraph's end, a stored `normAutofit` scale, a line or a line plus the word wrapped after it within 97-103% of its box's width); exits 1 on any hit.

## Editing the XML

- Text lives in `<a:t>` inside runs `<a:r>`, inside paragraphs `<a:p>`, inside `<p:txBody>`. Change the text, keep the run's `<a:rPr>` so font, size, and color survive.
- Escape `&`, `<`, and `>` in text; keep `xml:space="preserve"` where it already is.
- Shapes are `<p:sp>` with `<p:nvSpPr>` (id and name), `<p:spPr>` (position `<a:off>`, size `<a:ext>`, in EMU; 914400 per inch), and the text body. Pictures are `<p:pic>` and reference media through the slide's `.rels`.
- A new image needs three things: the file under `ppt/media/`, a `Relationship` in `ppt/slides/_rels/slideN.xml.rels`, and a `Default` or `Override` entry in `[Content_Types].xml` for its extension.
- Speaker notes are `ppt/notesSlides/notesSlideN.xml`; theme fonts and colors are `ppt/theme/theme1.xml`; layouts and masters are `ppt/slideLayouts/` and `ppt/slideMasters/`.

## PowerPoint parity

A LibreOffice render is not proof of the PowerPoint look: PowerPoint differs in three ways a render cannot show, so run `pptcheck.py` before every hand-off.

- PowerPoint lays out text about 1% wider than LibreOffice, so a box sized exactly to its measured text wraps in PowerPoint though it fits in the render: give the box a few percent of slack, or `wrap="none"` for a one-line label.
- PowerPoint ignores a stored `normAutofit` `fontScale` or `lnSpcReduction` and draws the text at full size, while LibreOffice applies the shrink: never rely on autofit, state the font size explicitly and use `<a:noAutofit/>`.
- PowerPoint drops the runs after an `<a:endParaRPr>` that is not the last child of its `<a:p>`, while LibreOffice shows them: `<a:endParaRPr>` is always the paragraph's last child.

## Image requirements

The project image (`docker/Dockerfile.amd64`) must provide:

- apt: `libreoffice-impress poppler-utils fontconfig`, plus the deck's font families copied from `docker/fonts` into the image and `fc-cache -f` (the Dockerfile's fonts block); a family the image lacks shows up as `font SUBSTITUTED` in the render output.
- conda or pip: `python-pptx pdf2image pillow lxml markitdown[pptx]`.
- Only for the plugin's html2pptx workflow: Node 20 or newer with `pptxgenjs playwright sharp react-icons react react-dom`, `npx playwright install --with-deps chromium`, and `NODE_PATH=/usr/local/lib/node_modules`.
