#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_slides_html.py — نسخة HTML من عروض الجلسات (للعرض في المتصفح أو الطباعة)
=================================================================================
تقرأ نفس مصادر العروض `source/slides/*.md` وتُخرج صفحات مستقلة في `slides/html/`:
  • عرض في المتصفح بملء الشاشة (أسهم ← → أو التمرير أو أزرار التنقل)
  • طباعة/تصدير PDF: شريحة واحدة في كل صفحة بمقاس 16:9
  • لا تحتاج إنترنت: خطوط `assets/fonts/*.woff2` محلية

الاستخدام:
    python3 tools/build_slides_html.py            # كل العروض + صفحة فهرس
    python3 tools/build_slides_html.py s3         # عرض واحد

المولّد يعيد استعمال محلّل المصدر من tools/build_slides.py (مصدر حقيقة واحد للصيغة).
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

import build_slides as bs

ROOT = bs.ROOT
SRC = bs.SRC
OUT = ROOT / "slides" / "html"

CSS = """
@font-face{font-family:CairoAr;src:url("../../assets/fonts/cairo-arabic-400-normal.woff2") format("woff2");font-weight:400;font-display:swap}
@font-face{font-family:CairoAr;src:url("../../assets/fonts/cairo-arabic-700-normal.woff2") format("woff2");font-weight:700;font-display:swap}
@font-face{font-family:CairoLat;src:url("../../assets/fonts/cairo-latin-400-normal.woff2") format("woff2");font-weight:400;font-display:swap}
@font-face{font-family:CairoLat;src:url("../../assets/fonts/cairo-latin-700-normal.woff2") format("woff2");font-weight:700;font-display:swap}
@font-face{font-family:JBMono;src:url("../../assets/fonts/jetbrains-mono-latin-400-normal.woff2") format("woff2")}
:root{--navy:#12203c;--navy2:#1e3a5f;--orange:#e8620c;--teal:#0e7c7b;--green:#128a5b;
 --red:#b3261e;--violet:#6d3bb5;--ink:#12161c;--body:#22303f;--muted:#6b7684;--light:#f4f7fa;--line:#d6dde6}
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:#0b1220;color:var(--ink);
 font-family:CairoAr,CairoLat,"Segoe UI",system-ui,sans-serif}
.deck{display:flex;flex-direction:column;align-items:center;gap:26px;padding:26px 10px 90px}
.slide{width:1280px;height:720px;background:#fff;border-radius:10px;overflow:hidden;
 box-shadow:0 18px 44px rgba(0,0,0,.45);position:relative;flex:0 0 auto;
 transform-origin:top center}
.slide>*{position:relative;z-index:1}
.thead{height:88px;background:var(--navy);display:flex;align-items:center;justify-content:space-between;
 padding:0 42px;gap:20px}
.thead h1{margin:0;color:#fff;font-size:27px;font-weight:700}
.thead .idx{color:#9fc0e6;font-size:12.5px;font-family:JBMono,monospace;direction:ltr;white-space:nowrap}
.body{padding:24px 42px;display:flex;flex-direction:column;gap:14px;height:632px;overflow:hidden}
.body p{margin:0;font-size:19px;line-height:1.65;color:var(--body)}
.body ul{margin:0;padding:0 22px 0 0;list-style:none}
.body ul li{position:relative;font-size:18px;line-height:1.75;color:var(--body);padding-right:22px}
.body ul li:before{content:"•";position:absolute;right:0;color:var(--orange);font-weight:700}
.code{background:#0f172a;border-radius:9px;padding:14px 18px;margin:0;direction:ltr;text-align:left;
 font-family:JBMono,Consolas,monospace;font-size:14.5px;line-height:1.62;color:#e6edf7;overflow:hidden;white-space:pre-wrap}
.code .cmd{color:#7fd1a8}.code .cm{color:#7d8ca3}.code .err{color:#f08c7a}
.callout{border-radius:9px;padding:13px 18px;font-size:16.5px;line-height:1.6}
.callout p{margin:0 0 4px;font-size:16.5px}
.callout p:last-child{margin-bottom:0}
.callout.info{background:#eef4fd;color:#1c4b86}.callout.tip{background:#e6f5f5;color:#0a5d5c}
.callout.warn{background:#fff8e8;color:#8a5a06}.callout.err{background:#fdecea;color:#8c1d17}
.callout.ok{background:#e7f7f0;color:#0b6244}.callout.rule{background:#f7f4fe;color:#4b2683}
figure{margin:0;display:flex;justify-content:center}
figure img{max-width:100%;max-height:430px}
.cols{display:grid;grid-template-columns:1fr 1fr;gap:18px}
.cols ul{background:var(--light);border-radius:9px;padding:14px 20px 14px 14px}
table{width:100%;border-collapse:collapse;font-size:15px}
th{background:var(--navy2);color:#fff;padding:9px 10px;font-size:15px}
td{padding:8px 10px;border-bottom:1px solid var(--line);color:var(--body);vertical-align:top}
tbody tr:nth-child(even){background:#fafcfe}
b{font-weight:700}
code{font-family:JBMono,Consolas,monospace;font-size:.92em;background:#eef2f7;border-radius:4px;padding:0 4px;direction:ltr;unicode-bidi:embed}
/* شريحة العنوان */
.slide.title{background:var(--navy);display:flex;flex-direction:column;align-items:center;justify-content:center;
 text-align:center;padding:0 70px;color:#fff;border-bottom:26px solid var(--orange)}
.slide.title .kick{color:#9fc0e6;font-size:17px;margin-bottom:22px}
.slide.title h1{font-size:52px;margin:0 0 18px;line-height:1.25}
.slide.title .sub{color:#d3e2f2;font-size:22px;direction:ltr;font-family:JBMono,monospace}
.slide.title .foot{position:absolute;bottom:34px;color:#cbdff0;font-size:14px}
nav{position:fixed;bottom:18px;left:50%;transform:translateX(-50%);background:rgba(11,18,32,.86);
 border:1px solid #26364f;border-radius:999px;padding:8px 14px;display:flex;gap:10px;align-items:center;z-index:9}
nav button{background:#1e3a5f;color:#fff;border:0;border-radius:999px;padding:8px 16px;font:inherit;font-size:14px;cursor:pointer}
nav button:hover{background:#2b5486}
nav .pos{color:#9fc0e6;font-size:13px;font-family:JBMono,monospace}
html:fullscreen nav{opacity:.15}html:fullscreen nav:hover{opacity:1}
.idx-page{max-width:1040px;margin:0 auto;padding:40px 22px 80px;color:#e8eef7;font-family:CairoLat,CairoAr,system-ui,sans-serif;direction:rtl}
.idx-page h1{color:#fff;font-size:30px;margin:0 0 6px}
.idx-page p.sub{color:#9fb6d4;margin:0 0 26px}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:16px}
.card{background:#152340;border:1px solid #26364f;border-radius:13px;padding:18px 20px;text-decoration:none;color:#e8eef7;display:block}
.card:hover{border-color:var(--orange);transform:translateY(-2px)}
.card b{display:block;font-size:19px;margin-bottom:8px}
.card span{color:#9fb6d4;font-size:13.5px;font-family:JBMono,monospace;direction:ltr}
@media print{
 @page{size:338mm 190mm;margin:0}
 html,body{background:#fff}
 .deck{gap:0;padding:0}
 .slide{box-shadow:none;border-radius:0;transform:none!important;page-break-after:always;width:338mm;height:190mm}
 nav{display:none}
 .thead{height:24mm}.body{height:calc(190mm - 24mm);padding:7mm 11mm}
 .body p,.body ul li{font-size:15pt}.code{font-size:11.5pt}
}
"""

JS = """
const slides=[...document.querySelectorAll('.slide')];
let cur=0;
function fit(){const s=Math.min(1,(window.innerWidth-40)/1280,(window.innerHeight-70)/720);
 document.querySelectorAll('.slide').forEach(el=>el.style.transform='scale('+s+')');}
function go(n){cur=Math.max(0,Math.min(slides.length-1,n));
 slides[cur].scrollIntoView({behavior:'smooth',block:'center'});show();}
function show(){const p=document.querySelector('nav .pos');
 if(p)p.textContent=(cur+1)+' / '+slides.length;
 slides.forEach((el,i)=>el.style.outline=i===cur?'3px solid #e8620c':'none');}
addEventListener('keydown',e=>{
 if(['ArrowLeft','ArrowRight','ArrowUp','ArrowDown',' ','PageUp','PageDown'].includes(e.key))e.preventDefault();
 if(e.key==='ArrowRight'||e.key==='ArrowDown'||e.key===' '||e.key==='PageDown')go(cur+1);
 else if(e.key==='ArrowLeft'||e.key==='ArrowUp'||e.key==='PageUp')go(cur-1);
 else if(e.key==='Home')go(0); else if(e.key==='End')go(slides.length-1);
 else if(e.key==='f'||e.key==='F'){document.fullscreenElement?document.exitFullscreen():document.documentElement.requestFullscreen();}});
addEventListener('resize',fit);
addEventListener('scroll',()=>{const mid=innerHeight/2;let best=0,bd=1e9;
 slides.forEach((el,i)=>{const r=el.getBoundingClientRect();const d=Math.abs(r.top+r.height/2-mid);if(d<bd){bd=d;best=i;}});
 if(best!==cur){cur=best;show();}},{passive:true});
fit();show();
"""


def inline(t: str) -> str:
    """تهريب HTML ثم تحويل **عريض** و`كود`."""
    t = html.escape(t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    return t


def code_html(lines: list[str]) -> str:
    out = []
    for ln in lines:
        e = html.escape(ln) or "&nbsp;"
        s = ln.strip()
        if s.startswith("$"):
            out.append(f'<span class="cmd">{e}</span>')
        elif s.startswith(("#", "//")):
            out.append(f'<span class="cm">{e}</span>')
        elif any(s.startswith(k) for k in ("fatal:", "error:", "CONFLICT", "✘", "❌")):
            out.append(f'<span class="err">{e}</span>')
        else:
            out.append(e)
    return '<pre class="code">' + "\n".join(out) + "</pre>"


def render_body(body: list[tuple]) -> str:
    parts = []
    for kind, payload in body:
        if kind == "text":
            parts.append(f"<p>{inline(payload)}</p>")
        elif kind == "bullets":
            items = "".join(f"<li>{inline(i)}</li>" for i in payload)
            parts.append(f"<ul>{items}</ul>")
        elif kind == "code":
            parts.append(code_html(payload[0]))
        elif kind == "callout":
            text, ck = payload
            ps = "".join(f"<p>{inline(x)}</p>" for x in text.split("\n") if x.strip())
            parts.append(f'<div class="callout {ck}">{ps}</div>')
        elif kind == "image":
            path = Path(payload[0])
            rel = f"../../assets/img/png/{path.stem}.png"
            parts.append(f'<figure><img src="{rel}" alt="{html.escape(path.stem)}"></figure>')
        elif kind == "two":
            left, right = payload
            l = "".join(f"<li>{inline(i)}</li>" for i in left)
            r = "".join(f"<li>{inline(i)}</li>" for i in right)
            parts.append(f'<div class="cols"><ul>{l}</ul><ul>{r}</ul></div>')
        elif kind == "table":
            header, rows = payload
            th = "".join(f"<th>{inline(c)}</th>" for c in header)
            trs = "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in rows)
            parts.append(f"<table><thead><tr>{th}</tr></thead><tbody>{trs}</tbody></table>")
    return "\n".join(parts)


def build(path: Path) -> tuple[Path, int]:
    meta, slides = bs.parse_deck(path)
    deck = meta.get("deck", path.stem)
    out = []
    for i, s in enumerate(slides, start=1):
        if s["attrs"].get("layout") == "title" or i == 1:
            out.append(
                '<section class="slide title">'
                f'<div class="kick">{inline(s["attrs"].get("kicker", meta.get("kicker", "")))}</div>'
                f'<h1>{inline(s["attrs"].get("title", ""))}</h1>'
                f'<div class="sub">{html.escape(s["attrs"].get("subtitle", ""))}</div>'
                f'<div class="foot">{inline(meta.get("footer", ""))}</div>'
                "</section>")
        else:
            body = render_body(bs.build_body(s))
            out.append(
                '<section class="slide">'
                f'<div class="thead"><h1>{inline(s["attrs"].get("title", ""))}</h1>'
                f'<span class="idx">{html.escape(deck)} · {i}/{len(slides)}</span></div>'
                f'<div class="body">{body}</div></section>')

    page = f"""<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(deck)}</title>
<style>{CSS}</style>
</head>
<body>
<div class="deck">
{chr(10).join(out)}
</div>
<nav>
<button onclick="go(cur-1)">السابق ‹</button>
<span class="pos">1 / {len(slides)}</span>
<button onclick="go(cur+1)">› التالي</button>
<button onclick="document.documentElement.requestFullscreen()">ملء الشاشة</button>
<button onclick="window.print()">طباعة / PDF</button>
</nav>
<script>{JS}</script>
</body>
</html>
"""
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / (path.stem + ".html")
    dest.write_text(page, encoding="utf-8")
    return dest, len(slides)


def build_index(decks: list[tuple[str, str, int]]) -> Path:
    cards = "\n".join(
        f'<a class="card" href="{f}"><b>{html.escape(title)}</b><span>{f} — {n} slides</span></a>'
        for f, title, n in decks)
    page = f"""<!doctype html>
<html lang="ar" dir="rtl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>عروض ورشة Git وGitHub</title><style>{CSS}</style></head>
<body><div class="idx-page">
<h1>عروض ورشة Git وGitHub</h1>
<p class="sub">Session decks — 16:9 · RTL · أسهم لوحة المفاتيح للتنقل · Ctrl+P للطباعة أو حفظ PDF</p>
<div class="cards">
{cards}
</div>
</div></body></html>
"""
    dest = OUT / "index.html"
    dest.write_text(page, encoding="utf-8")
    return dest


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    files = sorted(f for f in SRC.glob("*.md") if f.name.lower() not in ("readme.md", "index.md"))
    if args:
        files = [f for f in files if any(a in f.name for a in args)]
    if not files:
        print("لا ملفات عروض.")
        return
    made = []
    for f in files:
        dest, n = build(f)
        made.append((dest.name, dest.stem, n))
        print(f"HTML ✓ {dest.relative_to(ROOT)} ({n} شريحة)")
    if not args:
        idx = build_index(made)
        print(f"HTML ✓ {idx.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
