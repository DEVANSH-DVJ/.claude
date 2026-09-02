#!/usr/bin/env python3
"""
Compare two PDFs page by page: text lines changed (pdftotext) and pixels changed (pdftoppm at low dpi).
Use it between versions of a paper or deck export to find the pages worth looking at.

Usage:
    python pdfdiff.py old.pdf new.pdf [--dpi 40] [--text]

Prints one line per changed page; --text also prints the unified text diff.
"""

import argparse
import difflib
import re
import subprocess
import tempfile
from pathlib import Path


def page_count(pdf):
    info = subprocess.run(["pdfinfo", str(pdf)], check=True, capture_output=True, text=True)
    return int(re.search(r"^Pages:\s+(\d+)", info.stdout, re.MULTILINE).group(1))


def page_text(pdf, n):
    out = subprocess.run(
        ["pdftotext", "-layout", "-f", str(n), "-l", str(n), str(pdf), "-"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    return [line.rstrip() for line in out.splitlines() if line.strip()]


def page_images(pdf, dpi, tmp, tag):
    subprocess.run(
        ["pdftoppm", "-gray", "-png", "-r", str(dpi), str(pdf), str(tmp / tag)], check=True
    )
    return {int(f.stem.split("-")[1]): f for f in tmp.glob(f"{tag}-*.png")}


def pixel_change(a, b):
    """Fraction of pixels whose gray level differs noticeably; 1.0 when the page sizes differ."""
    from PIL import Image, ImageChops

    ia, ib = Image.open(a).convert("L"), Image.open(b).convert("L")
    if ia.size != ib.size:
        return 1.0
    mask = ImageChops.difference(ia, ib).point(lambda v: 255 if v > 32 else 0)
    return mask.histogram()[255] / (ia.size[0] * ia.size[1])


def main():
    ap = argparse.ArgumentParser(description="Page-by-page PDF comparison")
    ap.add_argument("old")
    ap.add_argument("new")
    ap.add_argument("--dpi", type=int, default=40, help="raster resolution for the pixel check")
    ap.add_argument(
        "--text", action="store_true", help="print the unified text diff per changed page"
    )
    args = ap.parse_args()
    old, new = Path(args.old), Path(args.new)

    n_old, n_new = page_count(old), page_count(new)
    if n_old != n_new:
        print(f"page count: {n_old} -> {n_new}")
    with tempfile.TemporaryDirectory(prefix="pdfdiff-") as td:
        tmp = Path(td)
        imgs_old, imgs_new = (
            page_images(old, args.dpi, tmp, "old"),
            page_images(new, args.dpi, tmp, "new"),
        )
        changed = 0
        for n in range(1, min(n_old, n_new) + 1):
            t_old, t_new = page_text(old, n), page_text(new, n)
            delta = list(difflib.unified_diff(t_old, t_new, lineterm="", n=0))
            lines = sum(1 for d in delta if d[:1] in "+-" and d[:3] not in ("+++", "---"))
            pixels = pixel_change(imgs_old[n], imgs_new[n])
            if lines or pixels > 0.001:
                changed += 1
                print(f"page {n:3d}: {lines} text lines changed, {pixels:.1%} pixels changed")
                if args.text and delta:
                    print("\n".join("    " + d for d in delta[2:]))
    same = min(n_old, n_new) - changed
    print(f"{changed} pages changed, {same} unchanged")


if __name__ == "__main__":
    main()
