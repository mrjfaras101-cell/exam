#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
توليد أيقونات التطبيق (أندرويد + iOS) من شعار المشروع.

المدخلات (في app/assets/branding/):
  icon.png            شعار مربّع كامل (خلفية فاتحة) — يُستعمل لأيقونة النظام القديمة و iOS.
  icon_foreground.png الشعار بخلفية شفافة — يُستعمل للأيقونة التكيّفية (adaptive).

المخرجات (في app/assets/branding/icons/):
  android/mipmap-<dpi>/ic_launcher.png            أيقونة النظام (48 → 192)
  android/mipmap-<dpi>/ic_launcher_foreground.png الجزء الأمامي للأيقونة التكيّفية (108dp)
  android/mipmap-anydpi-v26/ic_launcher.xml       الأيقونة التكيّفية (أندرويد 8+)
  android/values/ic_launcher_background.xml       لون الخلفية التكيّفية
  ios/AppIcon.appiconset/*.png + Contents.json    مجموعة أيقونات iOS

ثم تُنسخ إلى مجلدات المنصّات بأمر:  python3 tool/install_app_icons.py
(ملفات المخرجات مُلتزمة في المستودع، فلا حاجة لتشغيل هذا السكربت إلا عند تغيير الشعار.)

يتطلّب: Pillow  (pip install pillow)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BRANDING = ROOT / "assets" / "branding"
OUT = BRANDING / "icons"

ANDROID_BG = "#E8F5F4"          # لون الخلفية التكيّفية (نفس خلفية الشعار)
# كثافات أندرويد: الاسم ← (حجم الأيقونة العادية، حجم طبقة المقدّمة بالبكسل = 108dp)
ANDROID_DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

# مجموعة أيقونات iOS الكلاسيكية (نفس أسماء قوالب Flutter)
IOS_ICONS = [
    ("Icon-App-20x20@1x.png", 20, "ipad", "20x20", "1x"),
    ("Icon-App-20x20@2x.png", 40, "iphone", "20x20", "2x"),
    ("Icon-App-20x20@3x.png", 60, "iphone", "20x20", "3x"),
    ("Icon-App-29x29@1x.png", 29, "ipad", "29x29", "1x"),
    ("Icon-App-29x29@2x.png", 58, "iphone", "29x29", "2x"),
    ("Icon-App-29x29@3x.png", 87, "iphone", "29x29", "3x"),
    ("Icon-App-40x40@1x.png", 40, "ipad", "40x40", "1x"),
    ("Icon-App-40x40@2x.png", 80, "iphone", "40x40", "2x"),
    ("Icon-App-40x40@3x.png", 120, "iphone", "40x40", "3x"),
    ("Icon-App-60x60@2x.png", 120, "iphone", "60x60", "2x"),
    ("Icon-App-60x60@3x.png", 180, "iphone", "60x60", "3x"),
    ("Icon-App-76x76@1x.png", 76, "ipad", "76x76", "1x"),
    ("Icon-App-76x76@2x.png", 152, "ipad", "76x76", "2x"),
    ("Icon-App-83.5x83.5@2x.png", 167, "ipad", "83.5x83.5", "2x"),
    ("Icon-App-1024x1024@1x.png", 1024, "ios-marketing", "1024x1024", "1x"),
]

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""

COLOR_XML = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{color}</color>
</resources>
"""


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def resize(img, size: int):
    from PIL import Image
    return img.resize((size, size), Image.LANCZOS)


def main() -> int:
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        print("خطأ: يتطلّب هذا السكربت مكتبة Pillow — نفّذ: pip install pillow", file=sys.stderr)
        return 2

    base_path = BRANDING / "icon.png"
    fg_path = BRANDING / "icon_foreground.png"
    for p in (base_path, fg_path):
        if not p.exists():
            print(f"خطأ: الملف غير موجود: {p}", file=sys.stderr)
            return 2

    base = Image.open(base_path).convert("RGB")          # لا شفافية (شرط iOS)
    fg = Image.open(fg_path).convert("RGBA")             # الشعار بخلفية شفافة

    written: list[str] = []

    # ── أندرويد ──────────────────────────────────────────────────────────────
    for density, (icon_px, fg_px) in ANDROID_DENSITIES.items():
        d = OUT / "android" / f"mipmap-{density}"
        d.mkdir(parents=True, exist_ok=True)
        resize(base, icon_px).save(d / "ic_launcher.png", "PNG", optimize=True)
        resize(fg, fg_px).save(d / "ic_launcher_foreground.png", "PNG", optimize=True)
        written += [str(d / "ic_launcher.png"), str(d / "ic_launcher_foreground.png")]

    anydpi = OUT / "android" / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(ADAPTIVE_XML, encoding="utf-8")

    values = OUT / "android" / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "ic_launcher_background.xml").write_text(
        COLOR_XML.format(color=ANDROID_BG), encoding="utf-8")

    # ── iOS ──────────────────────────────────────────────────────────────────
    ios = OUT / "ios" / "AppIcon.appiconset"
    ios.mkdir(parents=True, exist_ok=True)
    contents = {"images": [], "info": {"version": 1, "author": "musahhih"}}
    for name, px, idiom, size, scale in IOS_ICONS:
        resize(base, px).save(ios / name, "PNG", optimize=True)
        contents["images"].append(
            {"size": size, "idiom": idiom, "filename": name, "scale": scale})
        written.append(str(ios / name))
    (ios / "Contents.json").write_text(
        json.dumps(contents, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"تم توليد {len(written)} ملف أيقونة في {OUT}")
    print("الخطوة التالية: python3 tool/install_app_icons.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
