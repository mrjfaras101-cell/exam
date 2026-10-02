/// تصدير ورقة الإجابة إلى PDF وطباعتها — **نسختان في كل صفحة A4**.
///
/// الورقة صارت بنصف A4 (148.5 × 210 مم)، لذا نضع نسختين جنبًا إلى جنب
/// في صفحة A4 **أفقية** (297 × 210 مم) ونرسم خط قصّ رفيعًا في المنتصف.
/// النتيجة: لصفٍّ فيه 40 طالبًا يحتاج المعلم 20 ورقة A4 فقط.
///
/// الرسم يتم بـ CustomPainter بدقة 300 نقطة/بوصة ثم يُدمج كصورة في الورقة،
/// فلا يتحجّم شيء عند الطبع (كل فقاعة تبقى على إحداثياتها المليمترية).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../vision/template.dart';
import 'sheet_painter.dart';

class SheetPdf {
  /// يبني ملف PDF: نسختان من الورقة في كل صفحة A4 أفقية.
  static Future<Uint8List> build(
    SheetTemplate template, {
    String? title,
    int copies = 2,
    bool cropMarks = true,
  }) async {
    final png = await _renderPng(template);
    final doc = pw.Document(title: title ?? template.title, creator: 'مُصحِّح — Basem');
    final memImage = pw.MemoryImage(png);
    final perPage = copies <= 1 ? 1 : 2;

    for (var i = 0; i < copies; i += perPage) {
      final remaining = copies - i;
      doc.addPage(
        pw.Page(
          pageFormat: perPage == 2 ? PdfPageFormat.a4.landscape : const PdfPageFormat(148.5 * PdfPageFormat.mm, 210 * PdfPageFormat.mm),
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.FullPage(
            ignoreMargins: true,
            child: perPage == 2
                ? pw.Stack(children: [
                    pw.Positioned(left: 0, top: 0, child: _sheetImage(memImage)),
                    if (remaining > 1) pw.Positioned(left: 148.5 * PdfPageFormat.mm, top: 0, child: _sheetImage(memImage)),
                    if (cropMarks) pw.Positioned(left: 148.5 * PdfPageFormat.mm - 0.15, top: 0, child: _cropLine()),
                  ])
                : _sheetImage(memImage),
          ),
        ),
      );
    }
    return doc.save();
  }

  static pw.Widget _sheetImage(pw.MemoryImage image) => pw.Image(
        image,
        fit: pw.BoxFit.fill,
        width: 148.5 * PdfPageFormat.mm,
        height: 210 * PdfPageFormat.mm,
      );

  /// خط قصّ رفيع بين النسختين + علامات قصّ صغيرة أعلى وأسفل.
  static pw.Widget _cropLine() => pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Container(width: 0.3 * PdfPageFormat.mm, height: 8 * PdfPageFormat.mm, color: PdfColors.grey600),
        pw.Container(width: 0.2 * PdfPageFormat.mm, height: 210 * PdfPageFormat.mm - 16 * PdfPageFormat.mm, color: PdfColors.grey400),
        pw.Container(width: 0.3 * PdfPageFormat.mm, height: 8 * PdfPageFormat.mm, color: PdfColors.grey600),
      ]);

  static Future<Uint8List> _renderPng(SheetTemplate template) async {
    final image = await renderSheetToImage(template, pxPerMm: SheetPainter.printPxPerMm);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// يفتح نافذة الطباعة على النظام مباشرة (نسختان في الصفحة افتراضيًا).
  static Future<void> print(SheetTemplate template, {String? title, int copies = 2}) async {
    final bytes = await build(template, title: title, copies: copies);
    await Printing.layoutPdf(name: title ?? 'ورقة الإجابة', onLayout: (format) async => bytes);
  }

  /// يشارك الورقة كملف PDF (واتساب/البريد) — تُستخدم لطباعة عدة نسخ في مكتبة المدرسة.
  static Future<void> share(SheetTemplate template, {String? filename, int copies = 2}) async {
    final bytes = await build(template, title: template.title, copies: copies);
    await Printing.sharePdf(bytes: bytes, filename: filename ?? 'answer-sheet.pdf');
  }
}
