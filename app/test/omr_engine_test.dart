/// اختبارات محرّك القراءة — تبني ورقة اصطناعية في الذاكرة وتتحقّق من كل القراءات.
///
/// التشغيل:  flutter test
///
/// الحالات المغطّاة:
///   • قراءة سليمة (رقم الجلوس + رمز الورقة + كل الإجابات)
///   • ميل إضاءة + ضوضاء (العتبات النسبية يجب أن تصمد)
///   • ورقة مقلوبة 180° (فرض الاتجاه عبر المربع الحلقي)
///   • تظليل خفيف (تظليل باهت يُقرأ مع وسم مراجعة، لا يُقرأ كفراغ)
///   • تظليل مزدوج (يُوسم «أكثر من دائرة مظلّلة» ولا يُخمَّن)
///   • ورقة مفتاح (بتّة المفتاح في رمز الورقة)
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:musahhih/vision/omr_engine.dart';
import 'package:musahhih/vision/template.dart';

const double pxPerMm = 4.0;
const int imgW = (210 * pxPerMm).round();
const int imgH = (297 * pxPerMm).round();

/// ورقة اصطناعية: نرسم الفقاعات والعلامات فقط (لا نحتاج خطوطًا للاختبار).
class TestSheet {
  TestSheet({required this.serial, required this.isKey, required this.questions, this.idDigits = 8});
  final int serial;
  final bool isKey;
  final List<({String type, int options})> questions;
  final int idDigits;

  late final SheetTemplate template = buildTemplate(
    title: 'اختبار اختبار',
    serial: serial,
    isKey: isKey,
    idDigits: idDigits,
    questions: questions,
  );

  /// يرسم الورقة: [studentNumber] و[marks] (فهرس السؤال → الخيارات المظلّلة).
  Uint8List render({
    required int studentNumber,
    required Map<int, List<int>> marks,
    Map<int, double> markAlpha = const {}, // عتامة التظليل لكل سؤال (0.2 = باهت)
    double lightingGradient = 0.0,
    double noise = 0.0,
    bool rotate180 = false,
    int? seed,
  }) {
    final gray = Uint8List(imgW * imgH);
    for (var i = 0; i < gray.length; i++) {
      gray[i] = 255;
    }
    // علامات التسجيل
    for (var i = 0; i < kFiducialCenters.length; i++) {
      final c = kFiducialCenters[i];
      _fillRect(gray, c[0], c[1], kFiducialSize, kFiducialSize, 0);
      if (i == kRingIndex) {
        _fillRect(gray, c[0], c[1], kFiducialHole, kFiducialHole, 255);
      }
    }
    // فقاعات: خط رقيق فقط (لتشابه الورقة المطبوعة الحقيقية)
    for (final b in template.allBubbles) {
      _ring(gray, b.x, b.y, b.r, 0.30, 120);
    }
    // رمز الورقة: البتّات المضبوطة مطبوعة مصمتة (كما في الورقة المطبوعة)
    for (final b in template.codeBubbles) {
      if (b.printed == 1) _disk(gray, b.x, b.y, b.r, 0);
    }
    // رقم الجلوس
    final digits = studentNumber.toString().padLeft(idDigits, '0');
    for (var col = 0; col < digits.length && col < idDigits; col++) {
      final d = int.parse(digits[col]);
      final bubble = template.digitBubbles.firstWhere((b) => b.index == col && b.digit == d);
      _disk(gray, bubble.x, bubble.y, bubble.r * 0.72, 25);
    }
    // الإجابات
    marks.forEach((qi, options) {
      final alpha = markAlpha[qi] ?? 1.0;
      final value = (25 + (1 - alpha) * 170).round().clamp(0, 255); // كلما قلّت العتامة زاد السطوع
      for (final o in options) {
        final bubble = template.questions[qi].bubbles[o];
        _disk(gray, bubble.x, bubble.y, bubble.r * 0.72, value);
      }
    });

    if (lightingGradient != 0) {
      for (var y = 0; y < imgH; y++) {
        for (var xx = 0; xx < imgW; xx++) {
          final f = 1 - lightingGradient * (xx / imgW);
          gray[y * imgW + xx] = (gray[y * imgW + xx] * f).round().clamp(0, 255);
        }
      }
    }
    if (noise > 0) {
      final rnd = math.Random(seed ?? 7);
      for (var i = 0; i < gray.length; i++) {
        final n = ((rnd.nextDouble() - 0.5) * 2 * noise).round();
        gray[i] = (gray[i] + n).clamp(0, 255);
      }
    }
    if (rotate180) {
      final out = Uint8List(imgW * imgH);
      for (var y = 0; y < imgH; y++) {
        for (var xx = 0; xx < imgW; xx++) {
          out[y * imgW + xx] = gray[(imgH - 1 - y) * imgW + (imgW - 1 - xx)];
        }
      }
      return out;
    }
    return gray;
  }

  void _fillRect(Uint8List gray, double cxMm, double cyMm, double wMm, double hMm, int value) {
    final x0 = ((cxMm - wMm / 2) * pxPerMm).round();
    final x1 = ((cxMm + wMm / 2) * pxPerMm).round();
    final y0 = ((cyMm - hMm / 2) * pxPerMm).round();
    final y1 = ((cyMm + hMm / 2) * pxPerMm).round();
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        if (x < 0 || y < 0 || x >= imgW || y >= imgH) continue;
        gray[y * imgW + x] = value;
      }
    }
  }

  void _ring(Uint8List gray, double cxMm, double cyMm, double rMm, double thicknessMm, int value) {
    final cx = cxMm * pxPerMm, cy = cyMm * pxPerMm;
    final r = rMm * pxPerMm;
    final t = thicknessMm * pxPerMm;
    for (var y = (cy - r - 2).floor(); y <= (cy + r + 2).ceil(); y++) {
      for (var x = (cx - r - 2).floor(); x <= (cx + r + 2).ceil(); x++) {
        if (x < 0 || y < 0 || x >= imgW || y >= imgH) continue;
        final d = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        if (d <= r + t / 2 && d >= r - t / 2) gray[y * imgW + x] = value;
      }
    }
  }

  void _disk(Uint8List gray, double cxMm, double cyMm, double rMm, int value) {
    final cx = cxMm * pxPerMm, cy = cyMm * pxPerMm;
    final r = rMm * pxPerMm;
    for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
      for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
        if (x < 0 || y < 0 || x >= imgW || y >= imgH) continue;
        if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r) gray[y * imgW + x] = value;
      }
    }
  }
}

void main() {
  final questions = <({String type, int options})>[
    (type: 'choice', options: 4),
    (type: 'choice', options: 4),
    (type: 'yesno', options: 2),
    (type: 'choice', options: 4),
    (type: 'choice', options: 4),
    (type: 'yesno', options: 2),
  ];
  final key = [2, 0, 1, 3, 0, 1];
  const studentNumber = 20260101;

  SheetReading read(TestSheet sheet, Uint8List gray) =>
      SheetReader().read(gray: gray, width: imgW, height: imgH, template: sheet.template);

  test('قراءة سليمة: رمز الورقة + رقم الجلوس + كل الإجابات', () {
    final sheet = TestSheet(serial: 3, isKey: false, questions: questions);
    final marks = <int, List<int>>{for (var i = 0; i < key.length; i++) i: [key[i]]};
    final gray = sheet.render(studentNumber: studentNumber, marks: marks);
    final r = read(sheet, gray);

    expect(r.ok, isTrue, reason: r.reason ?? '');
    expect(r.code!.value, SheetTemplate.codeValueFor(3, false));
    expect(r.code!.isKeySheet, isFalse);
    expect(r.studentNumber, studentNumber);
    expect(r.answerOptions, key);
    expect(r.flags, isEmpty);
    expect(r.quality!.pxPerMm, greaterThan(3.5));
  });

  test('ميل إضاءة + ضوضاء: القراءة نفسها', () {
    final sheet = TestSheet(serial: 5, isKey: false, questions: questions);
    final marks = <int, List<int>>{for (var i = 0; i < key.length; i++) i: [key[i]]};
    final gray = sheet.render(studentNumber: studentNumber, marks: marks, lightingGradient: 0.35, noise: 6, seed: 11);
    final r = read(sheet, gray);

    expect(r.ok, isTrue, reason: r.reason ?? '');
    expect(r.studentNumber, studentNumber);
    expect(r.answerOptions, key);
  });

  test('ورقة مقلوبة 180°: تُقرأ بالاتجاه الصحيح', () {
    final sheet = TestSheet(serial: 9, isKey: false, questions: questions);
    final marks = <int, List<int>>{for (var i = 0; i < key.length; i++) i: [key[i]]};
    final gray = sheet.render(studentNumber: studentNumber, marks: marks, rotate180: true);
    final r = read(sheet, gray);

    expect(r.ok, isTrue, reason: r.reason ?? '');
    expect(r.studentNumber, studentNumber, reason: 'يجب أن يعيد فرض الاتجاه ترتيب الأركان');
    expect(r.answerOptions, key);
  });

  test('تظليل باهت: يُقرأ مع وسم مراجعة (لا يُقرأ فراغًا)', () {
    final sheet = TestSheet(serial: 2, isKey: false, questions: questions);
    final marks = <int, List<int>>{for (var i = 0; i < key.length; i++) i: [key[i]]};
    marks[1] = [key[1]];
    final gray = sheet.render(studentNumber: studentNumber, marks: marks, markAlpha: {1: 0.35});
    final r = read(sheet, gray);

    expect(r.ok, isTrue);
    final a = r.answers[1];
    expect(a.option, key[1], reason: 'التظليل الباهت إجابة لا فراغ');
    expect(a.status, anyOf('ok', 'light'));
  });

  test('تظليل مزدوج: وسم التباس ولا تخمين', () {
    final sheet = TestSheet(serial: 4, isKey: false, questions: questions);
    final marks = <int, List<int>>{for (var i = 0; i < key.length; i++) i: [key[i]]};
    marks[2] = [0, 1];
    final gray = sheet.render(studentNumber: studentNumber, marks: marks);
    final r = read(sheet, gray);

    expect(r.ok, isTrue);
    expect(r.answers[2].status, 'ambiguous');
    expect(r.answers[2].option, isNull);
    expect(r.flags.any((f) => f.index == 2), isTrue);
    // بقية الأسئلة سليمة
    expect(r.answers[0].option, key[0]);
    expect(r.answers[5].option, key[5]);
  });

  test('ورقة مفتاح: بتّة المفتاح تُقرأ وتمنع احتساب درجة', () {
    final sheet = TestSheet(serial: 7, isKey: true, questions: questions);
    final marks = <int, List<int>>{for (var i = 0; i < key.length; i++) i: [key[i]]};
    final gray = sheet.render(studentNumber: studentNumber, marks: marks);
    final r = read(sheet, gray);

    expect(r.ok, isTrue);
    expect(r.code!.isKeySheet, isTrue);
    expect(r.code!.serial, 7);
    expect(r.answerOptions, key);
  });

  test('دقة منخفضة: رفض واضح برسالة مفهومة', () {
    final sheet = TestSheet(serial: 1, isKey: false, questions: questions);
    final marks = <int, List<int>>{for (var i = 0; i < key.length; i++) i: [key[i]]};
    final full = sheet.render(studentNumber: studentNumber, marks: marks);

    // تصغير الصورة كأن الكاميرا بعيدة: 2.2 بكسل/مم (دون حدّ 3.5)
    const targetPxPerMm = 2.2;
    final w = (210 * targetPxPerMm).round();
    final h = (297 * targetPxPerMm).round();
    final sx = imgW / w, sy = imgH / h;
    final small = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var sum = 0, n = 0;
        for (var j = (y * sy).floor(); j < ((y + 1) * sy).ceil() && j < imgH; j++) {
          for (var i = (x * sx).floor(); i < ((x + 1) * sx).ceil() && i < imgW; i++) {
            sum += full[j * imgW + i];
            n++;
          }
        }
        small[y * w + x] = n == 0 ? 255 : (sum / n).round();
      }
    }

    final r = SheetReader().read(gray: small, width: w, height: h, template: sheet.template);
    expect(r.ok, isFalse);
    expect(r.reason, isNotNull);
    expect(r.reason, contains('الدقة منخفضة'));
  });
}
