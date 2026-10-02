/// اختبار وحدة قواعد التصحيح والتحليلات — مطابق لمنطق demo/js/grading.js.
///
/// التشغيل: flutter test test/grading_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:musahhih/domain/grading.dart';
import 'package:musahhih/domain/models.dart';

void main() {
  final exam = Exam(
    name: 'اختبار تجريبي',
    serial: 3,
    questions: [
      Question(type: QuestionType.choice, options: 4, marks: 1, correctOption: 0),
      Question(type: QuestionType.choice, options: 4, marks: 1, correctOption: 2),
      Question(type: QuestionType.yesNo, marks: 2, correctOption: 1),
      Question(type: QuestionType.choice, options: 4, marks: 1, correctOption: 3),
    ],
  );

  group('── التصحيح الأساسي ──', () {
    test('كل الإجابات صحيحة = الدرجة الكاملة', () {
      final r = grade(answers: [0, 2, 1, 3], exam: exam);
      expect(r.score, 5);
      expect(r.total, 5);
      expect(r.percent, closeTo(100, 1e-9));
    });

    test('خطأ واحد بوزن 2 يُنقص الدرجة', () {
      final r = grade(answers: [0, 2, 0, 3], exam: exam);
      expect(r.score, 3);
      expect(r.wrong, 1);
    });

    test('السؤال الفارغ = صفر ولا خصم (المجموع 1+2+1)', () {
      final r = grade(answers: [0, null, 1, 3], exam: exam);
      expect(r.score, 4);
      expect(r.blank, 1);
    });

    test('الخصم لا يطبَّق على الصحيح', () {
      final negExam = Exam(
        name: 'خصم',
        serial: 3,
        negativeMarking: true,
        questions: exam.questions.map((q) => Question(type: q.type, options: q.options, marks: q.marks, correctOption: q.correctOption)).toList(),
      );
      final r = grade(answers: [0, 2, 1, 3], exam: negExam);
      expect(r.score, 5);
    });

    test('الخصم على الخطأ (0.25 لكل علامة) والدرجة لا تقل عن صفر', () {
      final negExam = Exam(
        name: 'خصم',
        serial: 3,
        negativeMarking: true,
        questions: exam.questions.map((q) => Question(type: q.type, options: q.options, marks: q.marks, correctOption: q.correctOption)).toList(),
      );
      final r = grade(answers: [1, 1, 0, 0], exam: negExam);
      expect(r.score, closeTo(0, 1e-9), reason: 'مجموع الخصم 1.25 ← تُصفَّر الدرجة');
      expect(r.wrong, 4);
    });

    test('السؤال الملغى يُستثنى من الدرجة الكلية', () {
      final cancelledExam = Exam(
        name: 'ملغى',
        serial: 3,
        questions: exam.questions.map((q) => Question(type: q.type, options: q.options, marks: q.marks, correctOption: q.correctOption)).toList(),
      );
      cancelledExam.questions[2].cancelled = true;
      final r = grade(answers: [0, 2, 1, 3], exam: cancelledExam);
      expect(r.total, 3);
      expect(r.score, 3);
    });
  });

  group('── إحصاءات الصف ──', () {
    final percents = [100.0, 80.0, 60.0, 40.0, 20.0, 0.0];
    final st = classStats(percents, passMark: 60);

    test('المتوسط صحيح', () => expect(st.mean, closeTo(50, 1e-9)));
    test('الوسيط صحيح', () => expect(st.median, closeTo(50, 1e-9)));
    test('نسبة النجاح صحيحة', () => expect(st.passRate, closeTo(50, 1e-9)));
    test('الأعلى والأدنى', () {
      expect(st.max, 100);
      expect(st.min, 0);
    });
    test('التوزيع 10 خانات ومجموعها = عدد الأوراق', () {
      expect(st.histogram.length, 10);
      expect(st.histogram.fold<int>(0, (a, b) => a + b), 6);
    });
  });

  group('── تحليل الأسئلة ──', () {
    final matrix = <List<int?>>[
      [0, 2, 1, 3],
      [0, 2, null, 3],
      [0, 1, 1, 2],
      [1, 2, 0, 3],
      [1, 1, 0, 2],
      [2, 3, 0, 1],
    ];
    final percents = [100.0, 80.0, 60.0, 40.0, 20.0, 0.0];

    test('عدد الأسئلة في التحليل', () {
      expect(analyzeQuestions(exam, matrix, percents).length, 4);
    });

    test('صعوبة السؤال الأول = 3 صحاح من 6', () {
      final an = analyzeQuestions(exam, matrix, percents);
      expect(an[0].difficulty, closeTo(0.5, 1e-9));
    });

    test('معامل التمييز محسوب ضمن المجال [-1, 1]', () {
      final an = analyzeQuestions(exam, matrix, percents);
      expect(an.every((x) => x.discrimination >= -1 && x.discrimination <= 1), isTrue);
    });

    test('تمييز ضعيف يُرصد', () {
      final flat = Exam(
        name: 'لا يميّز',
        serial: 1,
        questions: [Question(type: QuestionType.choice, options: 2, correctOption: 0)],
      );
      final flatMatrix = <List<int?>>[
        [0], [1], [0], [0], [1], [0],
      ];
      final flatPercents = [90.0, 80.0, 70.0, 60.0, 50.0, 40.0];
      final an = analyzeQuestions(flat, flatMatrix, flatPercents);
      expect(an[0].discrimination.abs(), lessThan(0.2));
      expect(an[0].flags, contains('low_discrimination'));
    });

    test('مؤشر «راجع المفتاح» يظهر عند تركّز المشتّت', () {
      final tricky = Exam(
        name: 'مشتّت',
        serial: 1,
        questions: [Question(type: QuestionType.choice, options: 4, correctOption: 0)],
      );
      final tMatrix = <List<int?>>[
        [1], [1], [1], [0], [1], [0],
      ];
      final an = analyzeQuestions(tricky, tMatrix, [50, 51, 52, 53, 54, 55]);
      expect(an[0].flags, contains('possible_key_error'));
    });

    test('توزيع الاختيارات صحيح', () {
      final tricky = Exam(
        name: 'مشتّت',
        serial: 1,
        questions: [Question(type: QuestionType.choice, options: 4, correctOption: 0)],
      );
      final tMatrix = <List<int?>>[
        [1], [1], [1], [0], [1], [0],
      ];
      final an = analyzeQuestions(tricky, tMatrix, [50, 51, 52, 53, 54, 55]);
      expect(an[0].distribution[1], 4);
      expect(an[0].distribution[0], 2);
    });
  });

  group('── ثبات KR-20 ──', () {
    test('KR-20 رقم صالح أو null', () {
      final matrix = <List<int?>>[
        [0, 2, 1, 3],
        [0, 2, null, 3],
        [0, 1, 1, 2],
        [1, 2, 0, 3],
        [1, 1, 0, 2],
        [2, 3, 0, 1],
      ];
      final kr = kr20(exam, matrix, [5, 4, 3, 2, 1, 0]);
      expect(kr == null || (kr > -1 && kr < 1.01), isTrue, reason: 'kr=$kr');
    });
  });
}
