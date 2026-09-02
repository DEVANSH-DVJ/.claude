#!/usr/bin/env python3
"""
Unpack a .pptx into a directory with every XML part pretty-printed, so edits and diffs are readable.
pack.py reverses the pretty print.

Usage:
    python unpack.py deck.pptx work/<name>
"""

import sys
import zipfile
from pathlib import Path
from xml.dom import minidom


def main():
    assert len(sys.argv) == 3, "Usage: python unpack.py deck.pptx <out_dir>"
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(src) as z:
        z.extractall(out)
    parts = [p for p in out.rglob("*") if p.suffix in (".xml", ".rels")]
    for part in parts:
        dom = minidom.parse(str(part))
        part.write_bytes(dom.toprettyxml(indent="  ", encoding="UTF-8"))
    print(f"unpacked {src} -> {out}/ ({len(parts)} XML parts)")


if __name__ == "__main__":
    main()
