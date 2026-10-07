#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_package.py — تدقيق سلامة الحزمة التدريبية (فحص ما قبل التسليم للفصل)
============================================================================
يتحقق من التكامل المنطقي والملفي قبل أن توزَّع الحزمة على المتدربين:

  1. الأوراق والحلول: لكل ورقة `wsN` يوجد حل `solutions-wsN` + المخرجات الثلاث.
  2. الدرجات: مجموع نقاط المهام في كل ورقة = 100 نقطة (والوحدة 06 مثلها).
  3. إغلاق الكتل: كل `:::` مفتوح في المصادر مُغلق (لا كتل مبتلعة).
  4. رموز آمنة: لا رموز تعبيرية (emoji) في المصادر ولا في الصور SVG.
  5. المراجع المتقاطعة: كل ملف يُذكَر في المصادر موجود فعلاً في `project/`.
  6. العروض: لكل مصدر عرض مخرجات PPTX/HTML/PDF، وعدد الشرائح متطابق.
  7. الفهرس: كل رابط في `index.html` يشير إلى ملف موجود.
  8. الترقيم: أرقام الجلسات/الأوراق في دليل المدرّب مطابقة للأوراق الفعلية.
  9. المشروع يعمل فعلاً: تُنفَّذ سكربتات المشروع على نسخة مؤقتة (بناء الفهرس، فحص البطاقات،
     الفحص المحلي) ويجب أن تنجح، وأن تفشل عند إدخال تعارض مقصود — ويُتحقق من أن الأسطر
     التي تقتبسها الأوراق من مخرجات السكربتات موجودة فعلاً في المخرجات الحقيقية.

الاستخدام:
    python3 tools/verify_package.py           # تدقيق كامل
    python3 tools/verify_package.py --quiet    # الملخص فقط
مخرجات: قائمة ملاحظات مرتّبة (أخطاء ✘ / تحذيرات ⚠) + رمز خروج 1 عند وجود أخطاء.
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "source"

EMOJI = re.compile("[\U0001F000-\U0001FAFF\u2190-\u2BFF\uFE0F]")
SAFE = set("✔✘✓✗★◆●■▲☐→⇒⚠←•─│┌┐└┘├┤┬┴┼━"
           "▣➜▸↳−≥≠⟶▶✱⊳…·▪▫–—")   # مُختبرة بالتصيير الفعلي
BLOCK = re.compile(r"^:::(?P<name>[a-z0-9_-]+)", re.I)
CLOSER = re.compile(r"^\s*:::\s*$", re.M)

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


# ---------------------------------------------------------------- 1+2: الأوراق
def sheet_numbers() -> list[str]:
    nums = []
    for f in sorted(SRC.glob("ws*.md")):
        m = re.match(r"ws(\d+)", f.name)
        if m:
            nums.append(m.group(1))
    return nums


def check_sheets() -> None:
    for n in sheet_numbers():
        ws_files = list(SRC.glob(f"ws{n}-*.md"))
        sol_files = list(SRC.glob(f"solutions-ws{n}.md"))
        if not ws_files:
            err(f"ورقة {n}: لا يوجد ملف مصدر ws{n}-*.md")
            continue
        ws = ws_files[0]
        if not sol_files:
            err(f"ورقة {n}: لا يوجد نموذج حل solutions-ws{n}.md")
        # المخرجات
        for out in (ROOT / "worksheets" / f"{ws.stem}.pdf",
                    ROOT / "worksheets" / f"{ws.stem}.html",
                    ROOT / "docx" / f"{ws.stem}.docx"):
            if not out.exists():
                err(f"ورقة {n}: مخرج مفقود {out.relative_to(ROOT)}")
        if sol_files:
            s = sol_files[0]
            for out in (ROOT / "solutions" / f"{s.stem}.pdf",
                        ROOT / "solutions" / f"{s.stem}.html",
                        ROOT / "docx" / f"{s.stem}.docx"):
                if not out.exists():
                    err(f"حل {n}: مخرج مفقود {out.relative_to(ROOT)}")
        # الدرجات: المهام + أقسام الأسئلة المُعلنة = المجموع المذكور في الترويسة
        text = ws.read_text(encoding="utf-8")
        pts = [int(x) for x in re.findall(r'pts="(\d+)"', text)]
        declared = re.search(r'"الدرجة / Points"\s*:\s*"(\d+)', text)
        declared_total = int(declared.group(1)) if declared else 100
        quiz = []                                   # أقسام الأسئلة المعلنة بنقاطها مثل «(15 نقطة)»
        for chunk in text.split("(")[1:]:
            if ("نقط" in chunk or "نقاط" in chunk) and ")" in chunk:
                head = chunk.split(")")[0]
                digits = "".join(c for c in head if c.isdigit())
                if digits:
                    quiz.append(int(digits))
        if pts:
            total = sum(pts) + sum(quiz)
            if total != declared_total:
                err(f"ورقة {n}: مجموع النقاط {total} (مهام {sum(pts)} + أسئلة {sum(quiz)}) "
                    f"مقابل {declared_total} المعلنة في الترويسة")
            if total > declared_total:
                err(f"ورقة {n}: النقاط تتجاوز الحد المعلن ({total} > {declared_total})")
        else:
            warn(f"ورقة {n}: لا توجد حقول pts في المهام")


# ------------------------------------------------------------------- 3: الكتل
def check_blocks() -> None:
    """قواعد الكتل: صارمة في العروض (كل ::slide تُغلق)، متسامحة في الأوراق.

    في أوراق العمل يُغلق المحلّل كتلة المهمة تلقائياً عند بدء مهمة/قسم جديد، أما الكتل
    الداخلية (term/box/evidence/check/scale/write/code) فيجب أن تُغلق صراحةً.
    """
    IMPLICIT = {"task", "band", "badge"}          # تُغلق تلقائياً حسب تصميم المحلّل
    for f in sorted((SRC / "slides").glob("s*.md")):
        depth = 0
        for i, line in enumerate(f.read_text(encoding="utf-8").split("\n"), 1):
            if CLOSER.match(line):
                depth -= 1
                if depth < 0:
                    err(f"{f.relative_to(ROOT)}:{i}: `:::` إغلاق بلا فتح")
                    depth = 0
            elif BLOCK.match(line):
                depth += 1
        if depth != 0:
            err(f"{f.relative_to(ROOT)}: كتل شرائح غير مغلقة (المتبقي: {depth})")

    for f in sorted(SRC.glob("*.md")):
        if f.name.lower() in ("readme.md", "index.md"):
            continue
        txt = f.read_text(encoding="utf-8")
        closers = len(CLOSER.findall(txt))
        inner = 0
        for line in txt.split("\n"):
            m = BLOCK.match(line)
            if m and m.group("name").lower() not in IMPLICIT:
                inner += 1
        if closers < inner:
            err(f"{f.relative_to(ROOT)}: كتل داخلية غير مغلقة "
                f"(مُغلِّقات {closers} < فواتح {inner})")
        if f.name.startswith("ws") and ":::task" not in txt:
            warn(f"{f.relative_to(ROOT)}: لا توجد مهام :::task في ورقة عمل")


# ------------------------------------------------------------------ 4: الرموز
def check_glyphs() -> None:
    for f in sorted(SRC.rglob("*.md")) + sorted((ROOT / "assets" / "img").glob("*.svg")):
        txt = f.read_text(encoding="utf-8")
        bad = sorted({ch for ch in EMOJI.findall(txt) if ch not in SAFE})
        if bad:
            err(f"{f.relative_to(ROOT)}: رموز قد تظهر مربعات فارغة: {''.join(bad)!r}")


# --------------------------------------------------------- 5: المراجع المتقاطعة
REF = re.compile(r"`([a-zA-Z0-9_./-]+\.(?:md|mjs|json|yml|txt|js|css|html))`")
IGNORE_BASENAMES = {"package.json", "package-lock.json"}

ALLOWLIST_FILE = ROOT / "tools" / "verify-allowlist.txt"


def allowlist() -> set[str]:
    if not ALLOWLIST_FILE.exists():
        return set()
    out = set()
    for line in ALLOWLIST_FILE.read_text(encoding="utf-8").splitlines():
        line = line.split("#")[0].strip()
        if line:
            out.add(line)
    return out


def check_refs() -> None:
    project_files = {p.name for p in (ROOT / "project").rglob("*") if p.is_file()}
    project_paths = {str(p.relative_to(ROOT / "project")) for p in (ROOT / "project").rglob("*") if p.is_file()}
    allow = allowlist()
    missing: dict[str, list[str]] = {}
    for f in sorted(SRC.rglob("*.md")):
        if f.name.lower() == "readme.md":
            continue
        for ref in set(REF.findall(f.read_text(encoding="utf-8"))):
            base = ref.split("/")[-1]
            if base in IGNORE_BASENAMES:
                continue
            if ref in project_paths or base in project_files:
                continue
            if (ROOT / ref).exists() or (ROOT / "project" / ref).exists():
                continue
            # مسارات تعليمية عامة (يكتبها الطالب) تُستثنى
            if ref.startswith(("data/members/", "docs/", "sandbox/")) and base.startswith(("00-", "99-", "team-")):
                continue
            if ref in ("data/members/<username>.json",):
                continue
            if ref in allow or base in allow:
                continue
            # ملفات بطاقة ينشئها المتدربون أثناء الورقة (لا توجد في المستودع الأصلي)
            if base.startswith("data/members/") or "/members/" in ref and base.endswith(".json"):
                continue
            if ref.startswith("data/members/") and base.endswith(".json"):
                continue
            missing.setdefault(ref, []).append(f.name)
    for ref, where in sorted(missing.items()):
        warn(f"مرجع غير موجود في project/: `{ref}` (مذكور في: {', '.join(sorted(set(where)))})")


# ------------------------------------------------------------------ 6: العروض
def check_decks() -> None:
    for src in sorted((SRC / "slides").glob("s*.md")):
        pptx = ROOT / "slides" / f"{src.stem}.pptx"
        htm = ROOT / "slides" / "html" / f"{src.stem}.html"
        pdf = ROOT / "slides" / "pdf" / f"{src.stem}.pdf"
        for out in (pptx, htm, pdf):
            if not out.exists():
                err(f"عرض {src.stem}: مخرج مفقود {out.relative_to(ROOT)}")
        if pptx.exists() and pdf.exists():
            try:
                from pptx import Presentation
                import pypdfium2 as pdfium
                n_ppt = len(Presentation(str(pptx)).slides)
                n_pdf = len(pdfium.PdfDocument(str(pdf)))
                if n_ppt != n_pdf:
                    err(f"عرض {src.stem}: PPTX {n_ppt} شريحة مقابل PDF {n_pdf} صفحة")
            except Exception as e:  # noqa: BLE001
                warn(f"عرض {src.stem}: تعذّر فحص تعداد الشرائح ({e})")


# ------------------------------------------------------------------ 7: الفهرس
def check_hub() -> None:
    hub = ROOT / "index.html"
    if not hub.exists():
        err("الفهرس index.html مفقود (شغّل python3 tools/make_hub.py)")
        return
    text = hub.read_text(encoding="utf-8")
    links = re.findall(r'href="([^"#][^"]*)"', text)
    for link in sorted(set(links)):
        if link.startswith(("http", "mailto:")):
            continue
        target = (ROOT / html.unescape(link)).resolve()
        if not target.exists():
            err(f"الفهرس: رابط مكسور → {link}")


# ----------------------------------------------------------------- 8: الترقيم
def check_numbering() -> None:
    guide = SRC / "trainer-guide.md"
    if not guide.exists():
        return
    text = guide.read_text(encoding="utf-8")
    # كل صف في جدول الجلسات يذكر الورقة بـ 0N
    for n in sheet_numbers():
        if not re.search(rf"\| ?0?{int(n)}\b|ورقة 0?{n}\b", text):
            warn(f"دليل المدرّب: لا إشارة إلى الورقة {n} في خطة الجلسات")
    # الدرجة الكلية
    if "600" not in text:
        warn("دليل المدرّب: لم يُذكر المجموع الكلي 600 نقطة")


# ------------------------------------------------- 9: المشروع يعمل فعلاً (وظيفي)
def check_project_runs() -> None:
    """يتحقق أن سكربتات المشروع تعمل وتُنتج السطور المقتبسة في الأوراق."""
    import shutil
    import subprocess
    import tempfile

    if not shutil.which("node"):
        warn("فحص المشروع الوظيفي متخطّى: node غير متوفّر في هذه البيئة.")
        return

    tmp = Path(tempfile.mkdtemp(prefix="pkgcheck-"))
    try:
        shutil.copytree(ROOT / "project", tmp / "project")
        cwd = tmp / "project"

        def run(cmd: str) -> subprocess.CompletedProcess:
            return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

        r1 = run("node tools/build-index.mjs")
        if r1.returncode != 0:
            err(f"المشروع: تعذّر توليد الفهرس — {(r1.stderr or r1.stdout).strip()[:120]}")
        r2 = run("node tests/validate-members.mjs")
        if r2.returncode != 0:
            err(f"المشروع: فحص البطاقات يفشل على مستودع نظيف — {(r2.stdout).strip()[-140:]}")
        r3 = run("node tools/ci-local.mjs")
        if r3.returncode != 0:
            err("المشروع: الفحص المحلي يفشل على مستودع نظيف (يجب أن يمرّ)")

        clean_out = (r1.stdout + r2.stdout + r3.stdout)

        # الأسطر التي تقتبسها الأوراق من السكربتات يجب أن تطابق المخرجات الحقيقية
        for quoted in ("[build-index] ✔ تم توليد الفهرس", "--- النتيجة / Result:",
                       "▸ لا علامات تعارض / no conflict markers … ✔ نجح",
                       "✔ كل الفحوص نجحت"):
            if quoted not in clean_out:
                err(f"اقتباس لا يطابق الواقع: «{quoted}» غير موجود في مخرجات المشروع الحقيقية")

        # المشروع يجب أن يكشف تعارضاً مزروعاً في ملف مختبر التعارض نفسه
        lab = cwd / "sandbox" / "team-slogan.txt"
        original = lab.read_text(encoding="utf-8")
        lab.write_text("<<<<<<< HEAD\nلافتة الصف\n=======\nلافتة الزميل\n>>>>>>> feature/omar-slogan\n",
                       encoding="utf-8")
        r4 = run("node tools/ci-local.mjs")
        if r4.returncode == 0:
            err("المشروع: الفحص المحلي لم يكشف تعارضاً مزروعاً في sandbox/team-slogan.txt")
        elif "team-slogan" not in (r4.stdout + r4.stderr):
            warn("المشروع: كشف التعارض لكن دون الإشارة إلى الملف المزروع")

        # درس الورقة 06: النمط القديم يفوّت العلامات التي تحمل اسم فرع، والصحيح يلتقطها
        lab.write_text("<<<<<<< HEAD\nبلا سطر أوسط\n>>>>>>> feature/x\n", encoding="utf-8")
        weak = run("grep -rInE '^(<<<<<<<|>>>>>>>|=======)$' --exclude-dir=.git sandbox/")
        strong = run("grep -rInE '^(<{7}|={7}|>{7})( |$)' --exclude-dir=.git sandbox/")
        if weak.returncode == 0:
            warn("درس الفحص الضعيف: النمط القديم التقط العلامات — راجع نص الورقة 06")
        if strong.returncode != 0:
            err("النمط المصحّح في الورقة 06 لا يلتقط العلامات التي تحمل اسم فرع")
        lab.write_text(original, encoding="utf-8")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> None:
    quiet = "--quiet" in sys.argv
    check_sheets()
    check_blocks()
    check_glyphs()
    check_refs()
    check_decks()
    check_hub()
    check_numbering()
    check_project_runs()

    print("=" * 70)
    print("تدقيق سلامة الحزمة / Package integrity audit")
    print("=" * 70)
    if not quiet:
        for e in errors:
            print(f"✘ خطأ:  {e}")
        for w in warnings:
            print(f"⚠ تحذير: {w}")
    print("-" * 70)
    print(f"الأوراق: {len(sheet_numbers())} · أخطاء: {len(errors)} · تحذيرات: {len(warnings)}")
    print("✔ الحزمة سليمة — جاهزة للتوزيع." if not errors
          else "✘ يجب إصلاح الأخطاء أعلاه قبل التوزيع.")
    return sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
