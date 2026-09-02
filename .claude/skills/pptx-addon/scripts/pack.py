#!/usr/bin/env python3
"""
Pack an unpacked deck directory back into a .pptx, reversing unpack.py's pretty print, then check the result:
every XML part must parse, and python-pptx must open the file when it is installed.

Usage:
    python pack.py work/<name> out.pptx
"""

import sys
import zipfile
from pathlib import Path
from xml.dom import minidom
from xml.etree import ElementTree as ET

DECLARATION = b'<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'


def strip_pretty(node):
    """Drop the newline-bearing whitespace nodes that pretty-printing added; real spaces have no newline."""
    for child in list(node.childNodes):
        if child.nodeType == child.TEXT_NODE and "\n" in child.data and not child.data.strip():
            node.removeChild(child)
        elif child.nodeType == child.ELEMENT_NODE:
            strip_pretty(child)


def minified(part):
    dom = minidom.parse(str(part))
    strip_pretty(dom.documentElement)
    return DECLARATION + dom.documentElement.toxml().encode("utf-8")


def check(pptx):
    with zipfile.ZipFile(pptx) as z:
        for name in z.namelist():
            if name.endswith((".xml", ".rels")):
                ET.fromstring(z.read(name))
    try:
        from pptx import Presentation
    except ImportError:
        return "XML well-formed; python-pptx not installed, open check skipped"
    Presentation(str(pptx))
    return "XML well-formed, opens in python-pptx"


def main():
    assert len(sys.argv) == 3, "Usage: python pack.py <unpacked_dir> out.pptx"
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    files = sorted(p for p in src.rglob("*") if p.is_file())
    # content types first, as Office writes it
    files.sort(key=lambda p: p.name != "[Content_Types].xml")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            name = f.relative_to(src).as_posix()
            data = minified(f) if f.suffix in (".xml", ".rels") else f.read_bytes()
            z.writestr(name, data)
    print(f"packed {src}/ -> {out}: {check(out)}")


if __name__ == "__main__":
    main()
