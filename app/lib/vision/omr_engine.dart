/// محرّك قراءة أوراق الإجابة (OMR) — Dart خالص، بلا تبعيات أصلية.
///
/// الخوارزمية (مطابقة حرفيًا للمحرّك المُعايَر والمُختبر في demo/js/engine.js):
///   1) رمادي → 2) تصحيح إضاءة (قسمة على تقدير الخلفية) → 3) عتبة Otsu
///   4) مكوّنات متّصلة → 5) علامات التسجيل (مساحة/اتجاه عبر فحص المظهر) → 6) تجانس
///   7) فحوص جودة → 8) أخذ عيّنات حلقية لكل فقاعة → 9) قرار متعدّد العتبات + ثقة
///
/// يعمل على مصفوفة رمادية (Uint8List, صفوف متتالية) — أسرع مسار على أندرويد هو
/// استهلاك مستوى Y من إطار YUV مباشرة بلا فك ترميز.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'template.dart';

/// العتبات القابلة للمعايرة (نفس قيم المحرّك المرجعي المُختبر).
class EngineThresholds {
  const EngineThresholds({
    this.maxWorkWidth = 1100,
    this.bgRadiusFactor = 0.045,
    this.inkRatio = 0.74,
    this.softInkRatio = 0.86,
    this.softMinContrast = 14,
    this.ringInner = 0.42,
    this.ringOuter = 0.70,
    this.tHigh = 0.45,
    this.tLight = 0.18,
    this.codeThreshold = 0.42,
    this.minPxPerMm = 3.5,
    this.lowPxPerMm = 5.2,
    this.warnEdgeWidthMm = 1.0,
    this.failEdgeWidthMm = 2.4,
    this.maxGlareRatio = 0.30,
    this.maxSideSkew = 0.35,
    this.minPaperCoverage = 0.12,
    this.maxComponentArea = 0.03,
  });

  final int maxWorkWidth;
  final double bgRadiusFactor, inkRatio, softInkRatio, softMinContrast;
  final double ringInner, ringOuter, tHigh, tLight, codeThreshold;
  final double minPxPerMm, lowPxPerMm, warnEdgeWidthMm, failEdgeWidthMm, maxGlareRatio;
  final double maxSideSkew, minPaperCoverage, maxComponentArea;

  EngineThresholds copyWith({double? tHigh, double? tLight, double? inkRatio}) => EngineThresholds(
        maxWorkWidth: maxWorkWidth, bgRadiusFactor: bgRadiusFactor,
        inkRatio: inkRatio ?? this.inkRatio, softInkRatio: softInkRatio,
        softMinContrast: softMinContrast, ringInner: ringInner, ringOuter: ringOuter,
        tHigh: tHigh ?? this.tHigh, tLight: tLight ?? this.tLight,
        codeThreshold: codeThreshold, minPxPerMm: minPxPerMm, lowPxPerMm: lowPxPerMm,
        warnEdgeWidthMm: warnEdgeWidthMm, failEdgeWidthMm: failEdgeWidthMm,
        maxGlareRatio: maxGlareRatio, maxSideSkew: maxSideSkew,
        minPaperCoverage: minPaperCoverage, maxComponentArea: maxComponentArea,
      );
}

/* ------------------------------------------------------------------ */
/* نتائج القراءة                                                       */
/* ------------------------------------------------------------------ */

class CodeReading {
  CodeReading({required this.value, required this.serial, required this.isKeySheet, required this.margin});
  final int value, serial;
  final bool isKeySheet;
  final double margin;
}

class DigitReading {
  DigitReading(this.col, this.digit, this.fill, this.status);
  final int col;
  final int? digit;
  final double fill;
  final String status; // ok | ambiguous | empty
}

class AnswerReading {
  AnswerReading({
    required this.index, required this.type, required this.option, required this.status,
    required this.reason, required this.fill, required this.fills, required this.fillSofts,
    required this.bubblePoints,
  });

  final int index;
  final String type;
  final int? option;
  final String status; // ok | light | blank | ambiguous
  final String? reason;
  final double fill;
  final List<double> fills, fillSofts;

  /// إحداثيات الفقاعات في الصورة (للتراكب البصري في المراجعة).
  final List<List<double>> bubblePoints;

  bool get needsReview => status != 'ok';
}

class SheetQuality {
  SheetQuality({
    required this.pxPerMm, required this.sharpness, required this.edgeWidthMm,
    required this.coverage, required this.whiteRef, required this.glareRatio, required this.otsu,
  });
  final double pxPerMm, edgeWidthMm, coverage, whiteRef, glareRatio;
  final int sharpness;
  final int otsu;
}

class SheetReading {
  SheetReading({
    required this.ok,
    this.reason,
    this.quality,
    this.code,
    this.digits = const [],
    this.digitReadings = const [],
    this.digitFills = const [],
    this.digitIssues = const [],
    this.answers = const [],
    this.flags = const [],
    this.confidence = 0,
    this.mirrored = false,
    this.orientationScore = 0,
    this.lowRes = false,
    this.corners = const [],
    this.elapsedMs = 0,
  });

  final bool ok;
  final String? reason;
  final SheetQuality? quality;
  final CodeReading? code;
  final List<int?> digits;
  final List<DigitReading> digitReadings;
  final List<List<double>> digitFills;
  final List<int> digitIssues;
  final List<AnswerReading> answers;
  final List<ReviewFlagLite> flags;
  final double confidence;
  final bool mirrored;
  final double orientationScore;
  final bool lowRes;
  final List<List<double>> corners;
  final int elapsedMs;

  static SheetReading fail(String reason, {SheetQuality? quality}) =>
      SheetReading(ok: false, reason: reason, quality: quality);

  /// رقم الجلوس كعدد صحيح (null إن كان أي منزلة غير مقروءة).
  int? get studentNumber {
    if (digits.isEmpty || digits.any((d) => d == null)) return null;
    return int.tryParse(digits.map((d) => d.toString()).join());
  }

  List<int?> get answerOptions => answers.map((a) => a.option).toList();
}

class ReviewFlagLite {
  ReviewFlagLite(this.index, this.status, this.reason);
  final int index;
  final String status;
  final String reason;
}

/* ------------------------------------------------------------------ */
/* المحرّك                                                             */
/* ------------------------------------------------------------------ */

class SheetReader {
  SheetReader({this.thresholds = const EngineThresholds()});
  final EngineThresholds thresholds;

  /// يقرأ ورقة واحدة من مصفوفة رمادية.
  SheetReading read({
    required Uint8List gray,
    required int width,
    required int height,
    required SheetTemplate template,
  }) {
    final t0 = DateTime.now();
    final th = thresholds;

    final illum = _Illumination.correct(gray, width, height, th);
    final corrected = illum.corrected;
    final thr = _otsu(corrected);
    final mask = Uint8List(width * height);
    for (var i = 0; i < mask.length; i++) {
      mask[i] = corrected[i] < thr ? 1 : 0;
    }

    final comps = _connectedComponents(mask, width, height, 14);
    final fid = _findFiducials(comps, mask, gray, width, height, th);
    if (!fid.ok) return SheetReading.fail(fid.reason ?? 'لم أتعرّف على الورقة');

    final H = fid.homography!;
    final dst = fid.cornersPx!;

    // فحوص الجودة
    final dTop = _dist(dst[0], dst[1]);
    final dLeft = _dist(dst[0], dst[3]);
    final pxPerMm = (dTop / kFiducialPitchXMm + dLeft / kFiducialPitchYMm) / 2;

    var minX = double.infinity, minY = double.infinity, maxX = 0.0, maxY = 0.0;
    for (final p in dst) {
      minX = math.min(minX, p[0]); maxX = math.max(maxX, p[0]);
      minY = math.min(minY, p[1]); maxY = math.max(maxY, p[1]);
    }
    final x0 = math.max(0, minX.floor()), x1 = math.min(width - 1, maxX.ceil());
    final y0 = math.max(0, minY.floor()), y1 = math.min(height - 1, maxY.ceil());

    final sharpness = _laplacianVariance(gray, width, height, x0, y0, x1, y1);
    final edgeWidthMm = _measureEdgeWidthMm(corrected, width, height, H, pxPerMm);
    final coverage = _polygonArea(dst) / (width * height);

    // بياض الورق المحلي (المئين 90)
    final samples = <int>[];
    final stepX = math.max(1, (x1 - x0) ~/ 120), stepY = math.max(1, (y1 - y0) ~/ 120);
    for (var y = y0; y <= y1; y += stepY) {
      for (var x = x0; x <= x1; x += stepX) {
        samples.add(corrected[y * width + x]);
      }
    }
    final whiteRef = samples.isEmpty ? 255.0 : _percentile(samples, 90).toDouble();

    var glarePx = 0, glareTotal = 0;
    for (var y = y0; y <= y1; y += 2) {
      for (var x = x0; x <= x1; x += 2) {
        glareTotal++;
        if (gray[y * width + x] >= 252) glarePx++;
      }
    }
    final glareRatio = glareTotal == 0 ? 0.0 : glarePx / glareTotal;

    final quality = SheetQuality(
      pxPerMm: pxPerMm, sharpness: sharpness.round(), edgeWidthMm: edgeWidthMm,
      coverage: coverage, whiteRef: whiteRef, glareRatio: glareRatio, otsu: thr,
    );

    if (pxPerMm < th.minPxPerMm) {
      return SheetReading.fail('الدقة منخفضة (${pxPerMm.toStringAsFixed(1)} بكسل/مم) — قرّب الكاميرا من الورقة', quality: quality);
    }
    if (edgeWidthMm > th.failEdgeWidthMm) {
      return SheetReading.fail('الصورة غير واضحة (اهتزاز/بُعد) — ثبّت يدك وأعد المحاولة', quality: quality);
    }
    if (coverage < th.minPaperCoverage) {
      return SheetReading.fail('الورقة صغيرة في الإطار — املأ الإطار بالورقة', quality: quality);
    }

    // أخذ العيّنات
    final flat = template.allBubbles;
    final fill = List<double>.filled(flat.length, 0);
    final fillSoft = List<double>.filled(flat.length, 0);
    final pts = List<List<double>>.filled(flat.length, const [0, 0]);
    final glares = List<double>.filled(flat.length, 0);
    final meanInk = List<double>.filled(flat.length, 0);
    for (var i = 0; i < flat.length; i++) {
      final s = _sampleBubble(corrected, gray, width, height, H, flat[i], whiteRef, th);
      fill[i] = s.fill; fillSoft[i] = s.fillSoft; pts[i] = [s.x, s.y];
      glares[i] = s.glare; meanInk[i] = s.meanInk;
    }

    // رمز الورقة
    final codeCols = <int>[]; final codeFills = <double>[];
    for (var i = 0; i < flat.length; i++) {
      if (flat[i].role != 'code') continue;
      codeCols.add(flat[i].bit); codeFills.add(fill[i]);
    }
    final order = List<int>.generate(codeCols.length, (i) => i)..sort((a, b) => codeCols[a].compareTo(codeCols[b]));
    var codeVal = 0; var codeMargin = 1.0;
    for (final i in order) {
      if (codeFills[i] >= th.codeThreshold) codeVal |= 1 << codeCols[i];
      codeMargin = math.min(codeMargin, (codeFills[i] - th.codeThreshold).abs());
    }
    final serial = codeVal & ((1 << SheetGeometry.codeBits) - 1);
    final isKeySheet = ((codeVal >> SheetGeometry.codeKeyBit) & 1) == 1;

    // شبكة رقم الجلوس
    final digitReadings = <DigitReading>[];
    final digitFills = <List<double>>[];
    final digitIssueCols = <int>[];
    final digits = <int?>[];
    for (var c = 0; c < template.digitCols; c++) {
      final colFills = List<double>.filled(SheetGeometry.idRows, 0);
      var marked = -1, markedCount = 0;
      for (var i = 0; i < flat.length; i++) {
        if (flat[i].role != 'digit' || flat[i].index != c) continue;
        final f = fill[i];
        colFills[flat[i].digit] = f;
        if (f >= th.tHigh) { markedCount++; marked = flat[i].digit; }
      }
      digitFills.add(colFills);
      if (markedCount == 1) {
        digitReadings.add(DigitReading(c, marked, colFills[marked], 'ok'));
        digits.add(marked);
      } else {
        final maxFill = colFills.reduce(math.max);
        digitReadings.add(DigitReading(c, null, maxFill, markedCount == 0 ? 'empty' : 'ambiguous'));
        digits.add(null);
        digitIssueCols.add(c);
      }
    }

    // الإجابات
    final answers = <AnswerReading>[];
    final flags = <ReviewFlagLite>[];
    for (var qi = 0; qi < template.questions.length; qi++) {
      final slot = template.questions[qi];
      final idx = <int>[]; final fv = <double>[]; final sv = <double>[]; final pv = <List<double>>[];
      final mv = <double>[];
      for (var i = 0; i < flat.length; i++) {
        if (flat[i].role == 'code' || flat[i].role == 'digit') continue;
        if (flat[i].index != qi) continue;
        idx.add(flat[i].option); fv.add(fill[i]); sv.add(fillSoft[i]); pv.add(pts[i]); mv.add(meanInk[i]);
      }
      final orderQ = List<int>.generate(idx.length, (i) => i)..sort((a, b) => fv[b].compareTo(fv[a]));
      final best = orderQ.first;
      final second = orderQ.length > 1 ? orderQ[1] : null;
      final high = orderQ.where((i) => fv[i] >= th.tHigh).toList();

      int? chosen;
      var status = 'ok';
      String? reason;

      if (high.isEmpty) {
        final softMarks = orderQ.where((i) => sv[i] >= 0.45 && meanInk[i] >= 0.05).toList();
        if (fv[best] >= th.tLight) {
          status = 'light'; chosen = idx[best]; reason = 'تظليل خفيف';
        } else if (softMarks.length == 1) {
          status = 'light'; chosen = idx[softMarks.first]; reason = 'تظليل باهت';
        } else if (softMarks.length > 1) {
          status = 'ambiguous'; reason = 'أثر تظليل على أكثر من دائرة';
        } else {
          status = 'blank'; reason = 'لم يُظلَّل';
        }
      } else if (high.length == 1) {
        chosen = idx[high.first];
        final margin = fv[high.first] - (second != null ? fv[second] : 0);
        if (margin < 0.12) { status = 'ambiguous'; reason = 'تظليل غير واضح'; }
      } else {
        status = 'ambiguous'; reason = 'أكثر من دائرة مظلّلة';
      }

      final anyGlare = orderQ.any((i) => glares[i] > 0.5 && fv[i] < th.tHigh);
      if (anyGlare && status != 'ok') {
        reason = (reason == null ? '' : '$reason + ') + 'لمعان على الفقاعة';
      }

      final byOption = List<int>.generate(idx.length, (i) => i)..sort((a, b) => idx[a].compareTo(idx[b]));
      final ans = AnswerReading(
        index: qi, type: slot.type, option: chosen, status: status, reason: reason,
        fill: fv[best],
        fills: byOption.map((i) => fv[i]).toList(),
        fillSofts: byOption.map((i) => sv[i]).toList(),
        bubblePoints: byOption.map((i) => pv[i]).toList(),
      );
      answers.add(ans);
      if (status != 'ok') flags.add(ReviewFlagLite(qi, status, reason ?? ''));
    }

    if (glareRatio > th.maxGlareRatio) {
      flags.add(ReviewFlagLite(-2, 'glare', 'لمعان قوي على الورقة — غيّر زاوية الإضاءة'));
    }
    if (edgeWidthMm > th.warnEdgeWidthMm) {
      flags.add(ReviewFlagLite(-3, 'blurry', 'الصورة غير واضحة قليلًا — ثبّت يدك أو قرّب الكاميرا'));
    }
    final lowRes = pxPerMm < th.lowPxPerMm;
    if (lowRes) flags.add(ReviewFlagLite(-1, 'lowres', 'دقة كاميرا منخفضة — تحقّق من رقم الجلوس'));

    final weak = answers.where((a) => a.status != 'ok').length;
    final confidence = math.max(0.0, 1 - weak / math.max(1, answers.length));

    return SheetReading(
      ok: true,
      quality: quality,
      code: CodeReading(value: codeVal, serial: serial, isKeySheet: isKeySheet, margin: codeMargin),
      digits: digits,
      digitReadings: digitReadings,
      digitFills: digitFills,
      digitIssues: digitIssueCols,
      answers: answers,
      flags: flags,
      confidence: confidence,
      mirrored: fid.mirrored,
      orientationScore: fid.appearance,
      lowRes: lowRes,
      corners: dst,
      elapsedMs: DateTime.now().difference(t0).inMilliseconds,
    );
  }

}

/* ------------------------------------------------------------------ */
/* تنفيذ الخطوات                                                       */
/* ------------------------------------------------------------------ */

class _Illumination {
  _Illumination(this.corrected, this.background, this.radius);
  final Uint8List corrected;
  final Float32List background;
  final int radius;

  /// تصحيح الإضاءة: قسمة الصورة على تقدير الخلفية (مصفاة صندوقية كبيرة).
  /// يرفع الأداء ويجعل العتبات نسبية لا مطلقة (مهم للظلال وإضاءة الصفوف).
  static _Illumination correct(Uint8List gray, int w, int h, EngineThresholds th) {
    final radius = math.max(6, (w * th.bgRadiusFactor).round());
    final bg = _boxBlur(gray, w, h, radius);
    final out = Uint8List(w * h);
    for (var i = 0; i < out.length; i++) {
      final b = bg[i];
      final v = b >= 60 ? (gray[i] * 255.0) / b : gray[i].toDouble();
      out[i] = v > 255 ? 255 : (v < 0 ? 0 : v.toInt());
    }
    return _Illumination(out, bg, radius);
  }

  static Float32List _boxBlur(Uint8List gray, int w, int h, int r) {
    final integral = Float64List((w + 1) * (h + 1));
    for (var y = 0; y < h; y++) {
      var rowSum = 0.0;
      final rowOff = (y + 1) * (w + 1);
      final prevOff = y * (w + 1);
      for (var x = 0; x < w; x++) {
        rowSum += gray[y * w + x];
        integral[rowOff + x + 1] = integral[prevOff + x + 1] + rowSum;
      }
    }
    final out = Float32List(w * h);
    for (var y = 0; y < h; y++) {
      final y0 = math.max(0, y - r), y1 = math.min(h - 1, y + r);
      for (var x = 0; x < w; x++) {
        final x0 = math.max(0, x - r), x1 = math.min(w - 1, x + r);
        final a = integral[y0 * (w + 1) + x0];
        final b = integral[y0 * (w + 1) + x1 + 1];
        final c = integral[(y1 + 1) * (w + 1) + x0];
        final d = integral[(y1 + 1) * (w + 1) + x1 + 1];
        final n = (x1 - x0 + 1) * (y1 - y0 + 1);
        out[y * w + x] = (a - b - c + d) / n;
      }
    }
    return out;
  }
}

int _otsu(Uint8List gray) {
  final hist = List<int>.filled(256, 0);
  for (final v in gray) {
    hist[v]++;
  }
  final total = gray.length;
  var sum = 0.0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  var sumB = 0.0, wB = 0, best = 0.0, thr = 128;
  for (var t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB == 0) continue;
    final wF = total - wB;
    if (wF == 0) break;
    sumB += t * hist[t];
    final mB = sumB / wB, mF = (sum - sumB) / wF;
    final between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) { best = between; thr = t; }
  }
  return thr;
}

class _Component {
  _Component(this.id, this.area, this.minX, this.maxX, this.minY, this.maxY, this.fill, this.cx, this.cy);
  final int id, area, minX, maxX, minY, maxY;
  final double fill, cx, cy;
  int get bw => maxX - minX + 1;
  int get bh => maxY - minY + 1;
}

List<_Component> _connectedComponents(Uint8List mask, int w, int h, int minArea) {
  final label = Int32List(w * h)..fillRange(0, w * h, -1);
  final stack = Int32List(w * h);
  final comps = <_Component>[];
  for (var start = 0; start < mask.length; start++) {
    if (mask[start] == 0 || label[start] != -1) continue;
    final id = comps.length;
    var sp = 0;
    stack[sp++] = start;
    label[start] = id;
    var area = 0, minX = w, maxX = -1, minY = h, maxY = -1;
    var sumX = 0.0, sumY = 0.0;
    while (sp > 0) {
      final p = stack[--sp];
      final x = p % w, y = p ~/ w;
      area++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      sumX += x; sumY += y;
      for (var dy = -1; dy <= 1; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx;
          if (nx < 0 || nx >= w) continue;
          final qi = ny * w + nx;
          if (mask[qi] != 0 && label[qi] == -1) {
            label[qi] = id;
            stack[sp++] = qi;
          }
        }
      }
    }
    if (area >= minArea) {
      final bw = maxX - minX + 1, bh = maxY - minY + 1;
      comps.add(_Component(id, area, minX, maxX, minY, maxY, area / (bw * bh), sumX / area, sumY / area));
    }
  }
  return comps;
}

/* ------------------------------------------------------------------ */
/* التجانس (Homography)                                                */
/* ------------------------------------------------------------------ */

List<double>? solveHomography(List<List<double>> src, List<List<double>> dst) {
  final a = List<List<double>>.generate(8, (_) => List<double>.filled(8, 0));
  final b = List<double>.filled(8, 0);
  for (var i = 0; i < 4; i++) {
    final x = src[i][0], y = src[i][1], u = dst[i][0], v = dst[i][1];
    a[2 * i] = [x, y, 1, 0, 0, 0, -x * u, -y * u];
    b[2 * i] = u;
    a[2 * i + 1] = [0, 0, 0, x, y, 1, -x * v, -y * v];
    b[2 * i + 1] = v;
  }
  for (var col = 0; col < 8; col++) {
    var piv = col;
    for (var r = col + 1; r < 8; r++) {
      if (a[r][col].abs() > a[piv][col].abs()) piv = r;
    }
    if (a[piv][col].abs() < 1e-12) return null;
    if (piv != col) {
      final tmp = a[piv]; a[piv] = a[col]; a[col] = tmp;
      final tb = b[piv]; b[piv] = b[col]; b[col] = tb;
    }
    final d = a[col][col];
    for (var c = col; c < 8; c++) {
      a[col][c] /= d;
    }
    b[col] /= d;
    for (var r = 0; r < 8; r++) {
      if (r == col) continue;
      final f = a[r][col];
      if (f == 0) continue;
      for (var c = col; c < 8; c++) {
        a[r][c] -= f * a[col][c];
      }
      b[r] -= f * b[col];
    }
  }
  return [...b, 1.0];
}

List<double> applyH(List<double> h, double x, double y) {
  final d = h[6] * x + h[7] * y + h[8];
  return [(h[0] * x + h[1] * y + h[2]) / d, (h[3] * x + h[4] * y + h[5]) / d];
}

/* ------------------------------------------------------------------ */
/* علامات التسجيل                                                      */
/* ------------------------------------------------------------------ */

class _FidResult {
  _FidResult({required this.ok, this.reason, this.cornersPx, this.homography, this.appearance = 0, this.mirrored = false});
  final bool ok;
  final String? reason;
  final List<List<double>>? cornersPx;
  final List<double>? homography;
  final double appearance;
  final bool mirrored;
}

_FidResult _findFiducials(
  List<_Component> comps, Uint8List mask, Uint8List gray, int w, int h, EngineThresholds th,
) {
  // ملاحظة: علامة «الحلقة» تُطابق بالفحص البصري لا بالشكل، لأن تظليل الطالب الكثيف يشبهها.
  final imgArea = w * h;
  final cand = comps.where((c) {
    if (c.area > th.maxComponentArea * imgArea) return false;
    if (c.area < math.max(40, (0.00003 * imgArea).round())) return false;
    if (c.fill < 0.35) return false;
    final ar = c.bw / c.bh;
    return ar >= 0.5 && ar <= 2.0;
  }).toList()
    ..sort((a, b) => b.area.compareTo(a.area));
  final list = cand.take(18).toList();
  if (list.length < 4) {
    return _FidResult(ok: false, reason: 'لم أجد علامات التسجيل — تأكّد من ظهور أركان الورقة الأربعة');
  }

  final ideal = kFiducialPitchXMm / kFiducialPitchYMm;
  final src = <List<double>>[kFiducialCenters[0], kFiducialCenters[1], kFiducialCenters[2], kFiducialCenters[3]];
  _BestFid? best;

  for (var i = 0; i < list.length; i++) {
    for (var j = i + 1; j < list.length; j++) {
      for (var k = j + 1; k < list.length; k++) {
        for (var l = k + 1; l < list.length; l++) {
          final four = [list[i], list[j], list[k], list[l]];
          // ترتيب أولي حسب موضع الركن في الصورة (يعمل مع الدوران حتى ±45°)
          final A = four.reduce((a, b) => (a.cx + a.cy <= b.cx + b.cy ? a : b));
          final B = four.reduce((a, b) => (a.cx - a.cy >= b.cx - b.cy ? a : b));
          final C = four.reduce((a, b) => (a.cx + a.cy >= b.cx + b.cy ? a : b));
          final D = four.reduce((a, b) => (a.cx - a.cy <= b.cx - b.cy ? a : b));
          if ({A.id, B.id, C.id, D.id}.length != 4) continue;

          final quadArea = _polygonArea([[A.cx, A.cy], [B.cx, B.cy], [C.cx, C.cy], [D.cx, D.cy]]).abs();
          if (quadArea < th.minPaperCoverage * imgArea) continue;

          // العلامات الأربع مطبوعة بنفس الحجم: قيد حاسم لرفض «بقعة تظليل» تتسلّل كركن
          final sides = four.map((c) => (c.bw + c.bh) / 2).toList();
          final meanSide = sides.reduce((a, b) => a + b) / 4;
          if (sides.any((s) => s < meanSide * 0.62 || s > meanSide * 1.6)) continue;
          final maxA = four.map((c) => c.area).reduce(math.max);
          if (four.any((c) => c.area < maxA * 0.42)) continue;

          final sTop = _dist([A.cx, A.cy], [B.cx, B.cy]);
          final sBottom = _dist([D.cx, D.cy], [C.cx, C.cy]);
          final sLeft = _dist([A.cx, A.cy], [D.cx, D.cy]);
          final sRight = _dist([B.cx, B.cy], [C.cx, C.cy]);
          if ([sTop, sBottom, sLeft, sRight].reduce(math.min) <= 4) continue;
          final skew = ((sTop + sBottom) / (sLeft + sRight) - ideal).abs() / ideal;
          if (skew > th.maxSideSkew) continue;
          if ((sTop - sBottom).abs() / math.max(sTop, sBottom) > 0.35) continue;
          if ((sLeft - sRight).abs() / math.max(sLeft, sRight) > 0.35) continue;

          // ثلاثة فروض للاتجاه: مباشر، دوران 180°، صورة معكوسة
          final assignments = [
            [A, B, C, D], [C, D, A, B], [B, A, D, C],
          ];
          for (final asg in assignments) {
            final hom = solveHomography(src, asg.map((c) => [c.cx, c.cy]).toList());
            if (hom == null) continue;
            final app = _probeAppearance(mask, w, h, hom);
            final score = quadArea * app * app;
            if (best == null || score > best.score) {
              best = _BestFid(score, app, asg, hom, quadArea);
            }
          }
        }
      }
    }
  }

  if (best == null) return _FidResult(ok: false, reason: 'لم أتعرّف على الورقة — افرد الورقة وصوّر أركانها الأربعة');
  if (best.appearance < 0.75) {
    return _FidResult(ok: false, reason: 'لم أتأكّد من اتجاه الورقة — أعد التصوير مع ظهور المربعات الأربعة كاملة');
  }

  var corners = best.corners;
  var hom = best.homography;
  var appearance = best.appearance;

  // تحسين المراكز على الصورة الخام (يتجنّب هالة تصحيح الإضاءة) ثم إعادة حساب التجانس
  final pxPerMm0 = _dist([corners[0].cx, corners[0].cy], [corners[1].cx, corners[1].cy]) / kFiducialPitchXMm;
  if (pxPerMm0 > 2) {
    final refined = <_Component>[];
    for (var i = 0; i < 4; i++) {
      final c = corners[i];
      final win = i == kRingIndex ? 5.0 : 6.0;
      final p = _refineCenter(gray, w, h, c.cx, c.cy, win, pxPerMm0);
      refined.add(_Component(c.id, c.area, c.minX, c.maxX, c.minY, c.maxY, c.fill, p[0], p[1]));
    }
    final hom2 = solveHomography(src, refined.map((c) => [c.cx, c.cy]).toList());
    if (hom2 != null) {
      final app2 = _probeAppearance(mask, w, h, hom2);
      if (app2 >= appearance - 0.08) {
        hom = hom2; appearance = app2; corners = refined;
      }
    }
  }

  final mirrored = _polygonArea(corners.map((c) => [c.cx, c.cy]).toList()) < 0;
  return _FidResult(
    ok: true,
    cornersPx: corners.map((c) => [c.cx, c.cy]).toList(),
    homography: hom,
    appearance: appearance,
    mirrored: mirrored,
  );
}

class _BestFid {
  _BestFid(this.score, this.appearance, this.corners, this.homography, this.quadArea);
  final double score, appearance, quadArea;
  final List<_Component> corners;
  final List<double> homography;
}

/// تحسين دقيق للمركز بعتبة محلية + مركز ثقل (يقاوم ميل الإضاءة والظلال).
List<double> _refineCenter(Uint8List img, int w, int h, double cx, double cy, double winMm, double pxPerMm) {
  var x0c = cx, y0c = cy;
  for (var iter = 0; iter < 3; iter++) {
    final half = math.max(6, (winMm * pxPerMm).round());
    final x0 = math.max(0, (x0c - half).floor()), x1 = math.min(w - 1, (x0c + half).ceil());
    final y0 = math.max(0, (y0c - half).floor()), y1 = math.min(h - 1, (y0c + half).ceil());
    final vals = <int>[];
    for (var y = y0; y <= y1; y += 2) {
      for (var x = x0; x <= x1; x += 2) {
        vals.add(img[y * w + x]);
      }
    }
    if (vals.length < 20) return [cx, cy];
    final lo = _percentile(vals, 5), hi = _percentile(vals, 95);
    if (hi - lo < 20) return [cx, cy];
    final thr = lo + 0.5 * (hi - lo);
    var sx = 0.0, sy = 0.0, n = 0;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (img[y * w + x] < thr) { sx += x; sy += y; n++; }
      }
    }
    if (n < 20) return [cx, cy];
    final nx = sx / n, ny = sy / n;
    final moved = math.sqrt((nx - x0c) * (nx - x0c) + (ny - y0c) * (ny - y0c));
    x0c = nx; y0c = ny;
    if (moved < 0.3) break;
  }
  return [x0c, y0c];
}

/// يفحص مظهر العلامات: ثلاثة أسود مصمتة + مربع حلقي (مركز أبيض وحلقة سوداء).
/// هذا الفحص هو ما يمنع قراءة الورقة مقلوبة وما يرفض الأركان الخاطئة.
double _probeAppearance(Uint8List mask, int w, int h, List<double> hom) {
  double darkRatioIn(double mmX, double mmY, double rMm) {
    final p = applyH(hom, mmX, mmY);
    final e = applyH(hom, mmX + 1, mmY);
    final sc = math.sqrt((e[0] - p[0]) * (e[0] - p[0]) + (e[1] - p[1]) * (e[1] - p[1]));
    final rad = math.max(1.0, rMm * sc);
    var dark = 0, total = 0;
    for (var y = (p[1] - rad).floor(); y <= (p[1] + rad).ceil(); y++) {
      for (var x = (p[0] - rad).floor(); x <= (p[0] + rad).ceil(); x++) {
        if (x < 0 || y < 0 || x >= w || y >= h) continue;
        final dx = x - p[0], dy = y - p[1];
        if (dx * dx + dy * dy > rad * rad) continue;
        total++;
        if (mask[y * w + x] != 0) dark++;
      }
    }
    return total == 0 ? 0 : dark / total;
  }

  double solid(double x, double y) => darkRatioIn(x, y, 2.4);
  double ring(double x, double y) {
    final innerWhite = (1 - darkRatioIn(x, y, 1.3)).clamp(0.0, 1.0);
    final inBand = (darkRatioIn(x, y, 3.0) - darkRatioIn(x, y, 2.2)).clamp(0.0, 1.0);
    return innerWhite * (inBand * 2.2).clamp(0.0, 1.0);
  }

  final probes = [solid(13, 13), solid(197, 13), solid(13, 284), ring(197, 284)];
  return probes.reduce((a, b) => a + b) / probes.length;
}

/* ------------------------------------------------------------------ */
/* أخذ العيّنات والقرار                                                */
/* ------------------------------------------------------------------ */

class _Sample {
  _Sample(this.fill, this.fillSoft, this.glare, this.x, this.y, this.localWhite, this.inkThr, this.meanInk);
  final double fill, fillSoft, glare, x, y, localWhite, inkThr;

  /// عتامة متوسطة بالنسبة لبياض الورق المحلي (تلتقط التظليل الباهت الذي لا يبلغ عتبة الحبر).
  final double meanInk;
}

_Sample _sampleBubble(
  Uint8List corrected, Uint8List gray, int w, int h, List<double> hom, Bubble b, double whiteRef, EngineThresholds th,
) {
  final c = applyH(hom, b.x, b.y);
  final e = applyH(hom, b.x + 1, b.y);
  final f = applyH(hom, b.x, b.y + 1);
  final sc = math.sqrt((e[0] - c[0]) * (e[0] - c[0]) + (e[1] - c[1]) * (e[1] - c[1]));
  final sy = math.sqrt((f[0] - c[0]) * (f[0] - c[0]) + (f[1] - c[1]) * (f[1] - c[1]));
  final scale = math.max(0.05, (sc + sy) / 2);            // بكسل/مم
  final rUnit = math.max(0.6, b.r * scale);               // نصف قطر الفقاعة بالبكسل

  var rIn = rUnit * th.ringInner, rOut = rUnit * th.ringOuter;
  if (rOut - rIn < 1.2) {
    final rm = (rIn + rOut) / 2;
    rIn = math.max(0, rm - 0.6); rOut = rm + 0.6;
  }
  // حلقة البياض المحلي: خارج الدائرة المطبوعة (لا تدخل الخط المطبوع)
  final wIn = rUnit * 1.2, wOut = rUnit * 1.5;
  final maxR = math.max(rOut, wOut);

  final x0 = math.max(0, (c[0] - maxR).floor()), x1 = math.min(w - 1, (c[0] + maxR).ceil());
  final y0 = math.max(0, (c[1] - maxR).floor()), y1 = math.min(h - 1, (c[1] + maxR).ceil());

  final vals = <int>[], outer = <int>[];
  var total = 0, sum = 0.0, glare = 0;
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final dx = x - c[0], dy = y - c[1];
      final d2 = dx * dx + dy * dy;
      final i = y * w + x;
      if (d2 <= rOut * rOut && d2 >= rIn * rIn) {
        total++;
        vals.add(corrected[i]);
        sum += corrected[i];
      } else if (d2 > wIn * wIn && d2 <= wOut * wOut) {
        outer.add(corrected[i]);
      }
    }
  }
  if (total == 0) return _Sample(0, 0, 0, c[0], c[1], whiteRef, whiteRef, 0);

  final localWhite = outer.length >= 6 ? _percentile(outer, 75).toDouble() : whiteRef;
  final inkThr = math.max(0.45 * whiteRef, math.min(whiteRef, localWhite) * th.inkRatio);
  final softThr = math.min(localWhite - th.softMinContrast, localWhite * th.softInkRatio);
  final glareThr = math.min(252.0, localWhite + 10);

  var dark = 0, soft = 0;
  for (final v in vals) {
    if (v < inkThr) dark++;
    if (v < softThr) soft++;
  }
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final dx = x - c[0], dy = y - c[1];
      final d2 = dx * dx + dy * dy;
      if (d2 > rOut * rOut || d2 < rIn * rIn) continue;
      if (gray[y * w + x] > glareThr) glare++;
    }
  }

  final meanInk = 1 - (sum / total) / math.max(1.0, localWhite);
  return _Sample(dark / total, soft / total, glare / total, c[0], c[1], localWhite, inkThr, meanInk);
}

/* ------------------------------------------------------------------ */
/* أدوات رقميّة صغيرة                                                  */
/* ------------------------------------------------------------------ */

int _percentile(List<int> values, int p) {
  final a = [...values]..sort();
  final idx = ((p / 100) * (a.length - 1)).round().clamp(0, a.length - 1);
  return a[idx];
}

double _dist(List<double> a, List<double> b) {
  final dx = a[0] - b[0], dy = a[1] - b[1];
  return math.sqrt(dx * dx + dy * dy);
}

/// مساحة مضلّع (موجبة = دوران باتجاه عقارب الساعة في إحداثيات الصورة).
double _polygonArea(List<List<double>> pts) {
  var s = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    s += p[0] * q[1] - q[0] * p[1];
  }
  return s / 2;
}

double _laplacianVariance(Uint8List gray, int w, int h, int x0, int y0, int x1, int y1) {
  final vals = <double>[];
  for (var y = y0 + 1; y < y1 - 1; y += 2) {
    for (var x = x0 + 1; x < x1 - 1; x += 2) {
      final c = gray[y * w + x];
      vals.add((4 * c - gray[(y - 1) * w + x] - gray[(y + 1) * w + x] - gray[y * w + x - 1] - gray[y * w + x + 1]).toDouble());
    }
  }
  if (vals.length < 10) return 0;
  final mean = vals.reduce((a, b) => a + b) / vals.length;
  final varr = vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / vals.length;
  return varr;
}

/// عرض انتقال حبر→ورق على حافة مربّع التسجيل (بالمليمتر) — مقياس وضوح مرتبط بالمهمّة.
double _measureEdgeWidthMm(Uint8List corrected, int w, int h, List<double> hom, double pxPerMm) {
  final widths = <double>[];
  for (final dy in [-2.5, 0.0, 2.5]) {
    final yMm = kFiducialCenters[0][1] + dy;
    final p0 = applyH(hom, kFiducialCenters[0][0] - kFiducialSize / 2 - 2.5, yMm);
    final p1 = applyH(hom, kFiducialCenters[0][0] + kFiducialSize / 2 + 2.5, yMm);
    final len = math.sqrt((p1[0] - p0[0]) * (p1[0] - p0[0]) + (p1[1] - p0[1]) * (p1[1] - p0[1]));
    final n = math.max(12, len.round());
    final vals = <int>[];
    for (var i = 0; i < n; i++) {
      final t = i / (n - 1);
      final x = (p0[0] + (p1[0] - p0[0]) * t).round();
      final y = (p0[1] + (p1[1] - p0[1]) * t).round();
      vals.add((x >= 0 && y >= 0 && x < w && y < h) ? corrected[y * w + x] : 255);
    }
    final hi = _percentile(vals, 92), lo = _percentile(vals, 8);
    if (hi - lo < 25) continue;
    final tDark = lo + 0.1 * (hi - lo), tLight = lo + 0.9 * (hi - lo);
    final sampleMm = len / (n - 1) / pxPerMm;
    var iA = -1, iB = -1;
    for (var i = 0; i < n; i++) {
      if (vals[i] <= tLight) { iA = i; break; }
    }
    if (iA >= 0) {
      for (var i = iA; i < n; i++) {
        if (vals[i] <= tDark) { iB = i; break; }
      }
    }
    if (iA >= 0 && iB >= 0) widths.add((iB - iA + 1) * sampleMm);
    if (iB >= 0) {
      var iC = -1, iD = -1;
      for (var i = iB; i < n; i++) {
        if (vals[i] >= tLight) { iC = i; break; }
      }
      if (iC >= 0) {
        for (var i = iC; i >= iB; i--) {
          if (vals[i] <= tDark) { iD = i; break; }
        }
      }
      if (iC >= 0 && iD >= 0) widths.add((iC - iD + 1) * sampleMm);
    }
  }
  if (widths.isEmpty) return 99;
  widths.sort();
  return widths[widths.length ~/ 2];
}
