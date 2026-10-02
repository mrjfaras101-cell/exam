#!/usr/bin/env python3
"""يضيف صلاحيات الكاميرا والصور إلى مشروعي أندرويد وiOS بعد `flutter create .`.

الاستخدام:
    cd app
    flutter create .                 # مرة واحدة، يولّد مجلدات المنصات
    python3 tool/apply_platform_config.py

السكربت آمن للتشغيل المتكرر (لا يكرّر الإضافات إن كانت موجودة).
"""

from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

CAMERA_PERMISSION = '    <uses-permission android:name="android.permission.CAMERA" />'
CAMERA_FEATURE = '    <uses-feature android:name="android.hardware.camera" android:required="false" />'

IOS_KEYS = [
    ("NSCameraUsageDescription", "يحتاج التطبيق إلى الكاميرا لقراءة أوراق الإجابة وتصحيحها."),
    ("NSPhotoLibraryUsageDescription", "يحتاج التطبيق إلى الوصول لصورك لتصحيح أوراق سبق تصويرها."),
    ("NSPhotoLibraryAddUsageDescription", "لحفظ ملفات النتائج (CSV و PDF) التي تصدّرها من التطبيق."),
]


def patch_android() -> bool:
    manifest = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
    if not manifest.exists():
        print("• أندرويد: لم أجد AndroidManifest.xml — شغّل `flutter create .` أولًا.")
        return False
    text = manifest.read_text(encoding="utf-8")
    if "android.permission.CAMERA" in text:
        print("• أندرويد: صلاحية الكاميرا موجودة أصلًا ✓")
        return True

    anchor = "    <application"
    if anchor not in text:
        print("• أندرويد: بنية الملف غير متوقعة — أضف الصلاحية يدويًا فوق <application>.")
        return False

    addition = f"{CAMERA_PERMISSION}\n{CAMERA_FEATURE}\n\n"
    text = text.replace(anchor, addition + anchor, 1)
    manifest.write_text(text, encoding="utf-8")
    print("• أندرويد: أُضيفت صلاحية CAMERA + uses-feature ✓")
    return True


def patch_ios() -> bool:
    plist = ROOT / "ios" / "Runner" / "Info.plist"
    if not plist.exists():
        print("• iOS: لم أجد Info.plist — شغّل `flutter create .` أولًا.")
        return False
    text = plist.read_text(encoding="utf-8")
    missing = [(k, v) for k, v in IOS_KEYS if f"<key>{k}</key>" not in text]
    if not missing:
        print("• iOS: أوصاف الاستخدام موجودة أصلًا ✓")
        return True

    close = "</dict>\n</plist>"
    if close not in text:
        print("• iOS: بنية الملف غير متوقعة — أضف المفاتيح يدويًا.")
        return False

    block = "".join(f"\t<key>{k}</key>\n\t<string>{v}</string>\n" for k, v in missing)
    text = text.replace(close, block + close, 1)
    plist.write_text(text, encoding="utf-8")
    print(f"• iOS: أُضيفت {len(missing)} مفاتيح وصف استخدام ✓")
    return True


def main() -> int:
    print("تهيئة صلاحيات مُصحِّح…")
    ok_android = patch_android()
    ok_ios = patch_ios()
    if not (ok_android or ok_ios):
        print("\nلم يُعدَّل شيء. تأكّد من وجود مجلدات المنصات (flutter create .).")
        return 1
    print("\nتم. تحقّق يدويًا من:")
    print("  - android/app/build.gradle: minSdkVersion ≥ 21 (الافتراضي في Flutter الحديث كافٍ)")
    print("  - ios/Runner.xcodeproj: Deployment Target ≥ 12")
    return 0


if __name__ == "__main__":
    sys.exit(main())
