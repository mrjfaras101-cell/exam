#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
make_hub.py — صفحة فهرس الحزمة (index.html في جذر المستودع)
=============================================================
تُولَّد آلياً بالمسح الفعلي لمجلدات الحزمة، فلا تتقادم أبداً:
  • أوراق العمل ونماذج الحلول ودليل المدرّب        (PDF + HTML)
  • عروض الجلسات                                   (PPTX + HTML + PDF)
  • نسخ DOCX القابلة للتعديل
  • المستودع التدريبي وأدوات البناء

الاستخدام:
    python3 tools/make_hub.py                 # يكتب index.html في الجذر
    python3 tools/make_hub.py --serve         # يبنيه ثم يذكّر بأمر المعاينة

يفتح الرابط محلياً عبر: python3 tools/serve_slides.py  (ثم /index.html)
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

CSS = """
@font-face{font-family:CairoAr;src:url("assets/fonts/cairo-arabic-400-normal.woff2") format("woff2");font-weight:400}
@font-face{font-family:CairoAr;src:url("assets/fonts/cairo-arabic-700-normal.woff2") format("woff2");font-weight:700}
@font-face{font-family:CairoLat;src:url("assets/fonts/cairo-latin-400-normal.woff2") format("woff2");font-weight:400}
@font-face{font-family:CairoLat;src:url("assets/fonts/cairo-latin-700-normal.woff2") format("woff2");font-weight:700}
:root{--navy:#12203c;--navy2:#1e3a5f;--orange:#e8620c;--teal:#0e7c7b;--green:#128a5b;
 --ink:#12161c;--body:#22303f;--muted:#6b7684;--line:#d6dde6;--soft:#f4f7fa}
*{box-sizing:border-box}
body{margin:0;background:#0b1220;color:var(--body);direction:rtl;
 font-family:CairoAr,CairoLat,"Segoe UI",system-ui,sans-serif}
.wrap{max-width:1180px;margin:0 auto;padding:0 18px 70px}
header{background:var(--navy);border-bottom:9px solid var(--orange);padding:34px 0 30px;margin-bottom:26px}
header .inner{max-width:1180px;margin:0 auto;padding:0 18px}
h1{margin:0 0 8px;color:#fff;font-size:32px}
header p{margin:0;color:#bcd3ee;font-size:15.5px;line-height:1.7}
header .en{color:#93b2d6;font-size:13.5px;direction:ltr;font-family:CairoLat,system-ui,sans-serif;margin-top:6px}
.badges{display:flex;flex-wrap:wrap;gap:8px;margin-top:16px}
.badge{background:#1b2c4b;border:1px solid #2c4468;color:#cfe0f4;
 border-radius:999px;padding:5px 13px;font-size:13px}
h2{color:#fff;font-size:21px;margin:34px 0 6px;display:flex;align-items:center;gap:10px}
h2 .n{background:var(--orange);color:#fff;border-radius:8px;font-size:13px;
 padding:2px 9px;font-family:CairoLat,sans-serif;direction:ltr}
h2 .en{color:#8fa8c7;font-size:13px;font-weight:400;direction:ltr;font-family:CairoLat,sans-serif}
.hint{color:#9fb6d4;font-size:13.5px;margin:0 0 14px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:14px}
.card{background:#152340;border:1px solid #27364f;border-radius:13px;padding:15px 17px;transition:.15s}
.card:hover{border-color:var(--orange);transform:translateY(-2px)}
.card h3{margin:0 0 4px;color:#fff;font-size:17.5px;font-weight:700}
.card .sub{color:#9fb6d4;font-size:13px;margin:0 0 10px;line-height:1.6}
.card .meta{color:#7f96b5;font-size:12px;font-family:CairoLat,sans-serif;direction:ltr;margin:0 0 10px}
.links{display:flex;flex-wrap:wrap;gap:7px}
.links a{text-decoration:none;font-size:13px;border-radius:8px;padding:5px 11px;
 background:var(--navy2);color:#dce9f8;border:1px solid #2c4468}
.links a:hover{background:#2b5486;border-color:#3f6ea8}
.links a.pdf{background:#3a1f18;border-color:#5e3226;color:#ffd9c9}
.links a.pdf:hover{background:#5a2f22;border-color:#84452f}
.links a.doc{background:#152c26;border-color:#26513f;color:#c9ecd9}
.links a.doc:hover{background:#1d4034;border-color:#2f6b52}
.links a.priv{background:#2c1a38;border-color:#4a2b5c;color:#e6d3f5}
.links a.priv:hover{background:#3d2450;border-color:#653a7c}
.note{margin-top:34px;background:#152340;border:1px solid #27364f;border-inline-start:4px solid var(--teal);
 border-radius:10px;padding:14px 18px;color:#c5d6ea;font-size:14px;line-height:1.85}
.note b{color:#fff}
code{font-family:"JetBrains Mono",Consolas,monospace;background:#0f172a;border:1px solid #27364f;
 color:#bfe3cf;border-radius:6px;padding:1px 7px;direction:ltr;unicode-bidi:embed;font-size:.9em}
footer{color:#7f96b5;text-align:center;font-size:12.5px;margin-top:40px;line-height:1.9}
footer .en{direction:ltr;font-family:CairoLat,sans-serif}
"""


def titles_from_source(path: Path) -> tuple[str, str, int]:
    """عنوان الورقة عربي/إنجليزي + عدد المهام (من الترويسة أو العنوان الأول)."""
    text = path.read_text(encoding="utf-8")
    m = re.search(r'"title"\s*:\s*"([^"]+)"', text)
    en = re.search(r'"en_title"\s*:\s*"([^"]+)"', text)
    tasks = len(re.findall(r":::task\{", text))
    if not m:
        h = re.search(r"^#\s+(.+)$", text, re.M)
        m = h if h else None
    return (m.group(1) if m else path.stem), (en.group(1) if en else ""), tasks


def cards(folder_html: Path, folder_pdf: Path, pattern: str) -> list[str]:
    out = []
    for src in sorted((ROOT / "source").glob(pattern)):
        title, en, n = titles_from_source(src)
        h = folder_html / (src.stem + ".html")
        p = folder_pdf / (src.stem + ".pdf")
        links = []
        if p.exists():
            links.append(f'<a class="pdf" href="{p.relative_to(ROOT)}">PDF</a>')
        if h.exists():
            links.append(f'<a href="{h.relative_to(ROOT)}">HTML</a>')
        d = ROOT / "docx" / (src.stem + ".docx")
        if d.exists():
            links.append(f'<a class="doc" href="{d.relative_to(ROOT)}">DOCX</a>')
        sub = f'<p class="sub">{html.escape(title)}</p>'
        meta = f'<p class="meta">{html.escape(en)}</p>' if en else ""
        if not en:
            sub = f'<p class="sub">{html.escape(title)}</p>'
        n_txt = f"{n} مهام" if n else ""
        out.append(
            f'<div class="card">{sub}{meta}'
            f'<div class="meta">{folder_pdf.relative_to(ROOT)} · {n_txt}</div>'
            f'<div class="links">{"".join(links)}</div></div>')
    return out


def deck_cards() -> list[str]:
    out = []
    meta_re = re.compile(r'"deck"\s*:\s*"([^"]+)"')
    for src in sorted((ROOT / "source" / "slides").glob("s*.md")):
        m = meta_re.search(src.read_text(encoding="utf-8"))
        deck = m.group(1) if m else src.stem
        pptx = ROOT / "slides" / (src.stem + ".pptx")
        htm = ROOT / "slides" / "html" / (src.stem + ".html")
        pdf = ROOT / "slides" / "pdf" / (src.stem + ".pdf")
        pages = ""
        try:
            import pypdfium2 as pdfium  # optional
            if pdf.exists():
                pages = f" · {len(pdfium.PdfDocument(str(pdf)))} شرائح"
        except Exception:  # noqa: BLE001
            pass
        links = []
        if pptx.exists():
            links.append(f'<a class="doc" href="{pptx.relative_to(ROOT)}">PPTX</a>')
        if htm.exists():
            links.append(f'<a href="{htm.relative_to(ROOT)}">عرض في المتصفح</a>')
        if pdf.exists():
            links.append(f'<a class="pdf" href="{pdf.relative_to(ROOT)}">PDF</a>')
        out.append(
            f'<div class="card"><p class="sub">{html.escape(deck)}</p>'
            f'<p class="meta">{src.name}{pages}</p>'
            f'<div class="links">{"".join(links)}</div></div>')
    return out


def build() -> Path:
    ws = cards(ROOT / "worksheets", ROOT / "worksheets", "ws*.md")
    sol = cards(ROOT / "solutions", ROOT / "solutions", "solutions-ws*.md")
    decks = deck_cards()

    trainer = ROOT / "source" / "trainer-guide.md"
    t_title = "دليل المدرّب الشامل"
    trainer_card = (
        f'<div class="card"><p class="sub">{t_title} — تخطيط الجلسات، إدارة الصف، أخطاء شائعة، سكربتات إنقاذ، ولوحة متابعة</p>'
        '<p class="meta">trainer-guide · للمدرّب فقط</p><div class="links">'
        '<a class="priv" href="trainer/trainer-guide.pdf">PDF</a>'
        '<a class="priv" href="trainer/trainer-guide.html">HTML</a>'
        '<a class="doc" href="docx/trainer-guide.docx">DOCX</a></div></div>')

    prog = ROOT / "worksheets" / "program-overview.pdf"
    prog_card = (
        '<div class="card"><p class="sub">دليل البرنامج والمشروع — ماذا نبني، وأدوار الطلبة، ومعايير التقييم الكلية</p>'
        '<p class="meta">program-overview · اقرأه أولاً</p><div class="links">'
        f'<a class="pdf" href="{prog.relative_to(ROOT)}">PDF</a>'
        '<a href="worksheets/program-overview.html">HTML</a>'
        '<a class="doc" href="docx/program-overview.docx">DOCX</a></div></div>')

    project_card = (
        '<div class="card"><p class="sub">المستودع التدريبي <b>class-team-hub</b> — موقع بطاقات الفريق + الأتمتة (Actions · CODEOWNERS · CHANGELOG)</p>'
        '<p class="meta">project/ · هو ما ينسخه الطلبة ويعدّلونه</p><div class="links">'
        '<a href="project/README.md">README</a>'
        '<a href="project/docs/ci.md">docs/ci</a>'
        '<a href="project/.github/workflows/validate.yml">workflow</a></div></div>')

    docx_only = [f for f in sorted((ROOT / "docx").glob("*.docx"))]
    docx_card = (
        f'<div class="card"><p class="sub">كل المستندات بصيغة DOCX قابلة للتعديل ({len(docx_only)} ملفاً)</p>'
        '<p class="meta">docx/</p><div class="links">'
        '<a class="doc" href="docx/ws1-setup.docx">ورقة 01</a>'
        '<a class="doc" href="docx/ws6-automation.docx">ورقة 06</a>'
        '<a class="doc" href="docx/solutions-ws6.docx">حلول 06</a></div></div>')

    tools_card = (
        '<div class="card"><p class="sub">أدوات التوليد والفحص: الأوراق (PDF/DOCX) · العروض (PPTX/HTML/PDF) · فاحص جودة العروض</p>'
        '<p class="meta">tools/ · Python + Node</p><div class="links">'
        '<a href="source/">المصادر</a><a href="tools/build.py">build.py</a>'
        '<a href="source/slides/README.md">دليل صيغة العروض</a></div></div>')

    page = f"""<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>حزمة ورشة Git وGitHub — فهرس الحزمة</title>
<style>{CSS}</style>
</head>
<body>
<header><div class="inner">
<h1>حزمة ورشة Git وGitHub — فهرس الحزمة</h1>
<p>كل مخرجات البرنامج التدريبي في صفحة واحدة: ستّة أوراق عمل، نماذج حلول للمدرّب، دليل مدرّب،
عروض الجلسات بثلاث صيغ، والمستودع التدريبي — بالعربية والإنجليزية.</p>
<p class="en">Git &amp; GitHub Workshop Package — worksheets · solution keys · trainer guide · session decks · classroom repo</p>
<div class="badges">
<span class="badge">6 أوراق عمل</span>
<span class="badge">6 نماذج حلول</span>
<span class="badge">6 عروض جلسات (80 شريحة)</span>
<span class="badge">PDF · DOCX · HTML · PPTX</span>
<span class="badge">600 نقطة تقييم</span>
</div>
</div></header>

<div class="wrap">
<h2><span class="n">00</span> ابدأ من هنا <span class="en">start here</span></h2>
<p class="hint">اقرأ دليل البرنامج أولاً، ثم دليل المدرّب قبل اليوم الأول.</p>
<div class="grid">{prog_card}{trainer_card}</div>

<h2><span class="n">01–06</span> أوراق العمل <span class="en">worksheets — تُطبع للطلبة</span></h2>
<p class="hint">تدرّج: التعريف → الاستنساخ → الفرع وطلب السحب → المزامنة والدمج → التعارضات والنشر → الأتمتة (اختيارية).</p>
<div class="grid">{"".join(ws)}</div>

<h2><span class="n">★</span> نماذج الحلول والتقييم <span class="en">solution keys — للمدرّب فقط</span></h2>
<p class="hint">مخرجات نموذجية لكل مهمة + قواعد المنح والخصم + جداول الأخطاء المتوقعة + درجة كل ورقة.</p>
<div class="grid">{"".join(sol)}</div>

<h2><span class="n">▶</span> عروض الجلسات <span class="en">session decks</span></h2>
<p class="hint">PPTX للتعديل (مع ملاحظات محاضر في Presenter View) · HTML للعرض من المتصفح (أسهم ← → وزر طباعة) · PDF للعرض المباشر.</p>
<div class="grid">{"".join(decks)}</div>

<h2><span class="n">⚙</span> المشروع والأدوات <span class="en">project &amp; tooling</span></h2>
<div class="grid">{project_card}{docx_card}{tools_card}</div>

<div class="note">
<b>للمدرّب:</b> كل شيء هنا يُبنى من المصادر في <code>source/</code> بأمر واحد —
<code>python3 tools/build.py</code> للمستندات، و<code>python3 tools/build_slides.py</code> للعروض،
و<code>python3 tools/build_slides_html.py --pdf</code> لنسختي المتصفح وPDF.
عدّل النصوص ثم أعد البناء، ولا تعدّل المخرجات مباشرة.
</div>
<footer>
حزمة ورشة Git وGitHub — البرنامج التدريبي العملي<br>
<span class="en">Built from source · PDF · DOCX · HTML · PPTX</span>
</footer>
</div>
</body>
</html>
"""
    dest = ROOT / "index.html"
    dest.write_text(page, encoding="utf-8")
    return dest


def main() -> None:
    dest = build()
    print(f"HTML ✓ {dest.relative_to(ROOT)} — فهرس الحزمة")
    print("   للمعاينة: python3 tools/serve_slides.py  ثم افتح /index.html")


if __name__ == "__main__":
    main()
