#!/usr/bin/env bash
# build_all.sh — بناء الحزمة كاملةً بأمر واحد (مستندات + عروض + فهرس)
# =============================================================================
#   bash tools/build_all.sh              # كل شيء
#   bash tools/build_all.sh --fast       # بلا DOCX (أسرع)
#   bash tools/build_all.sh --no-slides  # مستندات فقط
#
# الترتيب مقصود: المستندات → فهرس الحزمة (يُولَّد داخل build.py) →
#               عروض PPTX → نسخة المتصفح + PDF للعروض.
# كل خطوة تعتمد على مصدر الحقيقة في source/ — لا تعدّل المخرجات يدوياً.

set -euo pipefail
cd "$(dirname "$0")/.."

FAST=0; SLIDES=1
for a in "$@"; do
  case "$a" in
    --fast) FAST=1 ;;
    --no-slides) SLIDES=0 ;;
    *) echo "خيار غير معروف: $a"; exit 2 ;;
  esac
done

echo "▶ 1/3 مستندات الأوراق والحلول والدليل (PDF + DOCX + HTML)"
if [ "$FAST" = "1" ]; then python3 tools/build.py --no-docx; else python3 tools/build.py; fi

if [ "$SLIDES" = "1" ]; then
  echo "▶ 2/3 عروض الجلسات (PPTX) + فحص الجودة"
  python3 tools/build_slides.py
  python3 tools/check_slides.py

  echo "▶ 3/3 نسخة المتصفح + PDF للعروض"
  python3 tools/build_slides_html.py --pdf
else
  echo "… تم تخطي العروض (--no-slides)"
fi

echo
echo "✔ اكتمل بناء الحزمة. للمعاينة: python3 tools/serve_slides.py"
