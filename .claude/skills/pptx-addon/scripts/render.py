#!/usr/bin/env python3
"""
Render a .pptx to per-slide PNGs via LibreOffice (pptx -> pdf) and pdftoppm (pdf -> png).

Usage:
    python render.py deck.pptx [--slides 1,3-5] [--dpi 110] [--out DIR] [--grid] [--cols 4]

Slides are 1-based like PowerPoint. Output goes to DIR (default render/<deck path>/):
    DIR/<stem>.pdf        the full rendered deck
    DIR/slide-NN.png      one PNG per requested slide
    DIR/grid.png          labeled contact sheet of the requested slides (with --grid)
Fonts the deck asks for that fontconfig cannot supply exactly are reported on stderr.
"""

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

# metric-compatible clones
METRIC_CLONES = {
    "Calibri": {"Carlito"},
    "Calibri Light": {"Carlito"},
    "Cambria": {"Caladea"},
    "Arial": {"Liberation Sans", "Arimo"},
    "Helvetica": {"Liberation Sans", "Arimo"},
    "Times New Roman": {"Liberation Serif", "Tinos"},
    "Courier New": {"Liberation Mono", "Cousine"},
}


def parse_slides(spec, n):
    """'1,3-5' -> sorted unique 1-based pages within 1..n."""
    if not spec:
        return list(range(1, n + 1))
    pages = set()
    for part in spec.split(","):
        a, _, b = part.partition("-")
        lo, hi = int(a), int(b or a)
        pages.update(range(lo, hi + 1))
    bad = sorted(p for p in pages if p < 1 or p > n)
    assert not bad, f"slides out of range 1..{n}: {bad}"
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


def deck_fonts(pptx):
    """Latin and bullet typefaces referenced under ppt/."""
    fonts = set()
    with zipfile.ZipFile(pptx) as z:
        for name in z.namelist():
            if name.startswith("ppt/") and name.endswith(".xml"):
                fonts.update(
                    re.findall(rb'<a:(?:latin|buFont) typeface="([^"+][^"]*)"', z.read(name))
                )
    return sorted(f.decode() for f in fonts if f.strip())


def fc_match():
    """System fontconfig, the one LibreOffice uses."""
    system = Path("/usr/bin/fc-match")
    return str(system) if system.exists() else shutil.which("fc-match")


def report_font_substitutions(pptx):
    """Warn when fontconfig resolves a deck font to something else."""
    fc = fc_match()
    if not fc:
        return
    for font in deck_fonts(pptx):
        got = subprocess.run(
            [fc, "-f", "%{family[0]}", font], check=True, capture_output=True, text=True
        ).stdout.strip()
        if got == font:
            continue
        kind = "metric clone" if got in METRIC_CLONES.get(font, set()) else "SUBSTITUTED"
        print(f"font {kind}: {font} -> {got}", file=sys.stderr)


def to_pdf(pptx, tmp):
    """Convert with a private LibreOffice profile; safe to run in parallel."""
    profile = tmp / "lo-profile"
    run = subprocess.run(
        [
            "soffice",
            f"-env:UserInstallation=file://{profile}",
            "--headless",
            "--norestore",
            "--convert-to",
            "pdf",
            "--outdir",
            str(tmp),
            str(pptx),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    # drop the javaldx warning
    for line in run.stderr.splitlines():
        if "javaldx" not in line:
            print(line, file=sys.stderr)
    pdf = tmp / f"{pptx.stem}.pdf"
    assert pdf.exists(), "soffice produced no PDF"
    return pdf


def page_count(pdf):
    info = subprocess.run(["pdfinfo", str(pdf)], check=True, capture_output=True, text=True)
    return int(re.search(r"^Pages:\s+(\d+)", info.stdout, re.MULTILINE).group(1))


def to_pngs(pdf, pages, dpi, out, tmp):
    """Rasterize the requested pages and rename to slide-NN.png."""
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
        dest = out / f"slide-{n:02d}.png"
        shutil.move(f, dest)
        outputs.append(dest)
    return outputs


def make_grid(pngs, out, cols, thumb_w=360):
    """Labeled contact sheet; slide numbers match PowerPoint."""
    from PIL import Image, ImageDraw

    ims = [Image.open(p) for p in pngs]
    w, h = ims[0].size
    thumb_h = round(h * thumb_w / w)
    pad, label_h = 12, 22
    rows = -(-len(ims) // cols)
    sheet = Image.new(
        "RGB",
        (cols * (thumb_w + pad) + pad, rows * (thumb_h + label_h + pad) + pad),
        "white",
    )
    draw = ImageDraw.Draw(sheet)
    for i, (p, im) in enumerate(zip(pngs, ims)):
        x = pad + (i % cols) * (thumb_w + pad)
        y = pad + (i // cols) * (thumb_h + label_h + pad)
        draw.text((x, y + 4), f"slide {int(p.stem.split('-')[1])}", fill="black")
        thumb = im.resize((thumb_w, thumb_h))
        sheet.paste(thumb, (x, y + label_h))
        draw.rectangle([x, y + label_h, x + thumb_w - 1, y + label_h + thumb_h - 1], outline="#999")
    dest = out / "grid.png"
    sheet.save(dest)
    return dest


def default_out(pptx):
    """render/<deck path under the repo, without suffix>, else render/<stem>."""
    if pptx.is_relative_to(Path.cwd()):
        return Path("render") / pptx.relative_to(Path.cwd()).with_suffix("")
    return Path("render") / pptx.stem


def main():
    ap = argparse.ArgumentParser(description="Render pptx slides to PNG")
    ap.add_argument("pptx")
    ap.add_argument("--slides", help="1-based list/ranges, e.g. 1,3-5 (default: all)")
    ap.add_argument("--dpi", type=int, default=110)
    ap.add_argument("--out", help="output dir (default render/<stem>/)")
    ap.add_argument("--grid", action="store_true", help="also write grid.png")
    ap.add_argument("--cols", type=int, default=4, help="grid columns")
    args = ap.parse_args()

    pptx = Path(args.pptx).resolve()
    assert pptx.is_file(), f"no such file: {pptx}"
    out = Path(args.out) if args.out else default_out(pptx)
    out.mkdir(parents=True, exist_ok=True)

    report_font_substitutions(pptx)
    with tempfile.TemporaryDirectory(prefix="render-") as td:
        tmp = Path(td)
        pdf = to_pdf(pptx, tmp)
        n = page_count(pdf)
        pages = parse_slides(args.slides, n)
        shutil.copy(pdf, out / pdf.name)
        pngs = to_pngs(pdf, pages, args.dpi, out, tmp)

    print(f"{n} slides in deck; rendered {len(pngs)} to {out}/")
    for p in pngs:
        print(f"  {p}")
    if args.grid:
        print(f"  {make_grid(pngs, out, args.cols)}")


if __name__ == "__main__":
    main()
