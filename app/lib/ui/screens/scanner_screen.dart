/// شاشة التصحيح بالكاميرا: معاينة حيّة + تراكب بصري + التقاط تلقائي + مراجعة فورية.
///
/// مبدأ التجربة: لا يضغط المعلم أي زر أثناء المسح المتتابع. التطبيق يلتقط تلقائيًا
/// عندما يستقرّ الورق ويتّفق قراءتان متتاليتان على النتيجة، ثم ينتقل للورقة التالية.
library;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../vision/camera_frame.dart';
import '../../vision/image_scan.dart';
import '../../vision/scan_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, this.keyMode = false});

  /// وضع «مسح ورقة المفتاح»: تُطبَّق الإجابات المقروءة على مفتاح الاختبار بدل الدرجات.
  final bool keyMode;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  bool initializing = true;
  String? cameraError;
  bool torchOn = false;
  bool busy = false;
  bool running = false;

  ScanSummary? last;
  Uint8List? lastGray;
  int lastW = 0, lastH = 0;
  String hud = 'شغّل الكاميرا ووجّهها نحو الورقة…';
  bool ready = false;

  final List<_Consensus> recent = [];
  Timer? cooldownTimer;
  DateTime lastCapture = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _initCameras();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    controller?.dispose();
    cooldownTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _initCameras() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          initializing = false;
          cameraError = 'لا توجد كاميرا على هذا الجهاز';
        });
        return;
      }
      await _startCamera(cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      ));
    } on CameraException catch (e) {
      setState(() {
        initializing = false;
        cameraError = 'تعذّر الوصول للكاميرا: ${e.description ?? e.code}';
      });
    }
  }

  Future<void> _startCamera(CameraDescription description) async {
    final previous = controller;
    final c = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
    );
    controller = c;
    await previous?.dispose();
    try {
      await c.initialize();
      await c.setFocusMode(FocusMode.auto);
      await c.startImageStream(_onFrame);
      setState(() {
        initializing = false;
        running = true;
        cameraError = null;
      });
    } on CameraException catch (e) {
      setState(() {
        initializing = false;
        cameraError = 'تعذّر تشغيل الكاميرا: ${e.description ?? e.code}';
      });
    }
  }

  Future<void> _stopCamera() async {
    final c = controller;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    await c.dispose();
    controller = null;
    setState(() => running = false);
  }

  /// معالجة إطار واحد — مع تجاهل الإطارات أثناء انشغال المعالج.
  Future<void> _onFrame(CameraImage image) async {
    if (busy || !mounted) return;
    final state = context.read<AppState>();
    final exam = state.active;
    if (exam == null) return;

    busy = true;
    try {
      final frame = frameFromCameraImage(image);
      final size = <int>[frame.width, frame.height];
      final gray = downscaleGray(frame.gray, frame.width, frame.height, 1100, size);

      final summary = await scanFrame(
        gray: gray,
        width: size[0],
        height: size[1],
        spec: state.spec(isKey: widget.keyMode),
        thresholds: state.thresholds,
      );

      if (!mounted) return;
      setState(() {
        last = summary;
        lastGray = gray;
        lastW = size[0];
        lastH = size[1];
        hud = _hudText(summary);
        ready = false;
      });

      if (!summary.ok) {
        recent.clear();
        return;
      }

      final sig = '${summary.studentNumber}|${summary.answers.join(',')}';
      final now = DateTime.now();
      final cooled = now.difference(lastCapture).inMilliseconds > 1500;

      recent.add(_Consensus(sig, summary.corners, now));
      if (recent.length > 3) recent.removeAt(0);

      final stable = recent.length >= 2 && recent[recent.length - 1].sig == recent[recent.length - 2].sig;
      if (stable && summary.pxPerMm >= 3.0 && cooled) {
        setState(() => ready = true);
        await _capture(summary);
      }
    } catch (e) {
      // إطار غير صالح — نتجاهله بهدوء (لا نُزعج المعلم برسائل تقنية)
    } finally {
      busy = false;
    }
  }

  String _hudText(ScanSummary s) {
    if (!s.ok) return s.reason ?? 'وجّه الكاميرا نحو الورقة…';
    final who = s.isKeySheet ? 'ورقة مفتاح' : 'رقم ${s.studentNumber ?? '؟'}';
    final qFlags = s.flags.where((f) => f.$1 >= 0).length;
    final flags = qFlags == 0 ? 'قراءة واضحة ✓' : '$qFlags موضع للمراجعة ⚠';
    return '$who · $flags · دقة ${s.pxPerMm.toStringAsFixed(1)} بكسل/مم';
  }

  Future<void> _capture(ScanSummary s) async {
    final state = context.read<AppState>();
    lastCapture = DateTime.now();
    recent.clear();
    HapticFeedback.mediumImpact();

    if (s.isKeySheet || widget.keyMode) {
      final key = s.answers;
      if (key.every((k) => k != null) && state.active != null) {
        for (var i = 0; i < state.active!.questions.length && i < key.length; i++) {
          state.active!.questions[i].correctOption = key[i];
        }
        await state.saveKey(state.active!);
        _snack('تم قراءة مفتاح الإجابة من الورقة ✓');
      } else {
        _snack('ورقة المفتاح غير مكتملة — أكمل الإجابات يدويًا');
      }
      return;
    }

    if (s.studentNumber == null) {
      _snack('رقم الجلوس غير مقروء — ستُضاف الورقة إلى «تحتاج مراجعة»');
    }
    final attempt = await state.recordScan(s);
    if (attempt != null && mounted) {
      setState(() => ready = true);
      _showResultSheet(attempt);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  /// بطاقة النتيجة بعد كل ورقة: الدرجة + كل سؤال (المس لتعديل الإجابة يدويًا).
  void _showResultSheet(Attempt attempt) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ResultSheet(attempt: attempt),
    );
  }

  Future<void> _pickImages() async {
    final state = context.read<AppState>();
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty || !mounted) return;
    var done = 0;
    for (final f in files) {
      setState(() => hud = 'جارٍ تصحيح الصور… ${done + 1}/${files.length}');
      final res = await scanImageFile(File(f.path), spec: state.spec(isKey: widget.keyMode), thresholds: state.thresholds);
      if (res != null && res.summary.ok) {
        final s = res.summary;
        if (s.isKeySheet) {
          for (var i = 0; i < (state.active?.questions.length ?? 0) && i < s.answers.length; i++) {
            state.active!.questions[i].correctOption = s.answers[i];
          }
          await state.saveKey(state.active!);
        } else {
          await state.recordScan(s);
          done++;
        }
      }
    }
    setState(() => hud = 'تم تصحيح $done ورقة من الصور');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final review = state.attempts.where((a) => a.needsReview).toList();
    final theme = Theme.of(context);

    if (state.active == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('التصحيح')),
        body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('اختر اختبارًا من الرئيسية أولًا'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.keyMode ? 'مسح ورقة المفتاح' : 'التصحيح بالكاميرا'),
        actions: [
          IconButton(
            tooltip: 'صور من المعرض',
            onPressed: _pickImages,
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _CameraBox(
            controller: controller,
            initializing: initializing,
            error: cameraError,
            hud: hud,
            ready: ready,
            overlay: last,
            frameW: lastW,
            frameH: lastH,
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: running ? _stopCamera : () => _initCameras(),
                icon: Icon(running ? Icons.pause : Icons.play_arrow),
                label: Text(running ? 'إيقاف' : 'تشغيل الكاميرا'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'إضاءة الكاميرا',
              onPressed: () async {
                final c = controller;
                if (c == null) return;
                torchOn = !torchOn;
                try {
                  await c.setFlashMode(torchOn ? FlashMode.torch : FlashMode.off);
                } catch (_) {
                  _snack('هذا الجهاز لا يدعم إضاءة الكاميرا');
                }
              },
              icon: Icon(torchOn ? Icons.flashlight_on : Icons.flashlight_off),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: last == null ? null : () => _capture(last!),
                icon: const Icon(Icons.camera),
                label: const Text('التقاط يدوي'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Text('تحتاج مراجعة', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (review.isNotEmpty)
              Chip(label: Text('${review.length}'), visualDensity: VisualDensity.compact),
            const Spacer(),
            Text('${state.attempts.length} ورقة', style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 8),
          if (review.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(18), child: Center(child: Text('لا توجد أوراق تحتاج مراجعة ✓'))))
          else
            for (final a in review)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(a.studentNumber == null ? 'رقم جلوس غير مقروء' : 'الطالب ${a.studentNumber}'),
                  subtitle: Text([
                if (a.flagged.any((f) => f.index >= 0))
                  a.flagged.where((f) => f.index >= 0).map((f) => 'س${f.index + 1}: ${f.reason}').join(' · ')
                else if (a.studentNumber == null)
                  'رقم الجلوس غير مقروء',
                ...a.qualityNotes.map((f) => '⚠ ${f.reason}'),
              ].join('\n')),
                  trailing: Text('${a.score.toStringAsFixed(1)}/${a.total.toStringAsFixed(0)}'),
                  onTap: () => _showResultSheet(a),
                ),
              ),
        ],
      ),
    );
  }
}

class _Consensus {
  _Consensus(this.sig, this.corners, this.at);
  final String sig;
  final List<List<double>> corners;
  final DateTime at;
}

/// صندوق الكاميرا + تراكب الرسم (الأركان والفقاعات المظلَّلة).
class _CameraBox extends StatelessWidget {
  const _CameraBox({
    required this.controller,
    required this.initializing,
    required this.error,
    required this.hud,
    required this.ready,
    required this.overlay,
    required this.frameW,
    required this.frameH,
  });

  final CameraController? controller;
  final bool initializing;
  final String? error;
  final String hud;
  final bool ready;
  final ScanSummary? overlay;
  final int frameW, frameH;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          color: Colors.black,
          child: Stack(fit: StackFit.expand, children: [
            if (controller != null && controller!.value.isInitialized)
              CameraPreview(controller!)
            else
              Center(
                child: initializing
                    ? const CircularProgressIndicator()
                    : Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(error ?? 'الكاميرا متوقفة', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                      ),
              ),
            if (overlay != null && overlay!.ok && frameW > 0)
              CustomPaint(painter: _OverlayPainter(overlay!, frameW, frameH)),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.transparent, Color(0xCC000000)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
                child: Text(hud, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
            if (ready)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(999)),
                  child: const Text('تمّت القراءة ✓', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: ready ? Colors.greenAccent : Colors.white54, width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.summary, this.frameW, this.frameH);
  final ScanSummary summary;
  final int frameW, frameH;

  @override
  void paint(Canvas canvas, Size size) {
    if (!summary.ok || summary.corners.length != 4) return;

    // تحويل إحداثيات إطار المعالجة إلى أبعاد العرض (نفس أسلوب BoxFit.cover)
    final scale = (size.width / frameW) > (size.height / frameH)
        ? size.width / frameW
        : size.height / frameH;
    final dx = (size.width - frameW * scale) / 2;
    final dy = (size.height - frameH * scale) / 2;
    Offset map(List<double> p) => Offset(p[0] * scale + dx, p[1] * scale + dy);

    final questionFlags = summary.flags.where((f) => f.$1 >= 0).length;
    final good = questionFlags == 0;

    final quad = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = good ? const Color(0xFF34D399) : const Color(0xFFF59E0B);

    final path = Path()..moveTo(map(summary.corners[0]).dx, map(summary.corners[0]).dy);
    for (var i = 1; i < 4; i++) {
      final p = map(summary.corners[i]);
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, quad);

    // نقاط الأركان الأربعة — تأكيد بصري على أن الورقة «مقفلة»
    for (final c in summary.corners) {
      final p = map(c);
      canvas.drawCircle(p, 5, Paint()..color = quad.color);
      canvas.drawCircle(p, 5, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xCC000000));
    }

    // شارة عدد المواضع التي تحتاج مراجعة
    if (!good) {
      final tp = TextPainter(
        text: TextSpan(
          text: '⚠ $questionFlags',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final o = map(summary.corners[0]);
      final rect = Rect.fromLTWH(o.dx - tp.width / 2 - 8, o.dy - 34, tp.width + 16, 26);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(13)), Paint()..color = const Color(0xFFF59E0B));
      tp.paint(canvas, Offset(rect.left + 8, rect.top + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.summary != summary || old.frameW != frameW || old.frameH != frameH;
}

/// بطاقة نتيجة الورقة: الدرجة، الحالة، ولمس أي سؤال لتعديل إجابته يدويًا.
class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.attempt});
  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final exam = state.active!;
    final scheme = Theme.of(context).colorScheme;
    final current = state.attempts.firstWhere((a) => a.id == attempt.id, orElse: () => attempt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: current.percent >= 60 ? scheme.primaryContainer : scheme.errorContainer,
            ),
            child: Center(
              child: Text('${current.score.toStringAsFixed(1)}\n/${current.total.toStringAsFixed(0)}',
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${current.studentName ?? 'طالب'} ${current.studentNumber != null ? '— ${current.studentNumber}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text('النسبة ${current.percent.toStringAsFixed(1)}% · ثقة القراءة ${(current.confidence * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < exam.questions.length; i++)
            _AnswerChip(attempt: current, index: i),
        ]),
        if (current.qualityNotes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            current.qualityNotes.map((f) => '⚠ ${f.reason}').join('\n'),
            style: TextStyle(fontSize: 11.5, height: 1.6, color: scheme.tertiary),
          ),
        ],
        const SizedBox(height: 8),
        Text('المس أي سؤال لتغيير إجابته يدويًا — تُعاد الدرجة فورًا.', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({required this.attempt, required this.index});
  final Attempt attempt;
  final int index;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final exam = state.active!;
    final q = exam.questions[index];
    final a = index < attempt.answers.length ? attempt.answers[index] : null;
    final labels = q.type == QuestionType.yesNo
        ? const ['نعم', 'لا']
        : (exam.optionLabels == 'en' ? const ['A', 'B', 'C', 'D', 'E'] : const ['أ', 'ب', 'ج', 'د', 'هـ']);
    final flagged = attempt.flagged.any((f) => f.index == index);
    final isCorrect = a != null && a == q.correctOption;
    final scheme = Theme.of(context).colorScheme;

    final bg = flagged
        ? scheme.tertiaryContainer
        : (a == null
            ? scheme.surfaceContainerHighest
            : (isCorrect ? scheme.primaryContainer : scheme.errorContainer));

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        final max = q.optionCount;
        int? next;
        if (a == null) {
          next = 0;
        } else if (a >= max - 1) {
          next = null;
        } else {
          next = a + 1;
        }
        state.overrideAnswer(attempt, index, next);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(
          '${index + 1}: ${a == null ? '—' : labels[a]}${flagged ? ' ⚠' : ''}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
