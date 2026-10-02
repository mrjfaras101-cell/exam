/// تصدير الورقة إلى PDF بمقاس A4 حقيقي (بلا أي تحجيم عند الطباعة).
///
/// الطريقة: نرسم الورقة بـ CustomPainter إلى صورة عند 300 نقطة/بوصة
/// (= 2480×3508 بكسل)، ثم نضعها في صفحة A4 كاملة. النتيجة: أي فقاعة في PDF
/// تقع على نفس الإحداثيات المليمترية التي يتوقّعها محرّك القراءة.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../vision/template.dart';
import 'sheet_painter.dart';

class SheetPdf {
  /// يبني ملف PDF لورقة إجابة (طالب أو مفتاح).
  static Future<Uint8List> build(SheetTemplate template, {String? title}) async {
    final image = await renderSheetToImage(template, pxPerMm: SheetPainter.printPxPerMm);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final png = bytes!.buffer.asUint8List();

    final doc = pw.Document(title: title ?? template.title, creator: 'مُصحِّح');
    final memImage = pw.MemoryImage(png);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Image(memImage, fit: pw.BoxFit.fill, width: PdfPageFormat.a4.width, height: PdfPageFormat.a4.height),
        ),
      ),
    );
    return doc.save();
  }

  /// يفتح نافذة الطباعة على النظام مباشرة من الورقة (أسرع مسار للمعلم).
  static Future<void> print(SheetTemplate template, {String? title}) async {
    final image = await renderSheetToImage(template, pxPerMm: SheetPainter.printPxPerMm);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final png = bytes!.buffer.asUint8List();
    await Printing.layoutPdf(
      name: title ?? 'ورقة الإجابة',
      onLayout: (format) async {
        final doc = pw.Document();
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.FullPage(ignoreMargins: true, child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill)),
        ));
        return doc.save();
      },
    );
  }

  /// يشارك الورقة كملف PDF (واتساب/البريد) — تُستخدم لطباعة عدة نسخ في مكتبة المدرسة.
  static Future<void> share(SheetTemplate template, {String? filename}) async {
    final bytes = await build(template, title: template.title);
    await Printing.sharePdf(bytes: bytes, filename: filename ?? 'answer-sheet.pdf');
  }
}
