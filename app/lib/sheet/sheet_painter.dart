/// رسم ورقة الإجابة من القالب الهندسي — مصدر واحد للمعاينة والطباعة و PDF.
///
/// لماذا CustomPainter وليس ودجات؟ لأن نفس الرسم يُستخدَم لثلاثة أغراض:
///   1) المعاينة على الشاشة
///   2) تصدير PDF بدقة 300 نقطة/بوصة (بتحويل الرسم إلى صورة A4 دقيقة بالمليمتر)
///   3) تراكب المراجعة فوق صورة الورقة الممسوحة
/// وبذلك يستحيل أن تختلف النسخة المطبوعة عن نسخة القراءة.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../vision/template.dart';

class SheetPainter extends CustomPainter {
  SheetPainter({required this.template, this.pxPerMm = 3.2, this.showDebugGrid = false});

  final SheetTemplate template;
  final double pxPerMm;
  final bool showDebugGrid;

  /// مستوى الدقة المطلوب للطباعة (300 نقطة/بوصة ≈ 11.811 نقطة/مم).
  static const double printPxPerMm = 300 / 25.4;

  @override
  void paint(Canvas canvas, Size size) {
    final s = pxPerMm;
    Offset mm(double x, double y) => Offset(x * s, y * s);
    double px(double mmValue) => mmValue * s;

    canvas.drawRect(Rect.fromLTWH(0, 0, 210 * s, 297 * s), Paint()..color = Colors.white);

    // إطار خفيف يساعد على التأكد من حدود الطباعة
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, 210 * s - 1, 297 * s - 1),
      Paint()..color = const Color(0xFFC9D3D2)..style = PaintingStyle.stroke..strokeWidth = math.max(0.5, s * 0.15),
    );

    _paintFiducials(canvas, s);
    _paintCode(canvas, s);
    _paintIdGrid(canvas, s);
    _paintHeader(canvas, s);
    _paintQuestions(canvas, s);
    _paintFooter(canvas, s);

    if (showDebugGrid) {
      final p = Paint()..color = const Color(0x33FF0000)..strokeWidth = 0.5;
      for (var x = 0; x <= 210; x += 10) {
        canvas.drawLine(mm(x.toDouble(), 0), mm(x.toDouble(), 297), p);
      }
      for (var y = 0; y <= 297; y += 10) {
        canvas.drawLine(mm(0, y.toDouble()), mm(210, y.toDouble()), p);
      }
    }
  }

  void _paintFiducials(Canvas canvas, double s) {
    for (var i = 0; i < kFiducialCenters.length; i++) {
      final c = kFiducialCenters[i];
      final rect = Rect.fromCenter(
        center: Offset(c[0] * s, c[1] * s),
        width: kFiducialSize * s,
        height: kFiducialSize * s,
      );
      canvas.drawRect(rect, Paint()..color = Colors.black);
      if (i == kRingIndex) {
        final hole = Rect.fromCenter(
          center: rect.center,
          width: kFiducialHole * s,
          height: kFiducialHole * s,
        );
        canvas.drawRect(hole, Paint()..color = Colors.white);
      }
    }
  }

  void _paintCode(Canvas canvas, double s) {
    for (final b in template.codeBubbles) {
      final c = Offset(b.x * s, b.y * s);
      if (b.printed == 1) {
        canvas.drawCircle(c, b.r * s, Paint()..color = Colors.black);
      } else {
        canvas.drawCircle(
          c, b.r * s,
          Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = math.max(0.8, 0.30 * s),
        );
      }
    }
  }

  void _paintIdGrid(Canvas canvas, double s) {
    final boxPaint = Paint()..color = const Color(0xFF333333)..style = PaintingStyle.stroke..strokeWidth = math.max(0.8, 0.28 * s);
    for (final box in template.digitBoxes) {
      canvas.drawRect(Rect.fromLTWH(box[0] * s, box[1] * s, box[2] * s, box[3] * s), boxPaint);
    }
    final bubblePaint = Paint()..color = const Color(0xFF333333)..style = PaintingStyle.stroke..strokeWidth = math.max(0.7, 0.22 * s);
    for (final b in template.digitBubbles) {
      final c = Offset(b.x * s, b.y * s);
      canvas.drawCircle(c, b.r * s, bubblePaint);
      _text(canvas, '${b.digit}', c + Offset(0, 0.05 * s), sizeMm: 1.7, s: s, color: const Color(0xFF555555), center: true);
    }
  }

  void _paintHeader(Canvas canvas, double s) {
    final right = 186 * s;
    _text(canvas, template.title.isEmpty ? 'اختبار' : template.title, Offset(right, 35 * s), sizeMm: 5.4, s: s, bold: true, right: true);
    final line2 = [template.subject, template.gradeLabel].where((e) => e.isNotEmpty).join('  —  ');
    if (line2.isNotEmpty) {
      _text(canvas, line2, Offset(right, 43 * s), sizeMm: 3.9, s: s, right: true);
    }
    _text(canvas, 'التاريخ: ${template.examDate.isEmpty ? '—' : template.examDate}     المعلم: ${template.teacher.isEmpty ? '—' : template.teacher}',
        Offset(right, 49.5 * s), sizeMm: 3.0, s: s, right: true, color: const Color(0xFF333333));

    for (var i = 0; i < kSheetInstructions.length; i++) {
      _text(canvas, kSheetInstructions[i], Offset(right, (55.6 + i * 5.2) * s), sizeMm: 2.6, s: s, right: true, color: const Color(0xFF444444));
    }

    canvas.drawLine(
      Offset(90 * s, 69 * s), Offset(186 * s, 69 * s),
      Paint()..color = const Color(0xFF999999)..strokeWidth = math.max(0.5, 0.15 * s),
    );
    _text(canvas, kCodeCaption, Offset(186 * s, 77 * s), sizeMm: 2.4, s: s, right: true, color: const Color(0xFF555555));
    _text(canvas, kIdCaption, Offset(86 * s, 34 * s), sizeMm: 3.2, s: s, bold: true, right: true);
    _text(canvas, kIdHint, Offset(24 * s, 34 * s), sizeMm: 2.3, s: s, color: const Color(0xFF555555));
  }

  void _paintQuestions(Canvas canvas, double s) {
    for (final q in template.questions) {
      final rect = Rect.fromLTWH(q.numberX * s, q.numberY * s, SheetGeometry.numberBoxW * s, 12 * s);
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF8A9A98)..style = PaintingStyle.stroke..strokeWidth = math.max(0.5, 0.15 * s),
      );
      _text(canvas, '${q.index + 1}', rect.center, sizeMm: 3.4, s: s, bold: true, center: true);

      for (final b in q.bubbles) {
        final c = Offset(b.x * s, b.y * s);
        canvas.drawCircle(
          c, b.r * s,
          Paint()..color = const Color(0xFF222222)..style = PaintingStyle.stroke..strokeWidth = math.max(0.8, 0.30 * s),
        );
        _text(canvas, b.label, c + Offset(0, 0.05 * s), sizeMm: q.type == 'yesno' ? 3.0 : 2.9, s: s,
            color: const Color(0xFF333333), center: true);
      }
    }
  }

  void _paintFooter(Canvas canvas, double s) {
    _text(
      canvas,
      '$kFooterNote  ·  رمز الورقة ${template.serial}${template.isKey ? ' (مفتاح)' : ''}',
      Offset(105 * s, SheetGeometry.footerY * s),
      sizeMm: 2.3, s: s, color: const Color(0xFF666666), center: true,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required double sizeMm,
    required double s,
    bool bold = false,
    bool center = false,
    bool right = false,
    Color color = const Color(0xFF0B1A18),
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: sizeMm * s,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: center ? TextAlign.center : (right ? TextAlign.right : TextAlign.left),
    )..layout();
    final offset = center
        ? Offset(at.dx - tp.width / 2, at.dy - tp.height / 2)
        : (right ? Offset(at.dx - tp.width, at.dy - tp.height * 0.8) : Offset(at.dx, at.dy - tp.height * 0.8));
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SheetPainter old) =>
      old.template != template || old.pxPerMm != pxPerMm || old.showDebugGrid != showDebugGrid;
}

/// يحوّل الرسم إلى صورة نقطية بدقة الطباعة (تُستخدم لتصدير PDF ومشاركة صورة الورقة).
Future<ui.Image> renderSheetToImage(SheetTemplate template, {double pxPerMm = SheetPainter.printPxPerMm, bool debug = false}) async {
  final w = (210 * pxPerMm).round();
  final h = (297 * pxPerMm).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  SheetPainter(template: template, pxPerMm: pxPerMm, showDebugGrid: debug).paint(canvas, Size(w.toDouble(), h.toDouble()));
  final picture = recorder.endRecording();
  return picture.toImage(w, h);
}
