/// تحويل إطارات الكاميرا إلى مصفوفة رمادية للمحرّك.
///
/// قاعدة الأداء: على أندرويد نستهلك مستوى Y من YUV420 مباشرة (بلا فك ترميز ولا تحويل)،
/// وعلى iOS نستخدم BGRA ونحوّله إلى رمادي. كل شيء يعمل داخل Isolate (compute) لأن
/// المعالجة تستغرق 0.1–0.4 ثانية للإطار الواحد.
library;

import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

class FrameData {
  FrameData({required this.gray, required this.width, required this.height, required this.toRgba});

  /// مصفوفة رمادية (صفوف متتالية بطول width*height).
  final Uint8List gray;
  final int width;
  final int height;

  /// يحوّل إلى RGBA عند الحاجة فقط (مثلاً لحفظ صورة المراجعة).
  final Uint8List Function() toRgba;
}

/// يحوّل صورة الكاميرا إلى رمادي + (عند الطلب) RGBA.
FrameData frameFromCameraImage(CameraImage image) {
  final w = image.width, h = image.height;
  final format = image.format.group;

  switch (format) {
    case ImageFormatGroup.yuv420:
      {
        final yPlane = image.planes[0];
        final gray = Uint8List(w * h);
        final rowStride = yPlane.bytesPerRow;
        final src = yPlane.bytes;
        for (var y = 0; y < h; y++) {
          final srcOff = y * rowStride;
          final dstOff = y * w;
          final n = (srcOff + w <= src.length) ? w : (src.length - srcOff);
          if (n <= 0) break;
          gray.setRange(dstOff, dstOff + n, src, srcOff);
        }
        return FrameData(
          gray: gray,
          width: w,
          height: h,
          toRgba: () => _yuv420ToRgba(image, w, h),
        );
      }

    case ImageFormatGroup.bgra8888:
      {
        final plane = image.planes[0];
        final src = plane.bytes;
        final rowStride = plane.bytesPerRow;
        final gray = Uint8List(w * h);
        for (var y = 0; y < h; y++) {
          final rowOff = y * rowStride;
          for (var x = 0; x < w; x++) {
            final i = rowOff + x * 4;
            if (i + 2 >= src.length) break;
            final b = src[i], g = src[i + 1], r = src[i + 2];
            gray[y * w + x] = (r * 77 + g * 150 + b * 29) >> 8;
          }
        }
        return FrameData(
          gray: gray,
          width: w,
          height: h,
          toRgba: () {
            final rgba = Uint8List(w * h * 4);
            for (var y = 0; y < h; y++) {
              final rowOff = y * rowStride;
              for (var x = 0; x < w; x++) {
                final i = rowOff + x * 4;
                final o = (y * w + x) * 4;
                if (i + 2 >= src.length) break;
                rgba[o] = src[i + 2];     // R
                rgba[o + 1] = src[i + 1]; // G
                rgba[o + 2] = src[i];     // B
                rgba[o + 3] = 255;
              }
            }
            return rgba;
          },
        );
      }

    default:
      throw UnsupportedError('صيغة إطار غير مدعومة: $format');
  }
}

Uint8List _yuv420ToRgba(CameraImage image, int w, int h) {
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];
  final yBytes = yPlane.bytes, uBytes = uPlane.bytes, vBytes = vPlane.bytes;
  final yStride = yPlane.bytesPerRow, uStride = uPlane.bytesPerRow, vStride = vPlane.bytesPerRow;
  final uPixel = uPlane.bytesPerPixel ?? 1, vPixel = vPlane.bytesPerPixel ?? 1;

  final rgba = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final yi = y * yStride + x;
      if (yi >= yBytes.length) break;
      final uvRow = y ~/ 2;
      final ui = uvRow * uStride + (x ~/ 2) * uPixel;
      final vi = uvRow * vStride + (x ~/ 2) * vPixel;
      final yv = yBytes[yi];
      final uv = (ui < uBytes.length ? uBytes[ui] : 128) - 128;
      final vv = (vi < vBytes.length ? vBytes[vi] : 128) - 128;
      final r = (yv + 1.402 * vv).clamp(0, 255).toInt();
      final g = (yv - 0.344136 * uv - 0.714136 * vv).clamp(0, 255).toInt();
      final b = (yv + 1.772 * uv).clamp(0, 255).toInt();
      final o = (y * w + x) * 4;
      rgba[o] = r; rgba[o + 1] = g; rgba[o + 2] = b; rgba[o + 3] = 255;
    }
  }
  return rgba;
}

/// تصغير المصفوفة الرمادية إلى عرض أقصى (تقليل زمن المعالجة مع الحفاظ على الدقة الكافية).
Uint8List downscaleGray(Uint8List gray, int w, int h, int maxWidth, List<int> outSize) {
  if (w <= maxWidth) {
    outSize[0] = w;
    outSize[1] = h;
    return gray;
  }
  final scale = maxWidth / w;
  final nw = maxWidth;
  final nh = (h * scale).round();
  final out = Uint8List(nw * nh);
  for (var y = 0; y < nh; y++) {
    final sy0 = (y / scale).floor().clamp(0, h - 1);
    final sy1 = ((y + 1) / scale).ceil().clamp(1, h);
    for (var x = 0; x < nw; x++) {
      final sx0 = (x / scale).floor().clamp(0, w - 1);
      final sx1 = ((x + 1) / scale).ceil().clamp(1, w);
      var sum = 0, n = 0;
      for (var sy = sy0; sy < sy1; sy++) {
        final row = sy * w;
        for (var sx = sx0; sx < sx1; sx++) {
          sum += gray[row + sx];
          n++;
        }
      }
      out[y * nw + x] = n == 0 ? gray[sy0 * w + sx0] : (sum / n).round();
    }
  }
  outSize[0] = nw;
  outSize[1] = nh;
  return out;
}
