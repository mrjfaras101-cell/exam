/// قراءة ورقة من صورة جاهزة (من معرض الصور أو من كاميرا النظام).
///
/// مفيد جدًا ميدانيًا: بعض المعلمين يفضّلون تصوير الأوراق كلها بكاميرا الجوال
/// ثم تصحيحها دفعة واحدة من داخل التطبيق.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'scan_service.dart';

class ImageScanResult {
  ImageScanResult(this.summary, this.gray, this.width, this.height, this.rgba);
  final ScanSummary summary;
  final Uint8List gray;
  final int width, height;
  final Uint8List rgba;
}

/// يقرأ ملف صورة (jpg/png) ويعيد نتيجة القراءة.
Future<ImageScanResult?> scanImageFile(
  File file, {
  required Map<String, dynamic> spec,
  Map<String, dynamic> thresholds = const {},
  int maxWidth = 1100,
}) async {
  final bytes = await file.readAsBytes();
  final image = await decodeImageFromList(bytes);
  return scanUiImage(image, spec: spec, thresholds: thresholds, maxWidth: maxWidth);
}

Future<ImageScanResult?> scanUiImage(
  ui.Image image, {
  required Map<String, dynamic> spec,
  Map<String, dynamic> thresholds = const {},
  int maxWidth = 1100,
}) async {
  // تصغير للعرض الأقصى قبل التحويل (توفير ذاكرة وزمن)
  final scale = image.width > maxWidth ? maxWidth / image.width : 1.0;
  final w = (image.width * scale).round();
  final h = (image.height * scale).round();

  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (byteData == null) return null;
  final rgbaFull = byteData.buffer.asUint8List();

  final rgba = Uint8List(w * h * 4);
  final gray = Uint8List(w * h);
  final sw = image.width;
  for (var y = 0; y < h; y++) {
    final sy = (y / scale).floor().clamp(0, image.height - 1);
    for (var x = 0; x < w; x++) {
      final sx = (x / scale).floor().clamp(0, sw - 1);
      final si = (sy * sw + sx) * 4;
      final di = (y * w + x) * 4;
      final r = rgbaFull[si], g = rgbaFull[si + 1], b = rgbaFull[si + 2];
      rgba[di] = r; rgba[di + 1] = g; rgba[di + 2] = b; rgba[di + 3] = 255;
      gray[y * w + x] = (r * 77 + g * 150 + b * 29) >> 8;
    }
  }

  final summary = await scanFrame(gray: gray, width: w, height: h, spec: spec, thresholds: thresholds);
  return ImageScanResult(summary, gray, w, h, rgba);
}
