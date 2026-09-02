#!/usr/bin/env python3
"""
Print deck order -> slide part, with each slide's title, so XML edits hit the right file.
Slide numbers are 1-based like PowerPoint; slideN.xml numbering is file identity, not order.

Usage:
    python slidemap.py deck.pptx
"""

import sys
import zipfile
from xml.etree import ElementTree as ET

P = "{http://schemas.openxmlformats.org/presentationml/2006/main}"
A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"


def title_of(slide_xml):
    """Text of the title placeholder, else the first text run."""
    root = ET.fromstring(slide_xml)
    for sp in root.iter(P + "sp"):
        ph = sp.find(f"./{P}nvSpPr/{P}nvPr/{P}ph")
        if ph is not None and ph.get("type") in ("title", "ctrTitle"):
            return "".join(t.text or "" for t in sp.iter(A + "t"))
    first = next(root.iter(A + "t"), None)
    return (first.text or "") if first is not None else ""


def main():
    assert len(sys.argv) == 2, "Usage: python slidemap.py deck.pptx"
    z = zipfile.ZipFile(sys.argv[1])
    rels = ET.fromstring(z.read("ppt/_rels/presentation.xml.rels"))
    target = {rel.get("Id"): rel.get("Target") for rel in rels}
    pres = ET.fromstring(z.read("ppt/presentation.xml"))
    for i, sld in enumerate(pres.iter(P + "sldId"), 1):
        part = "ppt/" + target[sld.get(R + "id")]
        print(f"slide {i:2d} -> {part:24s} {title_of(z.read(part))[:60]}")


if __name__ == "__main__":
    main()
