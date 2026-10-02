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

    final pw = template.paperW, ph = template.paperH;
    canvas.drawRect(Rect.fromLTWH(0, 0, pw * s, ph * s), Paint()..color = Colors.white);

    // إطار خفيف يساعد على التأكد من حدود الطباعة
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, pw * s - 1, ph * s - 1),
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
      for (var x = 0.0; x <= pw; x += 10) {
        canvas.drawLine(mm(x, 0), mm(x, ph), p);
      }
      for (var y = 0.0; y <= ph; y += 10) {
        canvas.drawLine(mm(0, y), mm(pw, y), p);
      }
    }
  }

  void _paintFiducials(Canvas canvas, double s) {
    for (final f in template.fiducials) {
      final rect = Rect.fromCenter(
        center: Offset(f.x * s, f.y * s),
        width: kFiducialSize * s,
        height: kFiducialSize * s,
      );
      canvas.drawRect(rect, Paint()..color = Colors.black);
      if (f.role == 'ring') {
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
    final right = kHeaderRight * s;
    _text(canvas, template.title.isEmpty ? 'اختبار' : template.title, Offset(right, 26 * s), sizeMm: 4.6, s: s, bold: true, right: true);
    final line2 = [template.subject, template.gradeLabel].where((e) => e.isNotEmpty).join('  —  ');
    if (line2.isNotEmpty) {
      _text(canvas, line2, Offset(right, 33.5 * s), sizeMm: 3.3, s: s, right: true);
    }
    _text(canvas, 'التاريخ: ${template.examDate.isEmpty ? '—' : template.examDate}     المعلم: ${template.teacher.isEmpty ? '—' : template.teacher}',
        Offset(right, 38.5 * s), sizeMm: 2.6, s: s, right: true, color: const Color(0xFF333333));

    _text(canvas, kCodeCaption, Offset(SheetGeometry.codeLabelX * s, SheetGeometry.codeLabelY * s),
        sizeMm: 2.2, s: s, right: true, color: const Color(0xFF555555));

    for (var i = 0; i < kSheetInstructions.length; i++) {
      _text(canvas, kSheetInstructions[i], Offset(right, (55.5 + i * 4.5) * s), sizeMm: 2.2, s: s, right: true, color: const Color(0xFF444444));
    }

    // خط الفصل بين الترويسة وبقية الورقة
    canvas.drawLine(
      Offset(kHeaderLeft * s, kHeaderDividerY * s), Offset(kHeaderRight * s, kHeaderDividerY * s),
      Paint()..color = const Color(0xFF999999)..strokeWidth = math.max(0.5, 0.15 * s),
    );
    _text(canvas, kIdCaption, Offset(SheetGeometry.idCaptionX * s, SheetGeometry.idCaptionY * s), sizeMm: 2.9, s: s, bold: true, right: true);
    _text(canvas, kIdHint, Offset(SheetGeometry.idHintX * s, SheetGeometry.idHintY * s), sizeMm: 1.9, s: s, color: const Color(0xFF555555));
  }

  void _paintQuestions(Canvas canvas, double s) {
    for (final q in template.questions) {
      final rect = Rect.fromLTWH(q.numberX * s, q.numberY * s, SheetGeometry.numberBoxW * s, q.numberH * s);
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF8A9A98)..style = PaintingStyle.stroke..strokeWidth = math.max(0.5, 0.15 * s),
      );
      _text(canvas, '${q.index + 1}', rect.center, sizeMm: math.min(3.0, q.numberH * 0.55), s: s, bold: true, center: true);

      for (final b in q.bubbles) {
        final c = Offset(b.x * s, b.y * s);
        canvas.drawCircle(
          c, b.r * s,
          Paint()..color = const Color(0xFF222222)..style = PaintingStyle.stroke..strokeWidth = math.max(0.8, 0.30 * s),
        );
        _text(canvas, b.label, c + Offset(0, 0.05 * s), sizeMm: math.min(q.type == 'yesno' ? 2.6 : 2.5, b.r * 0.95), s: s,
            color: const Color(0xFF333333), center: true);
      }
    }
  }

  void _paintFooter(Canvas canvas, double s) {
    _text(
      canvas,
      '$kFooterNote  ·  رمز الورقة ${template.serial}${template.isKey ? ' (مفتاح)' : ''}',
      Offset(template.paperW / 2 * s, SheetGeometry.footerY * s),
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
  final w = (template.paperW * pxPerMm).round();
  final h = (template.paperH * pxPerMm).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  SheetPainter(template: template, pxPerMm: pxPerMm, showDebugGrid: debug).paint(canvas, Size(w.toDouble(), h.toDouble()));
  final picture = recorder.endRecording();
  return picture.toImage(w, h);
}
