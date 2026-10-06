#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_slides.py — مُولِّد العروض التقديمية (PPTX) لورشة Git وGitHub
===================================================================
المصادر: source/slides/s2.md … (بصيغة بسيطة موثّقة في source/slides/README.md)
المخرجات: slides/*.pptx  — مقاس 16:9، RTL، خطوط عربية واضحة

الاستخدام:
    python3 tools/build_slides.py                 # الكل
    python3 tools/build_slides.py 03              # عرض واحد
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

from pptx import Presentation
from pptx.util import Cm, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "source" / "slides"
OUT = ROOT / "slides"
ASSETS = ROOT / "assets"

# ---------------- الهوية البصرية ----------------
NAVY = RGBColor(0x12, 0x20, 0x3C)
NAVY2 = RGBColor(0x1E, 0x3A, 0x5F)
ORANGE = RGBColor(0xE8, 0x62, 0x0C)
TEAL = RGBColor(0x0E, 0x7C, 0x7B)
GREEN = RGBColor(0x12, 0x8A, 0x5B)
RED = RGBColor(0xB3, 0x26, 0x1E)
VIOLET = RGBColor(0x6D, 0x3B, 0xB5)
INK = RGBColor(0x12, 0x16, 0x1C)
BODY = RGBColor(0x22, 0x30, 0x3F)
MUTED = RGBColor(0x6B, 0x76, 0x84)
LIGHT = RGBColor(0xF4, 0xF7, 0xFA)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
LINE = RGBColor(0xD6, 0xDD, 0xE6)

CODE_BG = RGBColor(0x0F, 0x17, 0x2A)
CODE_TXT = RGBColor(0xE6, 0xED, 0xF7)
CODE_CMD = RGBColor(0x7F, 0xD1, 0xA8)

AR_FONT = "Cairo"
EN_FONT = "Segoe UI"
MONO_FONT = "Consolas"

SLIDE_W = Cm(33.867)
SLIDE_H = Cm(19.05)
MARGIN = Cm(1.5)
CONTENT_W = SLIDE_W - 2 * MARGIN

SAFE = {"✅": "✔", "❌": "✘", "🟢": "●", "🔒": "▣", "🔗": "➜", "⬜": "☐", "⚠️": "⚠", "⏱": "★"}


def safen(t: str) -> str:
    for b, g in SAFE.items():
        t = t.replace(b, g)
    return t


# ---------------- محلّل المصدر ----------------
BLOCK_RE = re.compile(r"^:::(?P<name>[a-z0-9_-]+)(?:\{(?P<attrs>.*)\})?\s*$", re.I)


def parse_attrs(raw: str | None) -> dict:
    if not raw:
        return {}
    out = {}
    for m in re.finditer(r'([a-zA-Z0-9_-]+)(?:\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^\s]+)))?', raw):
        val = next((g for g in m.groups()[1:] if g is not None), "1")
        out[m.group(1)] = safen(val)
    return out


def parse_deck(path: Path) -> tuple[dict, list[dict]]:
    """يفصل ترويسة العرض (JSON) عن الشرائح."""
    import json
    text = html.unescape(safen(path.read_text(encoding="utf-8")))
    meta: dict = {}
    if text.lstrip().startswith("---"):
        s = text.lstrip()
        end = s.find("\n---", 3)
        meta = json.loads(re.sub(r",(\s*[\]}])", r"\1", s[3:end]))
        text = s[end + 4:]

    slides: list[dict] = []
    current: dict | None = None
    buf: list[str] = []
    depth = 0  # عمق الكتل الداخلية المفتوحة داخل الشريحة
    for line in text.split("\n"):
        m = BLOCK_RE.match(line)
        if m and m.group("name").lower() == "slide":
            if current:
                current["body"] = buf
                slides.append(current)
            current = {"attrs": parse_attrs(m.group("attrs")), "body": []}
            buf = []
            depth = 0
            continue
        if current is None:
            continue
        if line.strip() == ":::":
            if depth == 0:
                continue            # هذا مُغلِّق كتلة الشريحة — لا نُمرّره
            depth -= 1
            buf.append(line)         # مُغلِّق كتلة داخلية — يلزم المُحلِّل
            continue
        if m:
            depth += 1
        buf.append(line)
    if current:
        current["body"] = buf
        slides.append(current)
    return meta, slides


# ---------------- أدوات الرسم ----------------
def add_blank(prs: Presentation):
    return prs.slides.add_slide(prs.slide_layouts[6])


def rect(slide, x, y, w, h, fill=None, line=None, line_w=Pt(1)):
    from pptx.enum.shapes import MSO_SHAPE
    sh = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, y, w, h)
    sh.adjustments[0] = 0.06
    if fill is None:
        sh.fill.background()
    else:
        sh.fill.solid(); sh.fill.fore_color.rgb = fill
    if line is None:
        sh.line.fill.background()
    else:
        sh.line.color.rgb = line; sh.line.width = line_w
    sh.shadow.inherit = False
    return sh


def plain_rect(slide, x, y, w, h, fill=None, line=None):
    from pptx.enum.shapes import MSO_SHAPE
    sh = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, x, y, w, h)
    if fill is None:
        sh.fill.background()
    else:
        sh.fill.solid(); sh.fill.fore_color.rgb = fill
    if line is None:
        sh.line.fill.background()
    else:
        sh.line.color.rgb = line
    sh.shadow.inherit = False
    return sh


def apply_font(run, font=AR_FONT):
    """يثبّت الخط على المقطع، مع نوع خط النص العربي (a:cs) لضمان ظهور العربية بخط واضح."""
    from pptx.oxml.ns import qn
    run.font.name = font
    rPr = run._r.get_or_add_rPr()
    cs = rPr.find(qn("a:cs"))
    if cs is None:
        cs = rPr.makeelement(qn("a:cs"), {}); rPr.append(cs)
    cs.set("typeface", font)


MD_RE = re.compile(r"(\*\*[^*]+\*\*|`[^`]+`)")


def add_md_runs(p, text, size, color, font=AR_FONT, base_bold=False, rtl=True):
    """يضيف مقاطع نص مع دعم **عريض** و`كود` داخل السطر."""
    for part in MD_RE.split(text):
        if not part:
            continue
        bold, f, t = base_bold, font, part
        if part.startswith("**") and part.endswith("**") and len(part) > 4:
            bold, t = True, part[2:-2]
        elif part.startswith("`") and part.endswith("`") and len(part) > 2:
            f, t = MONO_FONT, part[1:-1]
        r = p.add_run(); r.text = t
        r.font.size = Pt(size); r.font.bold = bold; r.font.color.rgb = color
        apply_font(r, f)


def textbox(slide, x, y, w, h, text, size=18, bold=False, color=BODY, align=PP_ALIGN.RIGHT,
            font=AR_FONT, rtl=True, line_spacing=1.25, anchor=MSO_ANCHOR.TOP):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = Cm(0.1)
    tf.margin_top = tf.margin_bottom = Cm(0.05)
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        p.line_spacing = line_spacing
        # اتجاه RTL على مستوى الفقرة
        pPr = p._pPr if p._pPr is not None else p._p.get_or_add_pPr()
        pPr.set("rtl", "1")
        add_md_runs(p, ln, size, color, font=font, base_bold=bold)
    return tb


def bullets(slide, x, y, w, h, items, size=17, color=BODY, marker="•", spacing=1.3):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame; tf.word_wrap = True
    tf.margin_left = tf.margin_right = Cm(0.1)
    for i, it in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = PP_ALIGN.RIGHT; p.line_spacing = spacing
        pPr = p._p.get_or_add_pPr(); pPr.set("rtl", "1")
        add_md_runs(p, f"{marker} {it}" if marker else it, size, color)
    return tb


def fit_image(slide, path: Path, x, y, max_w, max_h):
    from PIL import Image
    with Image.open(path) as im:
        ratio = im.width / im.height
    w = max_w; h = int(w / ratio)
    if h > max_h:
        h = max_h; w = int(h * ratio)
    return slide.shapes.add_picture(str(path), x + int((max_w - w) / 2), y, width=w, height=h)


def code_block(slide, x, y, w, lines, size=13, pad=Cm(0.5), title=None):
    line_h = Pt(size * 1.55)
    h = int(len(lines) * line_h + 2 * pad + (Pt(size * 1.5) if title else 0))
    box = rect(slide, x, y, w, h, fill=CODE_BG)
    cy = y + pad
    if title:
        textbox(slide, x + pad, cy, w - 2 * pad, Pt(size * 1.6), title, size=size * 0.85,
                color=RGBColor(0x8F, 0xA3, 0xC0), align=PP_ALIGN.LEFT, font=MONO_FONT, rtl=False)
        cy += Pt(size * 1.5)
    tb = slide.shapes.add_textbox(x + pad, cy, w - 2 * pad, h - 2 * pad)
    tf = tb.text_frame; tf.word_wrap = True
    for i, ln in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = PP_ALIGN.LEFT
        p.line_spacing = 1.15
        pPr = p._p.get_or_add_pPr(); pPr.set("rtl", "0")
        r = p.add_run(); r.text = ln
        r.font.size = Pt(size); r.font.name = MONO_FONT
        txt = ln.strip()
        if txt.startswith("$"):
            r.font.color.rgb = CODE_CMD
        elif txt.startswith(("#", "//")):
            r.font.color.rgb = RGBColor(0x7D, 0x8C, 0xA3)
        elif any(txt.startswith(k) for k in ("fatal:", "error:", "CONFLICT", "✘", "❌")):
            r.font.color.rgb = RGBColor(0xF0, 0x8C, 0x7A)
        else:
            r.font.color.rgb = CODE_TXT
    return box


def callout(slide, x, y, w, text, kind="info", size=15):
    colors = {"info": (RGBColor(0xEE, 0xF4, 0xFD), RGBColor(0x1C, 0x4B, 0x86)),
              "tip": (RGBColor(0xE6, 0xF5, 0xF5), RGBColor(0x0A, 0x5D, 0x5C)),
              "warn": (RGBColor(0xFF, 0xF8, 0xE8), RGBColor(0x8A, 0x5A, 0x06)),
              "err": (RGBColor(0xFD, 0xEC, 0xEA), RGBColor(0x8C, 0x1D, 0x17)),
              "ok": (RGBColor(0xE7, 0xF7, 0xF0), RGBColor(0x0B, 0x62, 0x44)),
              "rule": (RGBColor(0xF7, 0xF4, 0xFE), RGBColor(0x4B, 0x26, 0x83))}
    fill, txt = colors.get(kind, colors["info"])
    lines = text.split("\n")
    h = int(Pt(size * 1.6) * len(lines) + Cm(0.7))
    rect(slide, x, y, w, h, fill=fill, line=None)
    textbox(slide, x + Cm(0.35), y + Cm(0.3), w - Cm(0.7), h - Cm(0.5), text, size=size, color=txt)
    return h


# ---------------- قوالب الشرائح ----------------
def slide_title(prs, s, meta, idx, total):
    sl = add_blank(prs)
    plain_rect(sl, 0, 0, SLIDE_W, SLIDE_H, fill=NAVY)
    plain_rect(sl, 0, SLIDE_H - Cm(2.6), SLIDE_W, Cm(2.6), fill=ORANGE)
    textbox(sl, MARGIN, Cm(4.6), CONTENT_W, Cm(2.2), s["attrs"].get("kicker", meta.get("kicker", "")),
            size=15, color=RGBColor(0x9F, 0xC0, 0xE6), align=PP_ALIGN.CENTER)
    textbox(sl, MARGIN, Cm(6.6), CONTENT_W, Cm(4.2), s["attrs"].get("title", ""), size=40,
            bold=True, color=WHITE, align=PP_ALIGN.CENTER, line_spacing=1.15)
    textbox(sl, MARGIN, Cm(11.2), CONTENT_W, Cm(1.6), s["attrs"].get("subtitle", ""), size=18,
            color=RGBColor(0xD3, 0xE2, 0xF2), align=PP_ALIGN.CENTER, font=EN_FONT, rtl=False)
    if s["attrs"].get("meta"):
        textbox(sl, MARGIN, Cm(13.2), CONTENT_W, Cm(1.4), s["attrs"]["meta"], size=15,
                color=RGBColor(0xCB, 0xDC, 0xF0), align=PP_ALIGN.CENTER)
    textbox(sl, MARGIN, SLIDE_H - Cm(2.2), CONTENT_W, Cm(1.4), meta.get("footer", ""), size=13,
            color=WHITE, align=PP_ALIGN.CENTER)
    return sl


def _est_h(kind: str, payload) -> int:
    """تقدير ارتفاع العنصر بالسنتيمتر (بالمثلثات) لحجز مساحة كافية."""
    if kind == "text":
        return int(Pt(18 * 1.5) * (payload.count("\n") + 1) + Cm(0.35))
    if kind == "bullets":
        return int(Pt(17 * 1.7) * len(payload) + Cm(0.3))
    if kind == "code":
        lines, size = payload
        return int(len(lines) * Pt(size * 1.55) + Cm(1.0) + Cm(0.3))
    if kind == "callout":
        text, ck = payload
        return int(Pt(15 * 1.6) * len(text.split("\n")) + Cm(0.7) + Cm(0.3))
    if kind == "two":
        left, right = payload
        return int(Pt(16 * 1.7) * max(len(left), len(right)) + Cm(0.6) + Cm(0.3))
    if kind == "table":
        header, rows = payload
        return int((len(rows) + 1) * Pt(15 * 1.9) + Cm(0.2) + Cm(0.3))
    return 0


def slide_content(prs, s, meta, idx, total, body_lines):
    sl = add_blank(prs)
    # الشريط العلوي
    plain_rect(sl, 0, 0, SLIDE_W, Cm(2.3), fill=NAVY)
    textbox(sl, MARGIN, Cm(0.45), CONTENT_W - Cm(6), Cm(1.5), s["attrs"].get("title", ""), size=21,
            bold=True, color=WHITE)
    textbox(sl, MARGIN, Cm(0.6), CONTENT_W, Cm(1.2),
            f"{meta.get('deck', '')} · {idx}/{total}", size=11,
            color=RGBColor(0x9F, 0xC0, 0xE6), align=PP_ALIGN.LEFT, font=EN_FONT, rtl=False)

    y = Cm(3.0)
    full = False     # شريحة صورة ملأت المساحة
    # محتوى: فقرات نصية، قوائم، صناديق، أكواد، صور
    for pos, (kind, payload) in enumerate(body_lines):
        if kind == "text":
            tb = textbox(sl, MARGIN, y, CONTENT_W, Cm(1.2), payload, size=18, color=BODY)
            y += int(Pt(18 * 1.5) * (payload.count("\n") + 1) + Cm(0.35))
        elif kind == "bullets":
            h = int(Pt(17 * 1.7) * len(payload))
            bullets(sl, MARGIN, y, CONTENT_W, h, payload)
            y += h + Cm(0.3)
        elif kind == "code":
            lines, size = payload
            h = int(len(lines) * Pt(size * 1.55) + Cm(1.0))
            code_block(sl, MARGIN, y, CONTENT_W, lines, size=size)
            y += h + Cm(0.3)
        elif kind == "callout":
            text, ck = payload
            y += callout(sl, MARGIN, y, CONTENT_W, text, kind=ck) + Cm(0.3)
        elif kind == "image":
            path, h_ratio = payload
            reserve = sum(_est_h(k, p) for k, p in body_lines[pos + 1:])
            max_h = int(SLIDE_H - Cm(0.6) - y - reserve)
            if max_h < Cm(4):                      # مساحة ضيقة: الصورة وحدها في الشريحة
                max_h = int(SLIDE_H - Cm(0.6) - y)
                reserve = 0
            fit_image(sl, path, MARGIN, y, CONTENT_W, max_h)
            y += max_h + Cm(0.3)
            if reserve == 0:
                full = True
        elif kind == "two":
            left, right = payload
            col_w = int((CONTENT_W - Cm(0.6)) / 2)
            h = int(Pt(16 * 1.7) * max(len(left), len(right)) + Cm(0.6))
            rect(sl, MARGIN, y, col_w, h, fill=LIGHT)
            rect(sl, MARGIN + col_w + Cm(0.6), y, col_w, h, fill=LIGHT)
            bullets(sl, MARGIN + Cm(0.3), y + Cm(0.3), col_w - Cm(0.6), h, left, size=15)
            bullets(sl, MARGIN + col_w + Cm(0.9), y + Cm(0.3), col_w - Cm(0.6), h, right, size=15)
            y += h + Cm(0.3)
        elif kind == "table":
            header, rows = payload
            h = int((len(rows) + 1) * Pt(15 * 1.9) + Cm(0.2))
            h = min(h, int(SLIDE_H - y - Cm(1.4)))
            ncols = len(header)
            shape = sl.shapes.add_table(len(rows) + 1, ncols, MARGIN, y, CONTENT_W, h)
            tbl = shape.table
            for c, txt in enumerate(header):
                cell = tbl.cell(0, c); cell.text = txt
                cell.fill.solid(); cell.fill.fore_color.rgb = NAVY2
                for p in cell.text_frame.paragraphs:
                    p.alignment = PP_ALIGN.CENTER
                    for r in p.runs:
                        r.font.size = Pt(13); r.font.bold = True; r.font.color.rgb = WHITE
                        apply_font(r, AR_FONT)
            for ri, row in enumerate(rows, start=1):
                for ci, txt in enumerate(row):
                    cell = tbl.cell(ri, ci); cell.text = txt
                    cell.fill.solid()
                    cell.fill.fore_color.rgb = WHITE if ri % 2 else RGBColor(0xFA, 0xFC, 0xFE)
                    for p in cell.text_frame.paragraphs:
                        p.alignment = PP_ALIGN.RIGHT
                        for r in p.runs:
                            r.font.size = Pt(12.5); r.font.color.rgb = BODY
                            apply_font(r, AR_FONT)
            y += h + Cm(0.3)
    if y > SLIDE_H - Cm(0.2) and not full:
        print(f"  ⚠ تحذير تخطيط: الشريحة {idx} تتجاوز ارتفاع الشريحة "
              f"({round(y / Cm(1), 1)} سم من {round(SLIDE_H / Cm(1), 1)} سم)")
    return sl


# ---------------- تحويل نص الشريحة إلى عناصر ----------------
def build_body(slide_data: dict) -> list[tuple]:
    out: list[tuple] = []
    buf_text: list[str] = []
    buf_bullets: list[str] = []
    i = 0
    lines = slide_data["body"]
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        m = BLOCK_RE.match(line)
        if m:
            if buf_bullets:                      # أفرغ أي قائمة سابقة قبل الكتلة (حفظ الترتيب)
                out.append(("bullets", buf_bullets)); buf_bullets = []
            name = m.group("name").lower(); attrs = parse_attrs(m.group("attrs"))
            # اجمع حتى نهاية الكتلة
            inner = []
            i += 1
            while i < len(lines) and lines[i].strip() != ":::":
                inner.append(lines[i]); i += 1
            i += 1
            if name == "bullets":
                out.append(("bullets", [l.strip().lstrip("-•").strip() for l in inner if l.strip()]))
            elif name == "code":
                default_size = 13 if len(inner) <= 10 else 11
                out.append(("code", (inner, float(attrs.get("size", default_size)))))
            elif name == "callout":
                out.append(("callout", ("\n".join(x for x in inner if x.strip()), attrs.get("type", "info"))))
            elif name == "img":
                p = ASSETS / "img" / "png" / f"{attrs['name']}.png"
                src_svg = ASSETS / "img" / f"{attrs['name']}.svg"
                if not p.exists() and src_svg.exists():
                    p = src_svg
                out.append(("image", (p, attrs.get("h", "auto"))))
            elif name == "cols":
                mid = None
                try:
                    mid = inner.index("---")
                except ValueError:
                    mid = len(inner) // 2
                left = [l.strip().lstrip("-•").strip() for l in inner[:mid] if l.strip()]
                right = [l.strip().lstrip("-•").strip() for l in inner[mid + 1:] if l.strip()]
                out.append(("two", (left, right)))
            elif name == "table":
                rows = [r for r in inner if "|" in r]
                cells = [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows]
                cells = [c for c in cells if not all(set(x) <= set("-: ") for x in c)]
                if cells:
                    out.append(("table", (cells[0], cells[1:])))
            continue
        if line.strip().startswith(("- ", "• ")):
            buf_bullets.append(line.strip().lstrip("-•").strip())
            i += 1; continue
        if not line.strip():
            i += 1; continue
        # نص عادي
        if buf_bullets:
            out.append(("bullets", buf_bullets)); buf_bullets = []
        out.append(("text", safen(line.strip())))
        i += 1
    if buf_bullets:
        out.append(("bullets", buf_bullets))
    return out


def build_deck(path: Path) -> Path:
    meta, slides = parse_deck(path)
    prs = Presentation()
    prs.slide_width = SLIDE_W
    prs.slide_height = SLIDE_H
    total = len(slides)
    for idx, s in enumerate(slides, start=1):
        layout = s["attrs"].get("layout", "content")
        if layout == "title" or idx == 1:
            slide_title(prs, s, meta, idx, total)
        else:
            slide_content(prs, s, meta, idx, total, build_body(s))
    OUT.mkdir(exist_ok=True)
    dest = OUT / (path.stem + ".pptx")
    prs.save(str(dest))
    return dest


def main() -> None:
    args = sys.argv[1:]
    files = sorted(f for f in SRC.glob("*.md")
                   if f.name.lower() not in ("readme.md", "index.md"))
    if args:
        files = [f for f in files if any(a in f.name for a in args)]
    if not files:
        print("لا ملفات عروض.")
        return
    for f in files:
        d = build_deck(f)
        print(f"PPTX ✓ {d.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
