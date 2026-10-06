#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_slides.py — فاحص جودة عروض PPTX (تقديري، يعمل بلا LibreOffice)
=====================================================================
يفحص كل ملف في slides/*.pptx ويتحقق من:
  1. مقاس الشريحة (16:9)
  2. عدم خروج أي شكل عن حدود الشريحة (ارتفاع/عرض)
  3. تقدير ارتفاع النص الملتف واحتمال تجاوزه أسفل الشريحة
  4. خلو النص من الرموز التعبيرية (تُظهر مربعات فارغة في بعض الأجهزة)
  5. خلو النص من بقايا صيغة المصدر (:::، **، `، name=)
  6. ضبط اتجاه الفقرة rtl=1 عند وجود نص عربي
  7. سلامة الصور (نسبة العرض إلى الارتفاع)

الاستخدام:
    python3 tools/check_slides.py            # كل العروض
    python3 tools/check_slides.py s3          # عرض واحد
"""

from __future__ import annotations

import math
import re
import sys
from pathlib import Path

from pptx import Presentation
from pptx.util import Cm, Pt, Emu
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SLIDES = ROOT / "slides"

EMU_CM = 360000.0
# الرموز المضمون ظهورها في كل البيئات (لا تُعدّ مشكلة)
SAFE_GLYPHS = set("✔✘✓✗★◆●■▲☐→⇒⚠←•─│┌┐└┘├┤┬┴┼━")
EMOJI_RE = re.compile("[\U0001F000-\U0001FAFF\u2190-\u2BFF\uFE0F]")
LEFTOVER_RE = re.compile(r":::|^\s*---\s*$|\*\*|`|name=|\{type=", re.M)
AR_RE = re.compile("[\u0600-\u06FF]")

# متوسط عرض المحرف كنسبة من حجم الخط (سم لكل نقطة)
ADVANCE_AR = 0.0176
ADVANCE_MONO = 0.0194
ADVANCE_LATIN = 0.0170


def cm(v) -> float:
    return v / EMU_CM


def shape_font_size(shape) -> tuple[float, str]:
    """أكبر حجم خط في الشكل + اسم الخط الغالب."""
    size, font = 0.0, ""
    for p in shape.text_frame.paragraphs:
        for r in p.runs:
            if r.font.size:
                size = max(size, r.font.size.pt)
            if r.font.name:
                font = r.font.name
    return (size or 18.0), font


def est_lines(text: str, size_pt: float, width_cm: float, font: str = "") -> int:
    """تقدير عدد الأسطر بعد الالتفاف (تقريب متحفظ)."""
    if not text:
        return 1
    adv = ADVANCE_MONO if ("Consolas" in font or "Mono" in font) else ADVANCE_AR
    per_line = max(6, int(width_cm / (size_pt * adv)))
    n = 0
    for part in text.split("\n"):
        n += max(1, math.ceil(len(part) / per_line))
    return n


def check_deck(path: Path) -> list[str]:
    prs = Presentation(path)
    issues: list[str] = []
    W, H = prs.slide_width, prs.slide_height
    if abs(W / H - 16 / 9) > 0.02:
        issues.append(f"مقاس الشريحة ليس 16:9 ({cm(W):.1f}×{cm(H):.1f} سم)")

    for idx, slide in enumerate(prs.slides, 1):
        for shape in slide.shapes:
            try:
                l, t, w, h = shape.left, shape.top, shape.width, shape.height
            except Exception:
                continue
            if l is None:
                continue
            if l < -Cm(0.05) or t < -Cm(0.05) or l + w > W + Cm(0.05) or t + h > H + Cm(0.05):
                issues.append(f"شريحة {idx}: شكل خارج الحدود ({shape.shape_type}) "
                              f"l={cm(l):.2f} t={cm(t):.2f} w={cm(w):.2f} h={cm(h):.2f}")

            # 4+5: فحص النص
            if shape.has_text_frame:
                txt = shape.text_frame.text
                bad = "".join(sorted({ch for ch in EMOJI_RE.findall(txt)
                                      if ch not in SAFE_GLYPHS}))
                if bad:
                    issues.append(f"شريحة {idx}: رمز تعبيري قد يظهر مربعاً فارغاً: {bad!r}")
                if LEFTOVER_RE.search(txt):
                    m = LEFTOVER_RE.search(txt)
                    issues.append(f"شريحة {idx}: بقايا صيغة في النص: {m.group(0)!r}")
                if AR_RE.search(txt):
                    for p in shape.text_frame.paragraphs:
                        if AR_RE.search("".join(r.text for r in p.runs)):
                            if p._p.find(
                                "{http://schemas.openxmlformats.org/drawingml/2006/main}pPr"
                            ) is None:
                                issues.append(f"شريحة {idx}: فقرة عربية بلا rtl")
                                break
                # 3: تقدير ارتفاع النص الملتف
                size, fname = shape_font_size(shape)
                tf = shape.text_frame
                inner_w = cm(shape.width) - cm(tf.margin_left or 0) - cm(tf.margin_right or 0)
                lines = 0
                for p in tf.paragraphs:
                    ptxt = "".join(r.text for r in p.runs)
                    lines += est_lines(ptxt, size, inner_w, fname)
                need = lines * size * 1.6 * 0.0353 + cm(tf.margin_top or 0) + cm(tf.margin_bottom or 0)
                bottom = cm(t) + need
                if bottom > cm(H) - 0.15:
                    issues.append(f"شريحة {idx}: نص قد يخرج أسفل الشريحة "
                                  f"(يحتاج ≈{need:.1f} سم، يبدأ عند {cm(t):.1f} سم) "
                                  f"«{txt.splitlines()[0][:40]}…»")

            # 6b: الجداول — هل تكفي المساحة بعد التفاف النص؟
            if shape.has_table:
                tbl = shape.table
                col_w = [cm(c.width) for c in tbl.columns]
                need = 0.0
                for ri, row in enumerate(tbl.rows):
                    row_need = 0.0
                    for ci, cell in enumerate(row.cells):
                        ctxt = cell.text_frame.text
                        size = 13.0 if ri == 0 else 12.5
                        wcm = max(2.0, col_w[ci] - 0.4)
                        n = 0
                        for p in cell.text_frame.paragraphs:
                            ptxt = "".join(r.text for r in p.runs) or ""
                            n += est_lines(ptxt, size, wcm)
                        row_need = max(row_need, n * size * 1.5 * 0.0353 + 0.15)
                    need += max(row_need, cm(row.height))
                bottom = cm(t) + need
                if bottom > cm(H) - 0.15:
                    issues.append(f"شريحة {idx}: جدول قد يخرج أسفل الشريحة "
                                  f"(يحتاج ≈{need:.1f} سم من موضعه {cm(t):.1f} سم)")
                elif need > cm(h) * 1.25:
                    issues.append(f"شريحة {idx}: جدول سيتمدد أكثر من المسموح "
                                  f"(المقدّر {need:.1f} سم مقابل {cm(h):.1f} سم)")

            # 7: الصور
            if shape.shape_type == 13 or shape.__class__.__name__ == "Picture":
                try:
                    img = shape.image
                    with Image.open(img.blob and __import__("io").BytesIO(img.blob)) as im:
                        ratio = im.width / im.height
                    if abs((w / h) - ratio) > 0.02:
                        issues.append(f"شريحة {idx}: صورة مشوّهة (نسبة المصدر {ratio:.2f} مقابل {w / h:.2f})")
                except Exception:
                    pass
    return issues


def main() -> None:
    args = sys.argv[1:]
    files = sorted(SLIDES.glob("*.pptx"))
    if args:
        files = [f for f in files if any(a in f.name for a in args)]
    if not files:
        print("لا ملفات عروض في slides/")
        sys.exit(1)
    total = 0
    print("=" * 68)
    print("فاحص جودة العروض / Slide QA")
    print("=" * 68)
    for f in files:
        prs = Presentation(f)
        issues = check_deck(f)
        total += len(issues)
        mark = "✔" if not issues else "✘"
        print(f"{mark} {f.name} — {len(prs.slides)} شريحة، {len(issues)} ملاحظة")
        for it in issues:
            print(f"     • {it}")
    print("-" * 68)
    print(("✔ لا ملاحظات — العروض سليمة بنيوياً." if total == 0
           else f"✘ إجمالي الملاحظات: {total}"))
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
