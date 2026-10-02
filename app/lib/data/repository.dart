/// طبقة التخزين المحلي (SQLite عبر sqflite) — لا إنترنت ولا خادم.
///
/// التصميم: جداول منظّمة للاختبارات والأسئلة والمحاولات، مع تخزين الإجابات
/// والأعلام كـ JSON (مرونة في التطوير مقابل تعقيد ضئيل — البيانات صغيرة جدًا).
library;

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

class Repository {
  Repository._(this._db);
  final Database _db;

  static Repository? _instance;
  static Repository get instance {
    final i = _instance;
    if (i == null) throw StateError('Repository غير مهيّأ — استدعِ Repository.init() أولًا');
    return i;
  }

  static Future<Repository> init({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'musahhih.db');
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE exams(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, subject TEXT, grade_label TEXT, section TEXT, teacher TEXT,
            exam_date TEXT, serial INTEGER NOT NULL, id_digits INTEGER NOT NULL,
            option_labels TEXT NOT NULL, negative_marking INTEGER NOT NULL DEFAULT 0,
            negative_factor REAL NOT NULL DEFAULT 0.25, pass_mark INTEGER NOT NULL DEFAULT 60,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE questions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id INTEGER NOT NULL, order_index INTEGER NOT NULL,
            type TEXT NOT NULL, options INTEGER NOT NULL, marks REAL NOT NULL DEFAULT 1,
            correct_option INTEGER, cancelled INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(exam_id) REFERENCES exams(id) ON DELETE CASCADE
          )''');
        await db.execute('''
          CREATE TABLE attempts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id INTEGER NOT NULL, student_number INTEGER, student_name TEXT,
            answers TEXT NOT NULL, flagged TEXT NOT NULL, confidence REAL NOT NULL DEFAULT 0,
            score REAL NOT NULL DEFAULT 0, total REAL NOT NULL DEFAULT 0, percent REAL NOT NULL DEFAULT 0,
            image_path TEXT, scanned_at INTEGER, manually_edited INTEGER NOT NULL DEFAULT 0,
            UNIQUE(exam_id, student_number)
          )''');
        await db.execute('''
          CREATE TABLE students(number INTEGER PRIMARY KEY, name TEXT, class_label TEXT)''');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
        await db.execute('CREATE INDEX idx_questions_exam ON questions(exam_id, order_index)');
        await db.execute('CREATE INDEX idx_attempts_exam ON attempts(exam_id)');
      },
    );
    _instance = Repository._(db);
    return _instance!;
  }

  /* ------------------------------ الاختبارات ------------------------------ */

  Future<List<Exam>> listExams() async {
    final rows = await _db.query('exams', orderBy: 'created_at DESC');
    final exams = <Exam>[];
    for (final row in rows) {
      final qRows = await _db.query('questions', where: 'exam_id = ?', whereArgs: [row['id']], orderBy: 'order_index ASC');
      final questions = qRows
          .map((q) => Question(
                type: QuestionTypeX.fromCode(q['type'] as String),
                options: (q['options'] as int?) ?? 4,
                marks: (q['marks'] as num?)?.toDouble() ?? 1,
                correctOption: q['correct_option'] as int?,
                cancelled: (q['cancelled'] as int? ?? 0) == 1,
              ))
          .toList();
      exams.add(Exam(
        id: row['id'] as int,
        name: row['name'] as String,
        subject: row['subject'] as String? ?? '',
        gradeLabel: row['grade_label'] as String? ?? '',
        section: row['section'] as String? ?? '',
        teacher: row['teacher'] as String? ?? '',
        examDate: row['exam_date'] as String? ?? '',
        serial: row['serial'] as int,
        idDigits: row['id_digits'] as int,
        optionLabels: row['option_labels'] as String? ?? 'ar',
        questions: questions,
        negativeMarking: (row['negative_marking'] as int? ?? 0) == 1,
        negativeFactor: (row['negative_factor'] as num?)?.toDouble() ?? 0.25,
        passMark: row['pass_mark'] as int? ?? 60,
        createdAt: row['created_at'] as int?,
      ));
    }
    return exams;
  }

  Future<int> saveExam(Exam exam) async {
    final values = {
      'name': exam.name,
      'subject': exam.subject,
      'grade_label': exam.gradeLabel,
      'section': exam.section,
      'teacher': exam.teacher,
      'exam_date': exam.examDate,
      'serial': exam.serial,
      'id_digits': exam.idDigits,
      'option_labels': exam.optionLabels,
      'negative_marking': exam.negativeMarking ? 1 : 0,
      'negative_factor': exam.negativeFactor,
      'pass_mark': exam.passMark,
      'created_at': exam.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    };
    return _db.transaction<int>((txn) async {
      int examId;
      if (exam.id == null) {
        examId = await txn.insert('exams', values);
        exam.id = examId;
      } else {
        examId = exam.id!;
        await txn.update('exams', values, where: 'id = ?', whereArgs: [examId]);
        await txn.delete('questions', where: 'exam_id = ?', whereArgs: [examId]);
      }
      for (var i = 0; i < exam.questions.length; i++) {
        final q = exam.questions[i];
        await txn.insert('questions', {
          'exam_id': examId,
          'order_index': i,
          'type': q.type.code,
          'options': q.optionCount,
          'marks': q.marks,
          'correct_option': q.correctOption,
          'cancelled': q.cancelled ? 1 : 0,
        });
      }
      return examId;
    });
  }

  /// يحفظ مفتاح الإجابة والإلغاءات فقط (عملية شائعة بعد الاختبار).
  Future<void> saveKey(Exam exam) async {
    final examId = exam.id;
    if (examId == null) throw StateError('الاختبار غير محفوظ بعد');
    await _db.transaction((txn) async {
      for (var i = 0; i < exam.questions.length; i++) {
        final q = exam.questions[i];
        await txn.update(
          'questions',
          {'correct_option': q.correctOption, 'cancelled': q.cancelled ? 1 : 0},
          where: 'exam_id = ? AND order_index = ?',
          whereArgs: [examId, i],
        );
      }
    });
  }

  Future<void> deleteExam(int examId) async {
    await _db.transaction((txn) async {
      await txn.delete('attempts', where: 'exam_id = ?', whereArgs: [examId]);
      await txn.delete('questions', where: 'exam_id = ?', whereArgs: [examId]);
      await txn.delete('exams', where: 'id = ?', whereArgs: [examId]);
    });
  }

  /* ------------------------------ المحاولات ------------------------------ */

  Future<List<Attempt>> attemptsFor(int examId) async {
    final rows = await _db.query('attempts', where: 'exam_id = ?', whereArgs: [examId], orderBy: 'student_number ASC');
    return rows
        .map((r) => Attempt(
              id: r['id'] as int,
              examId: r['exam_id'] as int,
              studentNumber: r['student_number'] as int?,
              studentName: r['student_name'] as String?,
              answers: (jsonDecode(r['answers'] as String) as List).map((e) => (e as num?)?.toInt()).toList(),
              flagged: (jsonDecode(r['flagged'] as String) as List)
                  .map((e) => ReviewFlag.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList(),
              confidence: (r['confidence'] as num).toDouble(),
              score: (r['score'] as num).toDouble(),
              total: (r['total'] as num).toDouble(),
              percent: (r['percent'] as num).toDouble(),
              imagePath: r['image_path'] as String?,
              scannedAt: r['scanned_at'] as int?,
              manuallyEdited: (r['manually_edited'] as int? ?? 0) == 1,
            ))
        .toList();
  }

  Future<int> upsertAttempt(Attempt attempt) async {
    final values = {
      'exam_id': attempt.examId,
      'student_number': attempt.studentNumber,
      'student_name': attempt.studentName,
      'answers': jsonEncode(attempt.answers),
      'flagged': jsonEncode(attempt.flagged.map((f) => f.toJson()).toList()),
      'confidence': attempt.confidence,
      'score': attempt.score,
      'total': attempt.total,
      'percent': attempt.percent,
      'image_path': attempt.imagePath,
      'scanned_at': attempt.scannedAt ?? DateTime.now().millisecondsSinceEpoch,
      'manually_edited': attempt.manuallyEdited ? 1 : 0,
    };
    final existing = await _db.query('attempts',
        columns: ['id'], where: 'exam_id = ? AND student_number = ?', whereArgs: [attempt.examId, attempt.studentNumber]);
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await _db.update('attempts', values, where: 'id = ?', whereArgs: [id]);
      attempt.id = id;
      return id;
    }
    final id = await _db.insert('attempts', values);
    attempt.id = id;
    return id;
  }

  Future<void> deleteAttempt(int id) => _db.delete('attempts', where: 'id = ?', whereArgs: [id]);
  Future<void> clearAttempts(int examId) => _db.delete('attempts', where: 'exam_id = ?', whereArgs: [examId]);

  /* ------------------------------ الطلاب والإعدادات ------------------------------ */

  Future<Map<int, String>> studentsMap() async {
    final rows = await _db.query('students');
    return {for (final r in rows) r['number'] as int: (r['name'] as String? ?? '')};
  }

  Future<void> upsertStudent(int number, String name, {String? classLabel}) =>
      _db.insert('students', {'number': number, 'name': name, 'class_label': classLabel}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<String?> getSetting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) =>
      _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
}

/// نسخ احتياطي كـ JSON (يُشارَك عبر ملف) + استعادة.
class Backup {
  static Future<String> exportJson(Repository repo) async {
    final exams = await repo.listExams();
    final data = <String, dynamic>{'version': 1, 'exportedAt': DateTime.now().toIso8601String(), 'exams': []};
    for (final e in exams) {
      final attempts = await repo.attemptsFor(e.id!);
      (data['exams'] as List).add({
        'exam': e.toJson(),
        'attempts': attempts.map((a) => a.toJson()).toList(),
      });
    }
    return jsonEncode(data);
  }
}
