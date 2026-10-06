#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
serve_slides.py — خادم محلي بسيط لمعاينة العروض في المتصفح
=============================================================
يشغّل مجلد الحزمة (الجذر) على منفذ محلي، مع تعريف أنواع MIME الناقصة
(`.woff2`, `.mjs`, `.pptx`) حتى تُحمّل الخطوط العربية والأكواد بلا مشاكل.

الاستخدام:
    python3 tools/serve_slides.py                 # المنفذ 8110
    python3 tools/serve_slides.py 9000            # منفذ مختلف

ثم افتح:  http://localhost:8110/slides/html/index.html
"""

from __future__ import annotations

import functools
import http.server
import mimetypes
import socketserver
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

mimetypes.add_type("font/woff2", ".woff2")
mimetypes.add_type("text/javascript", ".mjs")
mimetypes.add_type("application/vnd.openxmlformats-officedocument.presentationml.presentation", ".pptx")
mimetypes.add_type("application/pdf", ".pdf")


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):  # هادئ
        pass


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8110
    handler = functools.partial(Handler, directory=str(ROOT))
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer(("0.0.0.0", port), handler) as httpd:
        print(f"خادم العروض يعمل على http://0.0.0.0:{port}")
        print(f"افتح: http://localhost:{port}/slides/html/index.html")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
