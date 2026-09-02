#!/usr/bin/env python3
"""
List which parts differ between two .pptx files, ignoring XML whitespace and attribute order.
Use it after a targeted edit to prove the untouched slides really are untouched.

Usage:
    python deckdiff.py old.pptx new.pptx
"""

import sys
import zipfile
from xml.etree import ElementTree as ET


def normalized(name, data):
    """Canonical XML for xml/rels parts, raw bytes otherwise."""
    if name.endswith((".xml", ".rels")):
        try:
            return ET.canonicalize(data.decode("utf-8"), strip_text=True)
        except ET.ParseError:
            return data
    return data


def main():
    assert len(sys.argv) == 3, "Usage: python deckdiff.py old.pptx new.pptx"
    old, new = (zipfile.ZipFile(p) for p in sys.argv[1:3])
    old_names, new_names = set(old.namelist()), set(new.namelist())
    changed = sorted(
        n for n in old_names & new_names if normalized(n, old.read(n)) != normalized(n, new.read(n))
    )
    for label, names in (
        ("added", sorted(new_names - old_names)),
        ("removed", sorted(old_names - new_names)),
        ("changed", changed),
    ):
        for n in names:
            print(f"{label}: {n}")
    same = len(old_names & new_names) - len(changed)
    print(f"identical: {same} parts")


if __name__ == "__main__":
    main()
