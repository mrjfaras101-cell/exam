#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
يُشغَّل في خطوة أخيرة عند فشل البناء (if: failure()).

الغرض: تحويل آخر أسطر سجلات الخطوات الحرجة إلى «تعليقات» (annotations) على الفحص،
فتكون رسالة الخطأ مقروءة من واجهة GitHub وواجهة برمجية صغيرة (أو من الأدوات التي
لا تستطيع تنزيل ملف السجل الكامل).

الخطوات التي نراقبها تكتب سجلها في /tmp/ci-logs/<اسم>.log عبر tee.
"""
from __future__ import annotations

import glob
import os

LOG_DIR = os.environ.get("CI_LOG_DIR", "/tmp/ci-logs")
MAX_CHARS = 6000           # حد الرسالة في تعليق GitHub أكبر من ذلك بكثير، لكن نبقى مختصرين


def escape(text: str) -> str:
    """ترميز أوامر سير العمل: % ثم CR ثم LF."""
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def main() -> int:
    found = False
    for path in sorted(glob.glob(os.path.join(LOG_DIR, "*.log"))):
        found = True
        name = os.path.basename(path)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                body = fh.read()
        except OSError as exc:
            print(f"::warning title=تعذّر قراءة سجل {name}::{escape(str(exc))}")
            continue
        tail = body[-MAX_CHARS:]
        truncated = " (مقتطف من النهاية)" if len(body) > MAX_CHARS else ""
        print(f"::error title=سجل: {name}{truncated}::{escape(tail)}")
    if not found:
        print(f"::warning title=لا سجلات::{escape('لم يوجد أي ملف في ' + LOG_DIR)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
