#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
نسخ أيقونات التطبيق الجاهزة (app/assets/branding/icons) إلى مجلدات المنصّات.

يُشغَّل بعد `flutter create` — داخل مجلد app/:
    python3 tool/install_app_icons.py

• أندرويد: ينسخ mipmap-* و values الأيقونة إلى android/app/src/main/res/
• iOS: ينسخ AppIcon.appiconset إلى ios/Runner/Assets.xcassets/ (إن وُجد مجلد ios)

يكتب تقريرًا بما نُسخ، ويرجع بكود خطأ 1 إن لم يجد الأيقونات المصدرية.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

APP = Path(__file__).resolve().parent.parent
SRC_ANDROID = APP / "assets" / "branding" / "icons" / "android"
SRC_IOS = APP / "assets" / "branding" / "icons" / "ios" / "AppIcon.appiconset"

RES = APP / "android" / "app" / "src" / "main" / "res"
IOS_ASSETS = APP / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

copied = 0
notes: list[str] = []

if not SRC_ANDROID.exists():
    print(f"خطأ: لا توجد أيقونات مُولَّدة في {SRC_ANDROID}", file=sys.stderr)
    print("شغّل أولًا: python3 tool/make_app_icons.py", file=sys.stderr)
    raise SystemExit(1)

if RES.exists():
    for src in sorted(SRC_ANDROID.iterdir()):
        if src.is_dir():                      # mipmap-anydpi-v26 / values
            dst = RES / src.name
            dst.mkdir(parents=True, exist_ok=True)
            for f in sorted(src.iterdir()):
                shutil.copy2(f, dst / f.name)
                copied += 1
        else:
            shutil.copy2(src, RES / src.name)
            copied += 1
    notes.append(f"أندرويد: {RES.relative_to(APP)}")
else:
    notes.append("أندرويد: مجلد res غير موجود — تجاهُل")

if SRC_IOS.exists() and (APP / "ios").exists():
    IOS_ASSETS.mkdir(parents=True, exist_ok=True)
    for f in sorted(SRC_IOS.iterdir()):
        shutil.copy2(f, IOS_ASSETS / f.name)
        copied += 1
    notes.append(f"iOS: {IOS_ASSETS.relative_to(APP)}")
else:
    notes.append("iOS: مجلد ios غير موجود — تجاهُل")

print(f"تم نسخ {copied} ملف أيقونة:")
for n in notes:
    print(f"  • {n}")
