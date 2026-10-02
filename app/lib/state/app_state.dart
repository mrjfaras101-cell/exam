/// حالة التطبيق: الاختبارات، النتائج، الإعدادات — مع التصحيح الفوري بعد كل مسح.
library;

import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../domain/grading.dart';
import '../domain/models.dart';
import '../vision/scan_service.dart';
import '../vision/template.dart';

class AppState extends ChangeNotifier {
  AppState(this.repo);

  final Repository repo;

  List<Exam> exams = [];
  Exam? active;
  List<Attempt> attempts = [];
  Map<int, String> students = {};

  // إعدادات القراءة (قابلة للمعايرة من شاشة الإعدادات)
  double tHigh = 0.45;
  double tLight = 0.18;
  double inkRatio = 0.74;
  bool negativeMarking = false;
  int passMark = 60;

  bool loading = true;

  Map<String, dynamic> get thresholds => {'tHigh': tHigh, 'tLight': tLight, 'inkRatio': inkRatio};

  Future<void> load() async {
    exams = await repo.listExams();
    students = await repo.studentsMap();
    tHigh = double.tryParse(await repo.getSetting('tHigh') ?? '') ?? tHigh;
    tLight = double.tryParse(await repo.getSetting('tLight') ?? '') ?? tLight;
    inkRatio = double.tryParse(await repo.getSetting('inkRatio') ?? '') ?? inkRatio;
    passMark = int.tryParse(await repo.getSetting('passMark') ?? '') ?? passMark;
    if (active == null && exams.isNotEmpty) active = exams.first;
    if (active != null) {
      attempts = await repo.attemptsFor(active!.id!);
      negativeMarking = active!.negativeMarking;
      passMark = active!.passMark;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> selectExam(Exam exam) async {
    active = exam;
    negativeMarking = exam.negativeMarking;
    passMark = exam.passMark;
    attempts = exam.id == null ? [] : await repo.attemptsFor(exam.id!);
    notifyListeners();
  }

  Future<Exam> createExam(Exam exam) async {
    exam.createdAt = DateTime.now().millisecondsSinceEpoch;
    await repo.saveExam(exam);
    exams = await repo.listExams();
    active = exams.firstWhere((e) => e.id == exam.id);
    negativeMarking = active!.negativeMarking;
    passMark = active!.passMark;
    attempts = [];
    notifyListeners();
    return active!;
  }

  Future<void> saveExamMeta(Exam exam) async {
    await repo.saveExam(exam);
    exams = await repo.listExams();
    notifyListeners();
  }

  Future<void> saveKey(Exam exam) async {
    await repo.saveKey(exam);
    notifyListeners();
  }

  /// يبني قالب الورقة الحالي (للطباعة أو للمسح).
  SheetTemplate template({bool isKey = false}) => buildTemplate(
        title: active?.name ?? '',
        subject: active?.subject ?? '',
        gradeLabel: active?.gradeLabel ?? '',
        teacher: active?.teacher ?? '',
        examDate: active?.examDate ?? '',
        serial: active?.serial ?? 0,
        isKey: isKey,
        idDigits: active?.idDigits ?? 8,
        optionLabels: active?.optionLabels ?? 'ar',
        questions: [
          for (final q in active?.questions ?? const <Question>[])
            (type: q.type.code, options: q.optionCount),
        ],
      );

  Map<String, dynamic> spec({bool isKey = false}) => templateSpec(
        title: active?.name ?? '',
        serial: active?.serial ?? 0,
        isKey: isKey,
        idDigits: active?.idDigits ?? 8,
        optionLabels: active?.optionLabels ?? 'ar',
        questions: [
          for (final q in active?.questions ?? const <Question>[])
            (type: q.type.code, options: q.optionCount),
        ],
      );

  GradedAttempt graded(Attempt attempt) => grade(answers: attempt.answers, exam: active!);

  /// يحوّل قراءة إلى محاولة مُصحَّحة ويحفظها (مع تحديث إذا كان الطالب مُسجَّلًا).
  Future<Attempt?> recordScan(ScanSummary s) async {
    final exam = active;
    if (exam == null || exam.id == null) return null;
    if (!s.ok || s.isKeySheet) return null;

    final attempt = Attempt(
      examId: exam.id!,
      studentNumber: s.studentNumber,
      studentName: s.studentNumber == null ? null : students[s.studentNumber],
      answers: s.answers,
      flagged: s.flags.map((f) => ReviewFlag(f.$1, f.$2, f.$3)).toList(),
      confidence: s.confidence,
      scannedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final g = grade(answers: attempt.answers, exam: exam);
    attempt
      ..score = g.score
      ..total = g.total
      ..percent = g.percent;

    await repo.upsertAttempt(attempt);
    attempts = await repo.attemptsFor(exam.id!);
    notifyListeners();
    return attempt;
  }

  /// تعديل يدوي لإجابة سؤال (من شاشة المراجعة) مع إعادة حساب الدرجة.
  Future<void> overrideAnswer(Attempt attempt, int questionIndex, int? option) async {
    while (attempt.answers.length <= questionIndex) {
      attempt.answers.add(null);
    }
    attempt.answers[questionIndex] = option;
    attempt.manuallyEdited = true;
    final g = grade(answers: attempt.answers, exam: active!);
    attempt
      ..score = g.score
      ..total = g.total
      ..percent = g.percent
      ..flagged = attempt.flagged.where((f) => f.index != questionIndex).toList();
    await repo.upsertAttempt(attempt);
    attempts = await repo.attemptsFor(active!.id!);
    notifyListeners();
  }

  Future<void> toggleCancelQuestion(int index) async {
    final exam = active;
    if (exam == null) return;
    exam.questions[index].cancelled = !exam.questions[index].cancelled;
    await repo.saveKey(exam);
    // إعادة حساب كل النتائج بعد الإلغاء
    for (final a in attempts) {
      final g = grade(answers: a.answers, exam: exam);
      a
        ..score = g.score
        ..total = g.total
        ..percent = g.percent;
      await repo.upsertAttempt(a);
    }
    attempts = await repo.attemptsFor(exam.id!);
    notifyListeners();
  }

  Future<void> clearAttempts() async {
    if (active?.id == null) return;
    await repo.clearAttempts(active!.id!);
    attempts = [];
    notifyListeners();
  }

  Future<void> deleteAttempt(Attempt a) async {
    if (a.id != null) await repo.deleteAttempt(a.id!);
    attempts = await repo.attemptsFor(active!.id!);
    notifyListeners();
  }

  Map<int, String> get studentNames => students;

  // ---- إعدادات (تُحفظ في الذاكرة وتبقى بين الجلسات عبر جدول settings عند الحاجة) ----
  void updateReadSettings({double? tHigh, double? tLight, double? inkRatio}) {
    if (tHigh != null) {
      this.tHigh = tHigh;
      repo.setSetting('tHigh', tHigh.toStringAsFixed(3));
    }
    if (tLight != null) {
      this.tLight = tLight;
      repo.setSetting('tLight', tLight.toStringAsFixed(3));
    }
    if (inkRatio != null) {
      this.inkRatio = inkRatio;
      repo.setSetting('inkRatio', inkRatio.toStringAsFixed(3));
    }
    notifyListeners();
  }

  void setPassMark(int value) {
    passMark = value;
    repo.setSetting('passMark', '$value');
    final exam = active;
    if (exam != null) {
      exam.passMark = value;
      saveExamMeta(exam);
    }
    notifyListeners();
  }

  Future<void> setNegativeMarking(bool value) async {
    final exam = active;
    if (exam == null) return;
    exam.negativeMarking = value;
    negativeMarking = value;
    await saveExamMeta(exam);
  }

  Future<void> deleteActiveExam() async {
    final exam = active;
    if (exam?.id == null) return;
    await repo.deleteExam(exam!.id!);
    exams = await repo.listExams();
    active = exams.isEmpty ? null : exams.first;
    attempts = active?.id == null ? [] : await repo.attemptsFor(active!.id!);
    notifyListeners();
  }

  /// يحفظ الصورة المصغّرة لورقة تحتاج مراجعة (اختياري — يُطفأ افتراضيًا حفاظًا على الخصوصية).
  Future<void> attachImage(Attempt attempt, String path) async {
    attempt.imagePath = path;
    await repo.upsertAttempt(attempt);
    attempts = await repo.attemptsFor(active!.id!);
    notifyListeners();
  }

  Future<void> rememberStudent(int number, String name) async {
    students[number] = name;
    await repo.upsertStudent(number, name);
    notifyListeners();
  }

  // ---- تحليلات ----
  ClassStats get classStatsValue => classStats(attempts.map((a) => a.percent).toList(), passMark: passMark);

  List<QuestionAnalysis> get analysis => analyzeQuestions(
        active!,
        attempts.map((a) => a.answers).toList(),
        attempts.map((a) => a.percent).toList(),
      );
}
