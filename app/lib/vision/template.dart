/// القالب الهندسي لورقة الإجابة — **مصدر الحقيقة** للطباعة والقراءة معًا.
///
/// أي تعديل على الإحداثيات هنا يجب أن يُطبَّق أيضًا في:
///   • demo/js/template.js   (النموذج الحي للويب)
///   • demo/test/gen_scans.py (مولّد الأوراق المصطنعة للاختبارات)
/// وإلا فسيتوقف التوافق بين ما يُطبع وما يُقرأ.
library;

import 'dart:math' as math;

const int kSchemaVersion = 1;

/// أبعاد الورقة (مم) — A4.
const double kPaperW = 210, kPaperH = 297;

/// مراكز علامات التسجيل الأربع (مم).
const List<List<double>> kFiducialCenters = [
  [13, 13], [197, 13], [197, 284], [13, 284],
];

/// نوع العلامة الرابعة (حلقي) — يميّز اتجاه الورقة حتى مع دوران 180°.
const int kRingIndex = 2;

const double kFiducialSize = 10;
const double kFiducialHole = 6;
const double kFiducialPitchXMm = 184, kFiducialPitchYMm = 271;

/// حروف الخيارات.
const List<String> kOptionLabelsAr = ['أ', 'ب', 'ج', 'د', 'هـ'];
const List<String> kOptionLabelsEn = ['A', 'B', 'C', 'D', 'E'];
const List<String> kYesNoLabels = ['نعم', 'لا'];

/// هندسة الشبكات والفقاعات (مم).
class SheetGeometry {
  // رمز الورقة: 6 فقاعات — 5 بتات لرقم الاختبار + بتة نوع الورقة (مفتاح؟)
  static const int codeCount = 6;
  static const int codeBits = 5;
  static const int codeKeyBit = 5;
  static const double codeR = 2.2, codePitch = 5.2, codeFirstX = 148, codeY = 76;

  // شبكة رقم الجلوس
  static const int idRows = 10;
  static const int idMaxCols = 8;
  static const double idColPitch = 7.0, idRowPitch = 4.7, idR = 1.9;
  static const double idFirstColX = 27.2, idFirstRowY = 41;
  static const double idBoxW = 6.4, idBoxH = 6.0, idBoxY = 31;

  // الأسئلة
  static const double qY0 = 90, qY1 = 264;
  static const int qRowsPerCol = 10;
  static const double colRightRight = 186, colRightLeft = 106;
  static const double colLeftRight = 104, colLeftLeft = 24;
  static const double numberBoxW = 13;
  static const double choiceR = 3.5, choiceMaxPitch = 14;
  static const double yesNoR = 4.0, yesNoPitch = 20;

  static const double footerY = 268;
}

class Bubble {
  Bubble({required this.x, required this.y, required this.r, required this.role, this.index = 0, this.option = 0, this.digit = 0, this.bit = 0, this.printed = 0, this.label = ''});

  final double x, y, r;
  final String role; // code | digit | question | choice | yesno
  final int index;   // رقم السؤال
  final int option;  // فهرس الخيار
  final int digit;   // رقم شبكة الجلوس
  final int bit;     // بتة رمز الورقة
  final int printed; // 1 = فقاعة مرسومة مصمتة (للمعاينة/الطباعة)
  final String label;

  Map<String, dynamic> toJson() => {
        'x': x, 'y': y, 'r': r, 'role': role, 'index': index, 'option': option,
        'digit': digit, 'bit': bit, 'printed': printed, 'label': label,
      };
}

class QuestionSlot {
  QuestionSlot({required this.index, required this.type, required this.optionCount, required this.bubbles, required this.numberX, required this.numberY});
  final int index;
  final String type; // choice | yesno
  final int optionCount;
  final List<Bubble> bubbles;
  final double numberX, numberY;
}

class SheetTemplate {
  SheetTemplate({
    required this.serial,
    required this.isKey,
    required this.title,
    required this.subject,
    required this.gradeLabel,
    required this.teacher,
    required this.examDate,
    required this.optionLabels,
    required this.fiducials,
    required this.codeBubbles,
    required this.codeValue,
    required this.digitBubbles,
    required this.digitCols,
    required this.digitBoxes,
    required this.questions,
  });

  final int serial;
  final bool isKey;
  final String title, subject, gradeLabel, teacher, examDate, optionLabels;
  final List<Bubble> fiducials;
  final List<Bubble> codeBubbles;
  final int codeValue;
  final List<Bubble> digitBubbles;
  final int digitCols;
  final List<List<double>> digitBoxes;
  final List<QuestionSlot> questions;

  /// كل الفقاعات في قائمة واحدة (لتسريع أخذ العيّنات).
  List<Bubble> get allBubbles => [
        ...codeBubbles, ...digitBubbles, ...questions.expand((q) => q.bubbles),
      ];

  static int codeValueFor(int serial, bool isKey) =>
      (serial & ((1 << SheetGeometry.codeBits) - 1)) | (isKey ? (1 << SheetGeometry.codeKeyBit) : 0);

  static String labelFor(String optionLabels, int option) =>
      option < kOptionLabelsAr.length ? (optionLabels == 'en' ? kOptionLabelsEn[option] : kOptionLabelsAr[option]) : '?';
}

/// يبني القالب من مواصفات الاختبار (نفس خوارزمية demo/js/template.js حرفيًا).
SheetTemplate buildTemplate({
  required String title,
  String subject = '',
  String gradeLabel = '',
  String teacher = '',
  String examDate = '',
  required int serial,
  bool isKey = false,
  int idDigits = 8,
  String optionLabels = 'ar',
  required List<({String type, int options})> questions,
}) {
  final fiducials = <Bubble>[];
  for (var i = 0; i < kFiducialCenters.length; i++) {
    fiducials.add(Bubble(
      x: kFiducialCenters[i][0], y: kFiducialCenters[i][1], r: kFiducialSize / 2,
      role: i == kRingIndex ? 'ring' : 'solid',
    ));
  }

  final codeValue = SheetTemplate.codeValueFor(serial, isKey);
  final codeBubbles = <Bubble>[];
  for (var b = 0; b < SheetGeometry.codeCount; b++) {
    codeBubbles.add(Bubble(
      x: SheetGeometry.codeFirstX - b * SheetGeometry.codePitch,
      y: SheetGeometry.codeY,
      r: SheetGeometry.codeR,
      role: 'code',
      bit: b,
      printed: (codeValue >> b) & 1,
    ));
  }

  final cols = idDigits.clamp(1, SheetGeometry.idMaxCols);
  final digitBubbles = <Bubble>[];
  for (var c = 0; c < cols; c++) {
    for (var row = 0; row < SheetGeometry.idRows; row++) {
      digitBubbles.add(Bubble(
        x: SheetGeometry.idFirstColX + c * SheetGeometry.idColPitch,
        y: SheetGeometry.idFirstRowY + row * SheetGeometry.idRowPitch,
        r: SheetGeometry.idR, role: 'digit', index: c, digit: row,
      ));
    }
  }
  final digitBoxes = List<List<double>>.generate(
    cols,
    (c) => [SheetGeometry.idFirstColX + c * SheetGeometry.idColPitch - SheetGeometry.idBoxW / 2, SheetGeometry.idBoxY, SheetGeometry.idBoxW, SheetGeometry.idBoxH],
  );

  const rowPitch = (SheetGeometry.qY1 - SheetGeometry.qY0) / SheetGeometry.qRowsPerCol;
  final slots = <QuestionSlot>[];
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i];
    final isYesNo = q.type == 'yesno';
    final right = i < SheetGeometry.qRowsPerCol ? SheetGeometry.colRightRight : SheetGeometry.colLeftRight;
    final left = i < SheetGeometry.qRowsPerCol ? SheetGeometry.colRightLeft : SheetGeometry.colLeftLeft;
    final y = SheetGeometry.qY0 + rowPitch * ((i % SheetGeometry.qRowsPerCol) + 0.5);
    final count = isYesNo ? 2 : q.options.clamp(2, 5);
    final r = isYesNo ? SheetGeometry.yesNoR : SheetGeometry.choiceR;
    final maxPitch = isYesNo ? SheetGeometry.yesNoPitch : SheetGeometry.choiceMaxPitch;
    final avail = (right - left) - 19 - 2 * r - 1;
    final pitch = math.min(maxPitch, avail / (count - 1));

    final bubbles = <Bubble>[];
    for (var o = 0; o < count; o++) {
      bubbles.add(Bubble(
        x: right - 19 - o * pitch,
        y: y,
        r: r,
        role: isYesNo ? 'yesno' : 'choice',
        index: i,
        option: o,
        label: isYesNo ? kYesNoLabels[o] : SheetTemplate.labelFor(optionLabels, o),
      ));
    }
    slots.add(QuestionSlot(
      index: i, type: isYesNo ? 'yesno' : 'choice', optionCount: count, bubbles: bubbles,
      numberX: right - SheetGeometry.numberBoxW, numberY: y - 6,
    ));
  }

  return SheetTemplate(
    serial: serial, isKey: isKey, title: title, subject: subject, gradeLabel: gradeLabel,
    teacher: teacher, examDate: examDate, optionLabels: optionLabels,
    fiducials: fiducials, codeBubbles: codeBubbles, codeValue: codeValue,
    digitBubbles: digitBubbles, digitCols: cols, digitBoxes: digitBoxes, questions: slots,
  );
}

/// نصّ التعليمات المطبوع على الورقة (واحد للجميع).
const List<String> kSheetInstructions = [
  'ظلّل دائرة واحدة فقط لكل سؤال باستخدام قلم رصاص أو قلم جاف أسود/أزرق.',
  'أجب بنعم أو لا: ظلّل (نعم) أو (لا). وللأسئلة الموضوعية ظلّل رمز الإجابة الصحيحة.',
  'لا تكتب أو تُظلّل خارج الدوائر، واحرص على تعبئة الدائرة كاملة.',
];
const String kIdCaption = 'رقم الجلوس';
const String kIdHint = 'اكتب رقمك في المستطيلات، ثم شبّك الرقم نفسه أسفل كل عمود';
const String kCodeCaption = 'رمز الورقة';
const String kFooterNote = 'لا تكتب في هذا القسم — تُقرأ الورقة آليًا';
