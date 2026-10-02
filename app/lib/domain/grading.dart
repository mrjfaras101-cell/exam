/// قواعد التصحيح والتحليلات التعليمية — منطق خالص (بلا Flutter) لتسهيل الاختبار.
/// نظير هذا الملف في النموذج الحي: demo/js/grading.js (نفس المعادلات، مُختبرة آليًا).
library;

import 'models.dart';

class QuestionOutcome {
  QuestionOutcome(this.index, this.state, this.delta);
  final int index;
  final String state; // correct | wrong | blank | cancelled
  final double delta; // ما أضافه/أنقصه السؤال في الدرجة
}

class GradedAttempt {
  GradedAttempt({
    required this.score,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.outcomes,
  });

  final double score;
  final double total;
  final int correct;
  final int wrong;
  final int blank;
  final List<QuestionOutcome> outcomes;

  double get percent => total > 0 ? (score / total) * 100 : 0;
}

/// درجة محاولة واحدة وفق مفتاح الاختبار وقواعد الخصم والإلغاء.
GradedAttempt grade({
  required List<int?> answers,
  required Exam exam,
}) {
  var score = 0.0, total = 0.0;
  var correct = 0, wrong = 0, blank = 0;
  final outcomes = <QuestionOutcome>[];

  for (var i = 0; i < exam.questions.length; i++) {
    final q = exam.questions[i];
    if (q.cancelled) {
      outcomes.add(QuestionOutcome(i, 'cancelled', 0));
      continue;
    }
    total += q.marks;
    final a = i < answers.length ? answers[i] : null;
    if (a == null) {
      blank++;
      outcomes.add(QuestionOutcome(i, 'blank', 0));
      continue;
    }
    if (a == q.correctOption) {
      score += q.marks;
      correct++;
      outcomes.add(QuestionOutcome(i, 'correct', q.marks));
    } else {
      wrong++;
      final penalty = exam.negativeMarking ? exam.negativeFactor * q.marks : 0.0;
      score -= penalty;
      outcomes.add(QuestionOutcome(i, 'wrong', -penalty));
    }
  }

  return GradedAttempt(
    score: score < 0 ? 0 : score,
    total: total,
    correct: correct,
    wrong: wrong,
    blank: blank,
    outcomes: outcomes,
  );
}

class ClassStats {
  ClassStats({
    required this.count,
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    required this.passRate,
    required this.q1,
    required this.q3,
    required this.histogram,
  });

  final int count;
  final double mean, median, min, max, passRate, q1, q3;

  /// عدد الطلاب في كل شريحة من 10% (10 خانات).
  final List<int> histogram;
}

ClassStats classStats(List<double> percents, {int passMark = 60}) {
  if (percents.isEmpty) {
    return ClassStats(count: 0, mean: 0, median: 0, min: 0, max: 0, passRate: 0, q1: 0, q3: 0, histogram: List.filled(10, 0));
  }
  final sorted = [...percents]..sort();
  double at(double p) => sorted[(p * (sorted.length - 1)).round().clamp(0, sorted.length - 1)];
  final mean = sorted.reduce((a, b) => a + b) / sorted.length;
  final median = sorted.length.isOdd
      ? sorted[sorted.length ~/ 2]
      : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
  final histogram = List<int>.filled(10, 0);
  for (final p in sorted) {
    final bin = p >= 100 ? 9 : (p ~/ 10).clamp(0, 9);
    histogram[bin]++;
  }
  return ClassStats(
    count: sorted.length,
    mean: mean,
    median: median,
    min: sorted.first,
    max: sorted.last,
    passRate: sorted.where((p) => p >= passMark).length / sorted.length * 100,
    q1: at(0.25),
    q3: at(0.75),
    histogram: histogram,
  );
}

class QuestionAnalysis {
  QuestionAnalysis({
    required this.index,
    required this.cancelled,
    required this.answered,
    required this.correct,
    required this.difficulty,
    required this.discrimination,
    required this.distribution,
    required this.flags,
  });

  final int index;
  final bool cancelled;
  final int answered;
  final int correct;

  /// معامل الصعوبة p = نسبة من أجاب صحيحًا.
  final double difficulty;

  /// معامل التمييز D = p(الأعلى 27%) − p(الأدنى 27%).
  final double discrimination;

  /// عدد من اختار كل خيار.
  final List<int> distribution;

  /// مؤشرات تستحق مراجعة المعلم (خطأ محتمل في المفتاح، سؤال معيب…).
  final List<String> flags;

  static const flagLabels = {
    'difficulty_very_hard': 'صعب جدًا',
    'difficulty_very_easy': 'سهل جدًا (لا يميّز)',
    'low_discrimination': 'تمييز ضعيف',
    'possible_key_error': 'راجع المفتاح أو صياغة السؤال',
  };
}

/// تحليل كل سؤال: صعوبة، تمييز، توزيع الاختيارات، ومؤشرات الخلل.
List<QuestionAnalysis> analyzeQuestions(Exam exam, List<List<int?>> matrix, List<double> percents) {
  final n = percents.length;
  final order = List<int>.generate(n, (i) => i)..sort((a, b) => percents[b].compareTo(percents[a]));
  final k = n == 0 ? 0 : (n * 0.27).round().clamp(1, n);
  final top = order.take(k).toList();
  final bottom = order.skip(n - k).toList();

  double pGroup(List<int> idx, int q) {
    if (idx.isEmpty) return 0;
    final ok = idx.where((i) => i < matrix.length && q < matrix[i].length && matrix[i][q] == exam.questions[q].correctOption).length;
    return ok / idx.length;
  }

  return List<QuestionAnalysis>.generate(exam.questions.length, (q) {
    final question = exam.questions[q];
    if (question.cancelled) {
      return QuestionAnalysis(
        index: q, cancelled: true, answered: 0, correct: 0,
        difficulty: 0, discrimination: 0,
        distribution: List.filled(question.optionCount, 0), flags: const [],
      );
    }
    final values = matrix.where((r) => q < r.length).map((r) => r[q]).where((v) => v != null).cast<int>().toList();
    final dist = List<int>.filled(question.optionCount, 0);
    for (final v in values) {
      if (v >= 0 && v < dist.length) dist[v]++;
    }
    final p = values.isEmpty ? 0.0 : values.where((v) => v == question.correctOption).length / values.length;
    final d = pGroup(top, q) - pGroup(bottom, q);

    final flags = <String>[];
    if (p < 0.2) flags.add('difficulty_very_hard');
    if (p > 0.95) flags.add('difficulty_very_easy');
    if (d < 0.2) flags.add('low_discrimination');
    var bestDistractor = 0;
    for (var o = 0; o < dist.length; o++) {
      if (o == question.correctOption) continue;
      if (dist[o] > bestDistractor) bestDistractor = dist[o];
    }
    if (values.isNotEmpty && bestDistractor / values.length > 0.4) flags.add('possible_key_error');

    return QuestionAnalysis(
      index: q, cancelled: false, answered: values.length,
      correct: values.where((v) => v == question.correctOption).length,
      difficulty: p, discrimination: d, distribution: dist, flags: flags,
    );
  });
}

/// معامل ثبات الاختبار KR-20 (تقريب جيد لثبات الأداة في اختبار واحد).
double? kr20(Exam exam, List<List<int?>> matrix, List<double> rawScores) {
  final items = analyzeQuestions(exam, matrix, rawScores).where((q) => !q.cancelled).toList();
  if (items.isEmpty || rawScores.length < 2) return null;
  final p = items.map((q) => q.difficulty).toList();
  final sumPq = p.fold<double>(0, (s, v) => s + v * (1 - v));
  final mean = rawScores.reduce((a, b) => a + b) / rawScores.length;
  final variance = rawScores.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / rawScores.length;
  if (variance == 0) return null;
  final k = items.length;
  return (k / (k - 1)) * (1 - sumPq / variance);
}

/// سلّم التقديرات (قابل للتعديل من الإعدادات).
String gradeLabel(double percent, {int passMark = 60}) {
  if (percent >= 90) return 'ممتاز';
  if (percent >= 80) return 'جيد جدًا';
  if (percent >= 70) return 'جيد';
  if (percent >= passMark) return 'مقبول';
  return 'راسب';
}
