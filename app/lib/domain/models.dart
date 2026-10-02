/// نماذج البيانات الأساسية للتطبيق.
/// تُخزَّن القوالب الهندسية في `sheet/template.dart` لأنها ليست بيانات مستخدم بل هندسة.
library;

import 'dart:convert';

/// نوع السؤال: «ضع دائرة حول رمز الإجابة الصحيحة» أو «أجب بنعم أو لا».
enum QuestionType { choice, yesNo }

extension QuestionTypeX on QuestionType {
  String get code => this == QuestionType.choice ? 'choice' : 'yesno';
  static QuestionType fromCode(String c) => c == 'yesno' ? QuestionType.yesNo : QuestionType.choice;
}

class Question {
  Question({
    required this.type,
    this.options = 4,
    this.marks = 1,
    this.correctOption,
    this.cancelled = false,
  }) : assert(options >= 2 && options <= 5);

  final QuestionType type;

  /// عدد الخيارات لأسئلة «ضع دائرة» (2..5)؛ وأسئلة نعم/لا = 2 دائمًا.
  final int options;

  /// وزن السؤال في الدرجة.
  final double marks;

  /// فهرس الإجابة الصحيحة في مفتاح الإجابة (null = لم يُحدَّد بعد).
  int? correctOption;

  /// سؤال ملغى: يُستثنى من الدرجة الكلية ومن التحليلات (قرار المعلم بعد الاختبار).
  bool cancelled;

  int get optionCount => type == QuestionType.yesNo ? 2 : options;

  Map<String, dynamic> toJson() => {
        'type': type.code,
        'options': options,
        'marks': marks,
        'correct': correctOption,
        'cancelled': cancelled,
      };

  static Question fromJson(Map<String, dynamic> j) => Question(
        type: QuestionTypeX.fromCode(j['type'] as String? ?? 'choice'),
        options: (j['options'] as num?)?.toInt() ?? 4,
        marks: (j['marks'] as num?)?.toDouble() ?? 1,
        correctOption: (j['correct'] as num?)?.toInt(),
        cancelled: j['cancelled'] as bool? ?? false,
      );
}

class Exam {
  Exam({
    this.id,
    required this.name,
    this.subject = '',
    this.gradeLabel = '',
    this.section = '',
    this.teacher = '',
    this.examDate = '',
    required this.serial,
    this.idDigits = 8,
    this.optionLabels = 'ar',
    required this.questions,
    this.negativeMarking = false,
    this.negativeFactor = 0.25,
    this.passMark = 60,
    this.createdAt,
  });

  int? id;
  String name;
  String subject;
  String gradeLabel;
  String section;
  String teacher;
  String examDate;

  /// رقم الاختبار (0..31) — يُطبع في «رمز الورقة» ليُتعرَّف عليه آليًا.
  int serial;

  /// عدد منازل رقم الجلوس (حتى 8).
  int idDigits;

  /// 'ar' للحروف أ/ب/ج… أو 'en' للحروف A/B/C…
  String optionLabels;

  final List<Question> questions;
  bool negativeMarking;
  double negativeFactor;
  int passMark;
  int? createdAt;

  /// مجموع الدرجات مع استثناء الأسئلة الملغاة.
  double get totalMarks {
    var t = 0.0;
    for (final q in questions) {
      if (!q.cancelled) t += q.marks;
    }
    return t;
  }

  int get answeredKeyCount => questions.where((q) => q.correctOption != null).length;
  bool get keyComplete => questions.every((q) => q.correctOption != null);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'gradeLabel': gradeLabel,
        'section': section,
        'teacher': teacher,
        'examDate': examDate,
        'serial': serial,
        'idDigits': idDigits,
        'optionLabels': optionLabels,
        'questions': questions.map((q) => q.toJson()).toList(),
        'negativeMarking': negativeMarking,
        'negativeFactor': negativeFactor,
        'passMark': passMark,
        'createdAt': createdAt,
      };

  static Exam fromJson(Map<String, dynamic> j) => Exam(
        id: (j['id'] as num?)?.toInt(),
        name: j['name'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        gradeLabel: j['gradeLabel'] as String? ?? '',
        section: j['section'] as String? ?? '',
        teacher: j['teacher'] as String? ?? '',
        examDate: j['examDate'] as String? ?? '',
        serial: (j['serial'] as num?)?.toInt() ?? 0,
        idDigits: (j['idDigits'] as num?)?.toInt() ?? 8,
        optionLabels: j['optionLabels'] as String? ?? 'ar',
        questions: ((j['questions'] as List?) ?? const [])
            .map((e) => Question.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        negativeMarking: j['negativeMarking'] as bool? ?? false,
        negativeFactor: (j['negativeFactor'] as num?)?.toDouble() ?? 0.25,
        passMark: (j['passMark'] as num?)?.toInt() ?? 60,
        createdAt: (j['createdAt'] as num?)?.toInt(),
      );

  String toJsonString() => jsonEncode(toJson());
  static Exam fromJsonString(String s) => Exam.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
}

/// نتيجة قراءة ورقة طالب (قبل التصحيح).
class Attempt {
  Attempt({
    this.id,
    required this.examId,
    required this.studentNumber,
    this.studentName,
    required this.answers,
    required this.flagged,
    required this.confidence,
    this.percent = 0,
    this.score = 0,
    this.total = 0,
    this.imagePath,
    this.scannedAt,
    this.manuallyEdited = false,
  });

  int? id;
  int examId;
  int? studentNumber;
  String? studentName;

  /// إجابة كل سؤال (فهرس الخيار أو null = فارغ/غير مقروء).
  List<int?> answers;

  /// أسئلة وُسمت للمراجعة (سبب + فهرس).
  List<ReviewFlag> flagged;
  double confidence;

  double score;
  double total;
  double percent;

  /// مسار صورة الورقة (اختياري — تُحذف تلقائيًا بعد التصحيح إن لم تُفعَّل المراجعة).
  String? imagePath;
  int? scannedAt;
  bool manuallyEdited;

  /// «تحتاج مراجعة» = وسم يخصّ سؤالًا (index ≥ 0) أو رقم جلوس غير مقروء.
  /// الوسوم العامة (index < 0: دقة منخفضة، لمعان، اهتزاز) ملاحظات جودة لا تُزحم القائمة.
  bool get needsReview =>
      flagged.any((f) => f.index >= 0) || studentNumber == null;

  /// ملاحظات الجودة العامة (غير مرتبطة بسؤال) — تُعرض للعلم فقط.
  List<ReviewFlag> get qualityNotes => flagged.where((f) => f.index < 0).toList();

  Map<String, dynamic> toJson() => {
        'id': id,
        'examId': examId,
        'studentNumber': studentNumber,
        'studentName': studentName,
        'answers': answers,
        'flagged': flagged.map((f) => f.toJson()).toList(),
        'confidence': confidence,
        'score': score,
        'total': total,
        'percent': percent,
        'imagePath': imagePath,
        'scannedAt': scannedAt,
        'manuallyEdited': manuallyEdited,
      };

  static Attempt fromJson(Map<String, dynamic> j) => Attempt(
        id: (j['id'] as num?)?.toInt(),
        examId: (j['examId'] as num).toInt(),
        studentNumber: (j['studentNumber'] as num?)?.toInt(),
        studentName: j['studentName'] as String?,
        answers: ((j['answers'] as List?) ?? const []).map((e) => (e as num?)?.toInt()).toList(),
        flagged: ((j['flagged'] as List?) ?? const []).map((e) => ReviewFlag.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        score: (j['score'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        percent: (j['percent'] as num?)?.toDouble() ?? 0,
        imagePath: j['imagePath'] as String?,
        scannedAt: (j['scannedAt'] as num?)?.toInt(),
        manuallyEdited: j['manuallyEdited'] as bool? ?? false,
      );
}

/// سبب وسم سؤال للمراجعة (لا يوجد تخمين صامت في هذا التطبيق).
class ReviewFlag {
  ReviewFlag(this.index, this.status, this.reason);
  final int index;          // فهرس السؤال، أو سالب للأعلام العامة (-1 دقة منخفضة…)
  final String status;      // light | ambiguous | blankLowRes | lowres | glare | blurry
  final String reason;

  Map<String, dynamic> toJson() => {'index': index, 'status': status, 'reason': reason};
  static ReviewFlag fromJson(Map<String, dynamic> j) =>
      ReviewFlag((j['index'] as num).toInt(), j['status'] as String? ?? '', j['reason'] as String? ?? '');
}
