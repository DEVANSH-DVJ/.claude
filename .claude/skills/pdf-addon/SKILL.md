---
name: pdf-addon
description: Review PDFs visually and between versions -- render pages to PNG with a contact sheet, dump text, and diff two PDFs page by page by text and pixels. Use when a PDF (a built paper, a deck export, a report) must be checked by eye or compared with its previous version. Extraction, creation, merging, forms, and OCR belong to the pdf skill of the document-skills plugin.
user-invocable: true
---

# PDF review loop

Look at pages as images, read the text, and compare versions page by page.

- Extraction, creation, merging, splitting, forms, and OCR belong to Anthropic's `pdf` skill, invoked as `/document-skills:pdf`.
- `.claude/settings.json` registers its marketplace and enables the plugin.
- If it is missing on a machine, run `/plugin marketplace add anthropics/skills` and `/plugin install document-skills@anthropic-agent-skills`.

## Environment

Every command runs through the project runner from the repo root:

```bash
./docker/exec.sh "<command>"
```

- Scripts live at `.claude/skills/pdf-addon/scripts/`.
- Paths in this file are repo-relative.
- Renders go in `render/` and scratch in `work/`.
  If either is not ignored, add it to `.git/info/exclude`, never to a `.gitignore`.
- Pages are 1-based.

## The loop

1. **Render** the pages in question and look at the contact sheet (`grid.png`, every rendered page as a thumbnail) first, then the pages:
   ```bash
   ./docker/exec.sh "python .claude/skills/pdf-addon/scripts/render.py paper.pdf --grid"
   ./docker/exec.sh "python .claude/skills/pdf-addon/scripts/render.py paper.pdf --pages 3-5 --dpi 150"
   ```
2. **Read** the text when wording matters: `./docker/exec.sh "pdftotext -layout paper.pdf work/paper.txt"`.
3. **Compare** with the previous version to find the pages worth opening:
   ```bash
   ./docker/exec.sh "python .claude/skills/pdf-addon/scripts/pdfdiff.py paper_v1.pdf paper_v2.pdf --text"
   ```
   A page with text changes and few pixels changed is a wording edit; many pixels and no text is a figure or layout change.
4. **Check** each rendered page for overflow past margins, overlapping floats, orphaned headings, missing figures, and wrong fonts.
5. **Report** page numbers with what changed or what is wrong.

## Scripts

- `render.py doc.pdf [--pages 1,3-5] [--dpi 110] [--grid --cols 4] [--out DIR]`: `page-NN.png` per requested page into `render/<the PDF's repo path without .pdf>/`, plus `grid.png` with `--grid`.
- `pdfdiff.py old.pdf new.pdf [--dpi 40] [--text]`: one line per changed page with text lines and pixel fraction changed; `--text` adds the unified text diff.

## Image requirements

- apt: `poppler-utils` (pdftoppm, pdftotext, pdfinfo).
- conda or pip: `pillow`.
