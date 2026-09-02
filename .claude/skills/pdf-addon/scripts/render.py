#!/usr/bin/env python3
"""
Render PDF pages to PNGs with pdftoppm, plus an optional labeled contact sheet.

Usage:
    python render.py doc.pdf [--pages 1,3-5] [--dpi 110] [--out DIR] [--grid] [--cols 4]

Pages are 1-based. Output goes to DIR (default render/<doc path>/): DIR/page-NN.png and DIR/grid.png.
"""

import argparse
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


def parse_pages(spec, n):
    """'1,3-5' -> sorted unique 1-based pages within 1..n."""
    if not spec:
        return list(range(1, n + 1))
    pages = set()
    for part in spec.split(","):
        a, _, b = part.partition("-")
        lo, hi = int(a), int(b or a)
        pages.update(range(lo, hi + 1))
    bad = sorted(p for p in pages if p < 1 or p > n)
    assert not bad, f"pages out of range 1..{n}: {bad}"
    return sorted(pages)


def contiguous_runs(pages):
    """[1,2,3,5] -> [(1,3),(5,5)] for pdftoppm -f/-l."""
    runs, start, prev = [], pages[0], pages[0]
    for p in pages[1:]:
        if p != prev + 1:
            runs.append((start, prev))
            start = p
        prev = p
    runs.append((start, prev))
    return runs


def page_count(pdf):
    info = subprocess.run(["pdfinfo", str(pdf)], check=True, capture_output=True, text=True)
    return int(re.search(r"^Pages:\s+(\d+)", info.stdout, re.MULTILINE).group(1))


def to_pngs(pdf, pages, dpi, out, tmp):
    """Rasterize the requested pages and rename to page-NN.png."""
    raw = tmp / "raw"
    raw.mkdir()
    for lo, hi in contiguous_runs(pages):
        subprocess.run(
            [
                "pdftoppm",
                "-png",
                "-r",
                str(dpi),
                "-f",
                str(lo),
                "-l",
                str(hi),
                str(pdf),
                str(raw / "p"),
            ],
            check=True,
        )
    outputs = []
    for f in sorted(raw.glob("p-*.png")):
        n = int(f.stem.split("-")[1])
        dest = out / f"page-{n:02d}.png"
        shutil.move(f, dest)
        outputs.append(dest)
    return outputs


def make_grid(pngs, out, cols, thumb_w=360):
    """Labeled contact sheet."""
    from PIL import Image, ImageDraw

    ims = [Image.open(p) for p in pngs]
    w, h = ims[0].size
    thumb_h = round(h * thumb_w / w)
    pad, label_h = 12, 22
    rows = -(-len(ims) // cols)
    sheet = Image.new(
        "RGB", (cols * (thumb_w + pad) + pad, rows * (thumb_h + label_h + pad) + pad), "white"
    )
    draw = ImageDraw.Draw(sheet)
    for i, (p, im) in enumerate(zip(pngs, ims)):
        x = pad + (i % cols) * (thumb_w + pad)
        y = pad + (i // cols) * (thumb_h + label_h + pad)
        draw.text((x, y + 4), f"page {int(p.stem.split('-')[1])}", fill="black")
        sheet.paste(im.resize((thumb_w, thumb_h)), (x, y + label_h))
        draw.rectangle([x, y + label_h, x + thumb_w - 1, y + label_h + thumb_h - 1], outline="#999")
    dest = out / "grid.png"
    sheet.save(dest)
    return dest


def default_out(pdf):
    """render/<doc path under the repo, without suffix>, else render/<stem>."""
    if pdf.is_relative_to(Path.cwd()):
        return Path("render") / pdf.relative_to(Path.cwd()).with_suffix("")
    return Path("render") / pdf.stem


def main():
    ap = argparse.ArgumentParser(description="Render PDF pages to PNG")
    ap.add_argument("pdf")
    ap.add_argument("--pages", help="1-based list/ranges, e.g. 1,3-5 (default: all)")
    ap.add_argument("--dpi", type=int, default=110)
    ap.add_argument("--out", help="output dir (default render/<doc path>/)")
    ap.add_argument("--grid", action="store_true", help="also write grid.png")
    ap.add_argument("--cols", type=int, default=4, help="grid columns")
    args = ap.parse_args()

    pdf = Path(args.pdf).resolve()
    assert pdf.is_file(), f"no such file: {pdf}"
    out = Path(args.out) if args.out else default_out(pdf)
    out.mkdir(parents=True, exist_ok=True)

    n = page_count(pdf)
    pages = parse_pages(args.pages, n)
    with tempfile.TemporaryDirectory(prefix="render-") as td:
        pngs = to_pngs(pdf, pages, args.dpi, out, Path(td))

    print(f"{n} pages in document; rendered {len(pngs)} to {out}/")
    for p in pngs:
        print(f"  {p}")
    if args.grid:
        print(f"  {make_grid(pngs, out, args.cols)}")


if __name__ == "__main__":
    main()
