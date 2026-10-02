#!/usr/bin/env python3
"""رفع compileSdk لحزم pub المخزّنة مؤقتًا (إصلاح توافقي).

المشكلة: بعض حزم Flutter على pub.dev تُصرّف نفسها بـ `compileSdk 30` بينما تبعيات
androidx التي تستخدمها تطلب 33 أو أعلى، فيفشل البناء برسائل مثل:

    Dependency 'androidx.tracing:tracing:1.2.0' requires libraries and applications
    that depend on it to compile against version 33 or later of the Android APIs.
    :printing is currently compiled against android-30.

الحل هنا: نرفع `compileSdk` إلى 36 في نسخ الحزم داخل مجلد pub cache قبل البناء
(مع احترام صيغة كل ملف: Kotlin DSL أو Groovy). الإصلاح الجذري هو أن تُحدّث الحزمة
نفسها، وحينها يمكن حذف هذه الخطوة.

الاستخدام:
    python3 tool/fix_pub_cache_compile_sdk.py [--sdk 36] [--dry-run]
"""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import sys


def cache_root() -> pathlib.Path:
    env = os.environ.get("PUB_CACHE")
    if env:
        return pathlib.Path(env)
    if sys.platform.startswith("win"):
        return pathlib.Path(os.environ.get("LOCALAPPDATA", "~")) / "Pub" / "Cache"
    return pathlib.Path.home() / ".pub-cache"


def patch_text(text: str, sdk: int, is_kotlin: bool) -> str:
    if is_kotlin:
        text = re.sub(r"compileSdkVersion\(\s*\d+\s*\)", f"compileSdkVersion({sdk})", text)
        text = re.sub(r"compileSdkVersion\s*=\s*\d+", f"compileSdk = {sdk}", text)
        text = re.sub(r"(?<!Version)\bcompileSdk\s*=\s*\d+", f"compileSdk = {sdk}", text)
    else:
        text = re.sub(r"compileSdkVersion\s*=\s*\d+", f"compileSdkVersion {sdk}", text)
        text = re.sub(r"compileSdkVersion\s+\d+", f"compileSdkVersion {sdk}", text)
        text = re.sub(r"(?<!Version)\bcompileSdk\s*=\s*\d+", f"compileSdk = {sdk}", text)
    return text


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sdk", type=int, default=36, help="قيمة compileSdk المطلوبة (افتراضي 36)")
    ap.add_argument("--app-dir", default="android/app", help="مجلد تطبيق أندرويد لرفع minSdk فيه")
    ap.add_argument("--min-sdk", type=int, default=24, help="قيمة minSdk للتطبيق (افتراضي 24)")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--cache", default=None, help="مسار pub cache (افتراضي: PUB_CACHE أو ~/.pub-cache)")
    args = ap.parse_args()

    root = pathlib.Path(args.cache) if args.cache else cache_root()
    if not root.exists():
        print(f"! لم أجد مجلد pub cache: {root}")
        return 1

    patched: list[str] = []

    # 1) حزم pub: رفع compileSdk
    for f in sorted(root.rglob("android/build.gradle*")):
        try:
            original = f.read_text(errors="ignore")
        except OSError:
            continue
        text = patch_text(original, args.sdk, f.name.endswith(".kts"))
        if text != original:
            if not args.dry_run:
                f.write_text(text)
            patched.append(str(f))

    # 2) تطبيقنا: رفع minSdk لتفادي تعارض متطلبات الحزم
    app_dir = pathlib.Path(args.app_dir)
    for g in sorted(app_dir.glob("build.gradle*")):
        text = g.read_text(errors="ignore")
        new = re.sub(r"minSdk\s*=\s*[^\n]+", f"minSdk = {args.min_sdk}", text)
        new = re.sub(r"minSdkVersion\s+\S+", f"minSdkVersion {args.min_sdk}", new)
        if new != text:
            if not args.dry_run:
                g.write_text(new)
            patched.append(str(g))

    print(f"عدد الملفات المعدّلة: {len(patched)}" + (" (تجريبي)" if args.dry_run else ""))
    for x in patched:
        print("  -", x)
    return 0


if __name__ == "__main__":
    sys.exit(main())
