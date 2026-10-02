/// القالب الهندسي لورقة الإجابة — **مصدر الحقيقة** للطباعة والقراءة معًا.
///
/// الورقة: **نصف ورقة A4** (148.5 × 210 مم) — تُطبع نسختان في صفحة A4 أفقية ثم تُقصّ،
/// فيطبع المعلم 20 ورقة A4 فقط لصفّ فيه 40 طالبًا.
///
/// أي تعديل على الإحداثيات هنا يجب أن يُطبَّق أيضًا في:
///   • demo/js/template.js    (النموذج الحي للويب)
///   • demo/test/gen_scans.py (مولّد الأوراق المصطنعة للاختبارات)
/// وإلا فسيتوقف التوافق بين ما يُطبع وما يُقرأ.
library;

import 'dart:math' as math;

const int kSchemaVersion = 2;

/// أبعاد الورقة (مم) — نصف A4 طولي.
const double kPaperW = 148.5, kPaperH = 210;

/// حدود كتل الترويسة (مم).
const double kHeaderDividerY = 70.5;
const double kHeaderRight = 130.5;
const double kHeaderLeft = 18;

/// مراكز علامات التسجيل الأربع (مم) بترتيب [TL, TR, BR, BL].
const List<List<double>> kFiducialCenters = [
  [10, 10], [138.5, 10], [138.5, 200], [10, 200],
];

/// نوع العلامة الثالثة (حلقي) — يميّز اتجاه الورقة حتى مع دوران 180°.
const int kRingIndex = 2;

const double kFiducialSize = 10;
const double kFiducialHole = 6;
const double kFiducialPitchXMm = 128.5, kFiducialPitchYMm = 190;

/// أقصى عدد أسئلة في الورقة (20 صفًا × عمودين).
const int kMaxQuestions = 40;

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
  static const double codeR = 2.0, codePitch = 4.8, codeFirstX = 128.5, codeY = 45;
  static const double codeLabelX = 100, codeLabelY = 46.2;

  // شبكة رقم الجلوس
  static const int idRows = 10;
  static const int idMaxCols = 8;
  static const double idColPitch = 6.2, idRowPitch = 3.8, idR = 1.7;
  static const double idFirstColX = 21.5, idFirstRowY = 31;
  static const double idBoxW = 6.0, idBoxH = 5.2, idBoxY = 23.5;
  static const double idCaptionX = 70, idCaptionY = 21;
  static const double idHintX = 18, idHintY = 68;

  // الأسئلة: عمودان يملآن الورقة (حتى 40 سؤالًا)
  static const double qY0 = 74, qY1 = 190;
  static const int maxRowsPerCol = 20;
  static const double maxRowPitch = 14;
  static const double colRightRight = 130.5, colRightLeft = 77.5;
  static const double colLeftRight = 71, colLeftLeft = 18;
  static const double numberBoxW = 9, numberBoxGap = 2.5;
  static const double choiceMaxPitch = 9.3, yesNoMaxPitch = 12;
  static const double minBubbleR = 2.2, maxBubbleR = 3.2, rowBubbleFactor = 0.42;

  static const double footerY = 192;
}

class Bubble {
  Bubble({required this.x, required this.y, required this.r, required this.role, this.index = 0, this.option = 0, this.digit = 0, this.bit = 0, this.printed = 0, this.label = '', this.id = ''});

  final double x, y, r;
  final String role; // code | digit | question | choice | yesno | solid | ring
  final int index;   // رقم السؤال
  final int option;  // فهرس الخيار
  final int digit;   // رقم شبكة الجلوس
  final int bit;     // بتة رمز الورقة
  final int printed; // 1 = فقاعة مرسومة مصمتة (للمعاينة/الطباعة)
  final String label;
  final String id;   // TL | TR | BR | BL لعلامات التسجيل

  Map<String, dynamic> toJson() => {
        'x': x, 'y': y, 'r': r, 'role': role, 'index': index, 'option': option,
        'digit': digit, 'bit': bit, 'printed': printed, 'label': label, 'id': id,
      };
}

class QuestionSlot {
  QuestionSlot({
    required this.index,
    required this.type,
    required this.optionCount,
    required this.bubbles,
    required this.numberX,
    required this.numberY,
    required this.numberH,
  });
  final int index;
  final String type; // choice | yesno
  final int optionCount;
  final List<Bubble> bubbles;
  final double numberX, numberY, numberH;
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
    required this.rowsPerCol,
    required this.rowPitch,
    required this.yStart,
    required this.bubbleR,
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

  /// تخطيط الأسئلة الفعلي (يُحسب من عدد الأسئلة).
  final int rowsPerCol;
  final double rowPitch, yStart, bubbleR;

  /// أبعاد الورقة (مم).
  double get paperW => kPaperW;
  double get paperH => kPaperH;

  /// المسافة بين مراكز علامات التسجيل (مم) — تُستخدم لتحويل بكسل ↔ مم.
  double get pitchX => kFiducialPitchXMm;
  double get pitchY => kFiducialPitchYMm;

  /// علامات التسجيل بترتيب [TL, TR, BR, BL].
  List<Bubble> get fiducialsOrdered {
    final byId = {for (final f in fiducials) f.id: f};
    return [byId['TL']!, byId['TR']!, byId['BR']!, byId['BL']!];
  }

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
  // 1) علامات التسجيل (TL, TR, BR, BL) — الرابعة حلقيّة لتمييز الاتجاه.
  const ids = ['TL', 'TR', 'BR', 'BL'];
  final fiducials = <Bubble>[];
  for (var i = 0; i < kFiducialCenters.length; i++) {
    fiducials.add(Bubble(
      x: kFiducialCenters[i][0], y: kFiducialCenters[i][1], r: kFiducialSize / 2,
      role: i == kRingIndex ? 'ring' : 'solid',
      id: ids[i],
    ));
  }

  // 2) رمز الورقة
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

  // 3) شبكة رقم الجلوس
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
    (c) => [
      SheetGeometry.idFirstColX + c * SheetGeometry.idColPitch - SheetGeometry.idBoxW / 2,
      SheetGeometry.idBoxY, SheetGeometry.idBoxW, SheetGeometry.idBoxH,
    ],
  );

  // 4) الأسئلة: عدد الصفوف يُحسب من عدد الأسئلة (حتى 20 صفًا × عمودين = 40 سؤالًا)
  final n = math.max(1, questions.length);
  const availH = SheetGeometry.qY1 - SheetGeometry.qY0;
  final rowsPerCol = math.max(1, math.min(SheetGeometry.maxRowsPerCol, (n / 2).ceil()));
  final rowPitch = math.min(SheetGeometry.maxRowPitch, availH / rowsPerCol);
  final yStart = SheetGeometry.qY0 + math.max(0.0, (availH - rowsPerCol * rowPitch) / 2);
  final bubbleR = (rowPitch * SheetGeometry.rowBubbleFactor)
      .clamp(SheetGeometry.minBubbleR, SheetGeometry.maxBubbleR)
      .toDouble();

  final slots = <QuestionSlot>[];
  for (var i = 0; i < questions.length; i++) {
    final q = questions[i];
    final isYesNo = q.type == 'yesno';
    final col = i ~/ rowsPerCol;                      // 0 = العمود الأيمن
    final row = i % rowsPerCol;
    final right = col == 0 ? SheetGeometry.colRightRight : SheetGeometry.colLeftRight;
    final left = col == 0 ? SheetGeometry.colRightLeft : SheetGeometry.colLeftLeft;
    final y = yStart + rowPitch * (row + 0.5);
    final count = isYesNo ? 2 : q.options.clamp(2, 5);
    final r = bubbleR;
    final xFirst = right - (SheetGeometry.numberBoxW + SheetGeometry.numberBoxGap) - r;
    final maxPitch = isYesNo ? SheetGeometry.yesNoMaxPitch : SheetGeometry.choiceMaxPitch;
    final avail = math.max(4.0, (xFirst - r) - left - 1.5);
    final pitch = math.min(maxPitch, avail / (count - 1));

    final bubbles = <Bubble>[];
    for (var o = 0; o < count; o++) {
      bubbles.add(Bubble(
        x: xFirst - o * pitch,
        y: y,
        r: r,
        role: isYesNo ? 'yesno' : 'choice',
        index: i,
        option: o,
        label: isYesNo ? kYesNoLabels[o] : SheetTemplate.labelFor(optionLabels, o),
      ));
    }
    slots.add(QuestionSlot(
      index: i,
      type: isYesNo ? 'yesno' : 'choice',
      optionCount: count,
      bubbles: bubbles,
      numberX: right - SheetGeometry.numberBoxW,
      numberY: y - rowPitch * 0.42,
      numberH: rowPitch * 0.84,
    ));
  }

  return SheetTemplate(
    serial: serial, isKey: isKey, title: title, subject: subject, gradeLabel: gradeLabel,
    teacher: teacher, examDate: examDate, optionLabels: optionLabels,
    fiducials: fiducials, codeBubbles: codeBubbles, codeValue: codeValue,
    digitBubbles: digitBubbles, digitCols: cols, digitBoxes: digitBoxes, questions: slots,
    rowsPerCol: rowsPerCol, rowPitch: rowPitch, yStart: yStart, bubbleR: bubbleR,
  );
}

/// نصّ التعليمات المطبوع على الورقة (واحد للجميع).
const List<String> kSheetInstructions = [
  'ظلّل دائرة واحدة فقط لكل سؤال بقلم رصاص أو قلم جاف أسود/أزرق.',
  'دائرة = رمز الإجابة الصحيحة، ونعم/لا كما هو مطلوب في السؤال.',
  'لا تكتب خارج الدوائر، ولا تُظلّل أكثر من دائرة واحدة.',
];
const String kIdCaption = 'رقم الجلوس';
const String kIdHint = 'اكتب رقمك في المستطيلات، ثم شبّك الرقم نفسه أسفل كل عمود';
const String kCodeCaption = 'رمز الورقة';
const String kFooterNote = 'نصف ورقة A4 · لا تكتب في هذا القسم — تُقرأ الورقة آليًا';
