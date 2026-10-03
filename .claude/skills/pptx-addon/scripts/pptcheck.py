#!/usr/bin/env python3
"""
Flag pptx constructs PowerPoint lays out differently from LibreOffice:
an <a:endParaRPr> before a paragraph's last child, a stored normAutofit scale,
and, wrapping greedily at spaces, a line or a line plus the word wrapped after it
within 97-103% of the box's inner width.
Prints one line per hit and exits 1 if any.

Usage:
    python pptcheck.py deck.pptx [deck2.pptx ...]
"""

import posixpath
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from PIL import ImageFont

P = "{http://schemas.openxmlformats.org/presentationml/2006/main}"
A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"
R = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
PR = "{http://schemas.openxmlformats.org/package/2006/relationships}"

EMU_PT = 12700
DEFAULT_INS = 91440
TIGHT = (0.97, 1.03)
MEASURE_PX = 1000


def fc_match():
    """System fontconfig, the one LibreOffice uses."""
    system = Path("/usr/bin/fc-match")
    return str(system) if system.exists() else shutil.which("fc-match")


def fc_file(pattern):
    """Font file fontconfig picks for a pattern."""
    out = subprocess.run(
        [fc_match(), "-f", "%{file}", pattern], capture_output=True, text=True, check=True
    )
    return out.stdout


FALLBACK = fc_file("pptcheck-no-such-font")
_fonts = {}


def font(face, bold, italic):
    """Pillow font at MEASURE_PX for a face and style, None if fontconfig falls back."""
    key = (face, bold, italic)
    if key not in _fonts:
        style = ":bold" * bold + ":italic" * italic
        path = fc_file(face.replace("-", r"\-") + style)
        _fonts[key] = None if path == FALLBACK else ImageFont.truetype(path, MEASURE_PX)
    return _fonts[key]


class Deck:
    """Zip reader with part relationships resolved."""

    def __init__(self, path):
        self.zip = zipfile.ZipFile(path)
        self._xml = {}

    def xml(self, part):
        if part not in self._xml:
            self._xml[part] = ET.fromstring(self.zip.read(part))
        return self._xml[part]

    def rel(self, part, rtype):
        """Target part of the first relationship ending in rtype."""
        rels = posixpath.join(posixpath.dirname(part), "_rels", posixpath.basename(part) + ".rels")
        for r in self.xml(rels).iter(PR + "Relationship"):
            if r.get("Type").endswith("/" + rtype):
                return posixpath.normpath(posixpath.join(posixpath.dirname(part), r.get("Target")))
        return None

    def slides(self):
        """(number, part) in deck order."""
        rels = self.xml("ppt/_rels/presentation.xml.rels")
        target = {r.get("Id"): r.get("Target") for r in rels}
        pres = self.xml("ppt/presentation.xml")
        for i, sld in enumerate(pres.iter(P + "sldId"), 1):
            yield i, posixpath.normpath("ppt/" + target[sld.get(R + "id")])


def ph_of(sp):
    return sp.find(f"{P}nvSpPr/{P}nvPr/{P}ph")


def find_ph(tree, ph):
    """Placeholder in a layout or master matching idx, else type."""
    ptype = ph.get("type", "body")
    by_type = None
    for sp in tree.iter(P + "sp"):
        other = ph_of(sp)
        if other is None:
            continue
        if ph.get("idx") is not None and other.get("idx") == ph.get("idx"):
            return sp
        if by_type is None and other.get("type", "body") == ptype:
            by_type = sp
    return by_type


def text_style(master, ph):
    """Master txStyles branch a placeholder type draws from."""
    ptype = ph.get("type", "body")
    name = {"title": "titleStyle", "ctrTitle": "titleStyle"}.get(ptype, "bodyStyle")
    if ptype in ("dt", "ftr", "sldNum", "hdr"):
        name = "otherStyle"
    return master.find(f"{P}txStyles/{P}{name}")


def check_shape(sp, chain, scale, theme, defaults):
    """Yield problems for one text shape; chain is its inherited shapes, nearest first."""
    tb = sp.find(P + "txBody")
    if tb is None:
        return
    for p in tb.findall(A + "p"):
        end = p.find(A + "endParaRPr")
        if end is not None and list(p)[-1] is not end:
            text = "".join(t.text or "" for t in p.iter(A + "t"))
            yield f'endParaRPr before the last child, PowerPoint drops "{text[:40]}"'
    bodies = [tb.find(A + "bodyPr")] + [s.find(f"{P}txBody/{A}bodyPr") for s in chain]
    bodies = [b for b in bodies if b is not None]
    fit = bodies[0].find(A + "normAutofit") if bodies else None
    if fit is not None and (fit.get("fontScale") or fit.get("lnSpcReduction")):
        yield "normAutofit stores fontScale or lnSpcReduction, PowerPoint ignores it"

    def body_attr(name, default):
        return next((b.get(name) for b in bodies if b.get(name) is not None), default)

    if body_attr("wrap", "square") == "none" or body_attr("vert", "horz") != "horz":
        return
    exts = [s.find(f"{P}spPr/{A}xfrm/{A}ext") for s in [sp] + chain]
    ext = next((e for e in exts if e is not None), None)
    if ext is None:
        return
    ins = int(body_attr("lIns", DEFAULT_INS)) + int(body_attr("rIns", DEFAULT_INS))
    inner = (int(ext.get("cx")) * scale - ins) / EMU_PT
    styles = [tb.find(A + "lstStyle")] + [s.find(f"{P}txBody/{A}lstStyle") for s in chain]
    styles += defaults
    for p in tb.findall(A + "p"):
        ppr = p.find(A + "pPr")
        lvl = f"lvl{int(ppr.get('lvl', 0)) + 1 if ppr is not None else 1}pPr"
        inherited = [s.find(A + lvl) if s is not None else None for s in styles]
        inherited = [lv for lv in inherited if lv is not None]
        levels = ([ppr] if ppr is not None else []) + inherited
        mar = next((int(lv.get("marL")) for lv in levels if lv.get("marL")), 0)
        # run defaults come from the inherited levels only
        defs = [lv.find(A + "defRPr") for lv in inherited if lv.find(A + "defRPr") is not None]
        avail = inner - mar / EMU_PT
        lines = [[]]
        for el in p:
            if el.tag == A + "br":
                lines.append([])
            elif el.tag in (A + "r", A + "fld"):
                lines[-1].append(el)
        for runs in lines:
            text = "".join(r.findtext(A + "t") or "" for r in runs)
            if not text.strip():
                continue
            try:
                pieces = styled(runs, defs, theme)
            except LookupError as why:
                yield f'{why}, skipped "{text[:40]}"'
                continue
            for start, end in wrap(pieces, text, avail):
                ratio = width(pieces, start, end) / avail
                if TIGHT[0] <= ratio <= TIGHT[1]:
                    yield f'tight line {ratio:.1%} of {avail:.1f} pt: "{text[start:end][-40:]}"'


def styled(runs, defs, theme):
    """(text, font, pt, spc) per run; LookupError names what did not resolve."""
    pieces = []
    for r in runs:
        rpr = r.find(A + "rPr")
        props = [rpr] + defs if rpr is not None else defs

        def get(attr, props=props):
            return next((e.get(attr) for e in props if e.get(attr) is not None), None)

        latin = [e.find(A + "latin") for e in props]
        face = next((e.get("typeface") for e in latin if e is not None and e.get("typeface")), None)
        face = theme.get(face, face)
        size = get("sz")
        if face is None or size is None:
            raise LookupError("font unresolved" if face is None else "size unresolved")
        f = font(face, get("b") == "1", get("i") == "1")
        if f is None:
            raise LookupError(f"font unresolved ({face})")
        text = r.findtext(A + "t") or ""
        pieces.append((text, f, int(size) / 100, int(get("spc") or 0) / 100))
    return pieces


def width(pieces, start, end):
    """Nominal width in pt of characters start..end across styled pieces."""
    total, pos = 0.0, 0
    for text, f, pt, spc in pieces:
        part = text[max(start - pos, 0) : max(end - pos, 0)]
        total += f.getlength(part) * pt / MEASURE_PX + spc * len(part)
        pos += len(text)
    return total


def wrap(pieces, text, avail):
    """(start, end) of each line wrapped greedily at spaces, and of the line plus the word wrapped after it."""
    words = [m.span() for m in re.finditer(r"\S+", text)]
    start, end = words[0]
    for s, e in words[1:]:
        if width(pieces, start, e) > avail:
            yield start, end
            yield start, e
            start = s
        end = e
    yield start, end


def theme_fonts(deck, master_part):
    """Map +mj-lt and +mn-lt to the master's theme faces."""
    theme = deck.xml(deck.rel(master_part, "theme"))
    out = {}
    for key, tag in (("+mj-lt", "majorFont"), ("+mn-lt", "minorFont")):
        latin = theme.find(f".//{A}{tag}/{A}latin")
        out[key] = latin.get("typeface")
    return out


def shapes(tree, scale=1.0):
    """(sp, scale) for every text shape, through group transforms."""
    for el in tree:
        if el.tag == P + "sp":
            yield el, scale
        elif el.tag == P + "grpSp":
            xfrm = el.find(f"{P}grpSpPr/{A}xfrm")
            ext, chext = xfrm.find(A + "ext"), xfrm.find(A + "chExt")
            sub = scale
            if ext is not None and chext is not None and int(chext.get("cx")):
                sub *= int(ext.get("cx")) / int(chext.get("cx"))
            yield from shapes(el, sub)


def check(path):
    deck = Deck(path)
    pres_defaults = deck.xml("ppt/presentation.xml").find(P + "defaultTextStyle")
    hits = 0
    for num, part in deck.slides():
        layout_part = deck.rel(part, "slideLayout")
        master_part = deck.rel(layout_part, "slideMaster")
        layout, master = deck.xml(layout_part), deck.xml(master_part)
        theme = theme_fonts(deck, master_part)
        for sp, scale in shapes(deck.xml(part).find(f"{P}cSld/{P}spTree")):
            ph = ph_of(sp)
            chain, defaults = [], [pres_defaults]
            if ph is not None:
                chain = [s for s in (find_ph(layout, ph), find_ph(master, ph)) if s is not None]
                defaults = [text_style(master, ph)]
            nv = sp.find(f"{P}nvSpPr/{P}cNvPr")
            for problem in check_shape(sp, chain, scale, theme, defaults):
                print(f'slide {num}  shape "{nv.get("name")}" id={nv.get("id")}: {problem}')
                hits += 1
    return hits


if __name__ == "__main__":
    assert len(sys.argv) >= 2, "Usage: python pptcheck.py deck.pptx [deck2.pptx ...]"
    hits = 0
    for path in sys.argv[1:]:
        if len(sys.argv) > 2:
            print(f"== {path}")
        hits += check(path)
    sys.exit(1 if hits else 0)
