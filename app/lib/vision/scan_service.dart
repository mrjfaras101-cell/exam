/// خدمة المسح: تشغيل محرّك القراءة داخل Isolate منفصل حتى لا تتجمّد الواجهة.
///
/// تُمرَّر البيانات كخرائط/مصفوفات بسيطة (Sendable) لأن كائنات القالب والنتيجة
/// ليست قابلة للنقل بين العُزل — فيُبنى القالب داخل العزل من مواصفات مختصرة.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'omr_engine.dart';
import 'template.dart';

/// مواصفات مختصرة للقالب تُرسل إلى العزل.
Map<String, dynamic> templateSpec({
  required String title,
  required int serial,
  required bool isKey,
  required List<({String type, int options})> questions,
  int idDigits = 8,
  String optionLabels = 'ar',
}) =>
    {
      'title': title,
      'serial': serial,
      'isKey': isKey,
      'idDigits': idDigits,
      'optionLabels': optionLabels,
      'questions': questions.map((q) => {'type': q.type, 'options': q.options}).toList(),
    };

SheetTemplate templateFromSpec(Map<String, dynamic> spec) => buildTemplate(
      title: spec['title'] as String? ?? '',
      serial: (spec['serial'] as num?)?.toInt() ?? 0,
      isKey: spec['isKey'] as bool? ?? false,
      idDigits: (spec['idDigits'] as num?)?.toInt() ?? 8,
      optionLabels: spec['optionLabels'] as String? ?? 'ar',
      questions: [
        for (final q in (spec['questions'] as List? ?? const []))
          (type: (q as Map)['type'] as String? ?? 'choice', options: ((q)['options'] as num?)?.toInt() ?? 4),
      ],
    );

/// ملخّص نتيجة القراءة (قابل للنقل بين العُزل، ويكفي للتصحيح والتراكب البصري).
class ScanSummary {
  ScanSummary({
    required this.ok,
    this.reason,
    this.studentNumber,
    this.digits = const [],
    this.answers = const [],
    this.flags = const [],
    this.confidence = 0,
    this.isKeySheet = false,
    this.serial = 0,
    this.corners = const [],
    this.mirrored = false,
    this.lowRes = false,
    this.pxPerMm = 0,
    this.edgeWidthMm = 0,
    this.glareRatio = 0,
    this.elapsedMs = 0,
  });

  final bool ok;
  final String? reason;
  final int? studentNumber;
  final List<int?> digits;

  /// إجابات كل سؤال (null = فارغ/غير مقروء).
  final List<int?> answers;

  /// (فهرس السؤال، الحالة، السبب) — الحالات السالبة عامة: -1 دقة، -2 لمعان، -3 ضبابية.
  final List<(int, String, String)> flags;
  final double confidence;
  final bool isKeySheet;
  final int serial;

  /// أركان الورقة في الصورة (لرسم التراكب).
  final List<List<double>> corners;
  final bool mirrored;
  final bool lowRes;
  final double pxPerMm, edgeWidthMm, glareRatio;
  final int elapsedMs;

  bool get needsReview => flags.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'ok': ok,
        'reason': reason,
        'studentNumber': studentNumber,
        'digits': digits,
        'answers': answers,
        'flags': flags.map((f) => [f.$1, f.$2, f.$3]).toList(),
        'confidence': confidence,
        'isKeySheet': isKeySheet,
        'serial': serial,
        'corners': corners,
        'mirrored': mirrored,
        'lowRes': lowRes,
        'pxPerMm': pxPerMm,
        'edgeWidthMm': edgeWidthMm,
        'glareRatio': glareRatio,
        'elapsedMs': elapsedMs,
      };

  static ScanSummary fromMap(Map<String, dynamic> m) => ScanSummary(
        ok: m['ok'] as bool? ?? false,
        reason: m['reason'] as String?,
        studentNumber: (m['studentNumber'] as num?)?.toInt(),
        digits: ((m['digits'] as List?) ?? const []).map((e) => (e as num?)?.toInt()).toList(),
        answers: ((m['answers'] as List?) ?? const []).map((e) => (e as num?)?.toInt()).toList(),
        flags: ((m['flags'] as List?) ?? const []).map((e) {
          final l = e as List;
          return ((l[0] as num).toInt(), l[1] as String? ?? '', l[2] as String? ?? '');
        }).toList(),
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
        isKeySheet: m['isKeySheet'] as bool? ?? false,
        serial: (m['serial'] as num?)?.toInt() ?? 0,
        corners: ((m['corners'] as List?) ?? const [])
            .map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
            .toList(),
        mirrored: m['mirrored'] as bool? ?? false,
        lowRes: m['lowRes'] as bool? ?? false,
        pxPerMm: (m['pxPerMm'] as num?)?.toDouble() ?? 0,
        edgeWidthMm: (m['edgeWidthMm'] as num?)?.toDouble() ?? 0,
        glareRatio: (m['glareRatio'] as num?)?.toDouble() ?? 0,
        elapsedMs: (m['elapsedMs'] as num?)?.toInt() ?? 0,
      );
}

/// مدخل العزل — دالة عامة (تتطلّبها compute).
Map<String, dynamic> scanIsolateEntry(Map<String, dynamic> args) {
  final gray = args['gray'] as Uint8List;
  final width = (args['width'] as num).toInt();
  final height = (args['height'] as num).toInt();
  final spec = Map<String, dynamic>.from(args['spec'] as Map);
  final th = Map<String, dynamic>.from(args['thresholds'] as Map? ?? const {});

  final reader = SheetReader(
    thresholds: EngineThresholds(
      tHigh: (th['tHigh'] as num?)?.toDouble() ?? 0.45,
      tLight: (th['tLight'] as num?)?.toDouble() ?? 0.18,
      inkRatio: (th['inkRatio'] as num?)?.toDouble() ?? 0.74,
    ),
  );

  final r = reader.read(gray: gray, width: width, height: height, template: templateFromSpec(spec));

  return ScanSummary(
    ok: r.ok,
    reason: r.reason,
    studentNumber: r.studentNumber,
    digits: r.digits,
    answers: r.answerOptions,
    flags: r.flags.map((f) => (f.index, f.status, f.reason)).toList(),
    confidence: r.confidence,
    isKeySheet: r.code?.isKeySheet ?? false,
    serial: r.code?.serial ?? 0,
    corners: r.corners,
    mirrored: r.mirrored,
    lowRes: r.lowRes,
    pxPerMm: r.quality?.pxPerMm ?? 0,
    edgeWidthMm: r.quality?.edgeWidthMm ?? 0,
    glareRatio: r.quality?.glareRatio ?? 0,
    elapsedMs: r.elapsedMs,
  ).toMap();
}

/// يقرأ إطارًا واحدًا (في الخلفية إن أمكن).
Future<ScanSummary> scanFrame({
  required Uint8List gray,
  required int width,
  required int height,
  required Map<String, dynamic> spec,
  Map<String, dynamic> thresholds = const {},
}) async {
  final args = {
    'gray': gray,
    'width': width,
    'height': height,
    'spec': spec,
    'thresholds': thresholds,
  };
  // compute يعمل في Isolate على الأجهزة: لا تجميد للواجهة أثناء المعالجة.
  final result = await compute(scanIsolateEntry, args);
  return ScanSummary.fromMap(Map<String, dynamic>.from(result));
}
