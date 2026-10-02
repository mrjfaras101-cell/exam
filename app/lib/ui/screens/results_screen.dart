import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/grading.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';

/// النتائج: إحصاءات الصف + جدول الطلاب + تحليل الأسئلة (صعوبة/تمييز/توزيع) + تصدير CSV.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final exam = state.active;

    if (exam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('النتائج والتحليل')),
        body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('اختر اختبارًا من الرئيسية أولًا'))),
      );
    }

    final stats = state.classStatsValue;
    final analysis = state.attempts.isEmpty ? <QuestionAnalysis>[] : state.analysis;

    return Scaffold(
      appBar: AppBar(
        title: const Text('النتائج والتحليل'),
        actions: [
          IconButton(
            tooltip: 'تصدير CSV',
            onPressed: state.attempts.isEmpty ? null : () => _exportCsv(context, state),
            icon: const Icon(Icons.table_view_outlined),
          ),
        ],
      ),
      body: state.attempts.isEmpty
          ? const Center(
              child: Padding(padding: EdgeInsets.all(28), child: Text('لا توجد نتائج بعد — ابدأ التصحيح من شاشة الكاميرا')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _StatsGrid(stats: stats),
                const SizedBox(height: 8),
                _Histogram(stats: stats),
                const SizedBox(height: 18),
                Text('نتائج الطلاب', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _ResultsTable(exam: exam),
                const SizedBox(height: 20),
                Text('تحليل الأسئلة', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text('معامل الصعوبة p · معامل التمييز D · توزيع اختيارات الطلاب',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final an in analysis) _AnalysisCard(analysis: an, exam: exam),
              ],
            ),
    );
  }

  Future<void> _exportCsv(BuildContext context, AppState state) async {
    final exam = state.active!;
    final rows = <List<dynamic>>[
      ['رقم الجلوس', 'الاسم', 'الدرجة', 'من', 'النسبة', 'الحالة', ...exam.questions.asMap().entries.map((e) => 'س${e.key + 1}')],
      for (final a in state.attempts)
        [
          a.studentNumber ?? '',
          a.studentName ?? '',
          a.score.toStringAsFixed(2),
          a.total.toStringAsFixed(0),
          a.percent.toStringAsFixed(1),
          a.needsReview ? 'مراجعة' : 'سليم',
          ...a.answers.map((v) => v == null ? '' : v + 1),
        ],
    ];
    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '${exam.name}-results.csv'));
    await file.writeAsString('\uFEFF$csvData', flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'نتائج ${exam.name}');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز ملف CSV ✓')));
    }
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final ClassStats stats;
  @override
  Widget build(BuildContext context) {
    if (stats.count == 0) return const SizedBox.shrink();
    Widget tile(String value, String label) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ]),
            ),
          ),
        );
    return Column(children: [
      Row(children: [
        tile('${stats.count}', 'ورقة'),
        const SizedBox(width: 6),
        tile('${stats.mean.toStringAsFixed(1)}%', 'المتوسط'),
        const SizedBox(width: 6),
        tile('${stats.median.toStringAsFixed(0)}%', 'الوسيط'),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        tile('${stats.max.toStringAsFixed(0)}%', 'الأعلى'),
        const SizedBox(width: 6),
        tile('${stats.min.toStringAsFixed(0)}%', 'الأدنى'),
        const SizedBox(width: 6),
        tile('${stats.passRate.toStringAsFixed(0)}%', 'النجاح'),
      ]),
    ]);
  }
}

class _Histogram extends StatelessWidget {
  const _Histogram({required this.stats});
  final ClassStats stats;
  @override
  Widget build(BuildContext context) {
    if (stats.count == 0) return const SizedBox.shrink();
    final maxV = stats.histogram.reduce((a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('توزيع الدرجات', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 10; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text('${stats.histogram[i]}', style: const TextStyle(fontSize: 9)),
                        const SizedBox(height: 2),
                        Container(
                          height: maxV == 0 ? 2 : (44 * stats.histogram[i] / maxV) + 2,
                          decoration: BoxDecoration(
                            color: i >= 6 ? scheme.primary : scheme.error,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        Text('${i * 10}', style: const TextStyle(fontSize: 8)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.exam});
  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.attempts.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Column(children: [
        for (final a in state.attempts) ...[
          _AttemptRow(attempt: a),
          const Divider(height: 1),
        ],
      ]),
    );
  }
}

/// صف نتيجة طالب واحد — يُعيد حساب التصحيح من المفتاح الحالي (يشمل الأسئلة الملغاة).
class _AttemptRow extends StatelessWidget {
  const _AttemptRow({required this.attempt});
  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final g = state.graded(attempt);
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      dense: true,
      leading: Icon(
        attempt.needsReview ? Icons.error_outline : Icons.check_circle_outline,
        color: attempt.needsReview ? scheme.error : scheme.primary,
      ),
      title: Text('${attempt.studentNumber ?? '—'}  ${attempt.studentName ?? ''}'),
      subtitle: Text(
        '${g.correct} صحيح · ${g.wrong} خطأ · ${g.blank} فارغ'
        '${attempt.manuallyEdited ? ' · تعديل يدوي' : ''}',
      ),
      trailing: Text(
        '${attempt.score.toStringAsFixed(1)}/${attempt.total.toStringAsFixed(0)}  (${attempt.percent.toStringAsFixed(1)}%)',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _EditAttemptSheet(attempt: attempt),
      ),
    );
  }
}

class _EditAttemptSheet extends StatelessWidget {
  const _EditAttemptSheet({required this.attempt});
  final Attempt attempt;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final exam = state.active!;
    final labelsOf = (Question q) => q.type == QuestionType.yesNo
        ? const ['نعم', 'لا']
        : (exam.optionLabels == 'en' ? const ['A', 'B', 'C', 'D', 'E'] : const ['أ', 'ب', 'ج', 'د', 'هـ']);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('تعديل يدوي — الطالب ${attempt.studentNumber ?? '؟'}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        Text('الدرجة الحالية ${attempt.score.toStringAsFixed(1)} / ${attempt.total.toStringAsFixed(0)} (${attempt.percent.toStringAsFixed(1)}%)',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < exam.questions.length; i++)
                Builder(builder: (context) {
                  final q = exam.questions[i];
                  final a = i < attempt.answers.length ? attempt.answers[i] : null;
                  final flagged = attempt.flagged.any((f) => f.index == i);
                  final correct = a != null && a == q.correctOption;
                  final labels = labelsOf(q);
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      int? next;
                      if (a == null) {
                        next = 0;
                      } else if (a >= q.optionCount - 1) {
                        next = null;
                      } else {
                        next = a + 1;
                      }
                      state.overrideAnswer(attempt, i, next);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: flagged
                            ? scheme.tertiaryContainer
                            : a == null
                                ? scheme.surfaceContainerHighest
                                : (correct ? scheme.primaryContainer : scheme.errorContainer),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${i + 1}: ${a == null ? '—' : labels[a]}${flagged ? ' ⚠' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  );
                }),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.analysis, required this.exam});
  final QuestionAnalysis analysis;
  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final q = exam.questions[analysis.index];
    final scheme = Theme.of(context).colorScheme;
    final total = analysis.distribution.fold<int>(0, (a, b) => a + b);

    if (analysis.cancelled) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text('سؤال ${analysis.index + 1} — ملغى'),
          subtitle: const Text('لا يُحتسب في الدرجات'),
          trailing: TextButton(onPressed: () => state.toggleCancelQuestion(analysis.index), child: const Text('إعادة احتساب')),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('سؤال ${analysis.index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text(q.type == QuestionType.yesNo ? 'نعم/لا' : 'دائرة', style: Theme.of(context).textTheme.labelSmall),
            const Spacer(),
            Text('صحيح ${(analysis.difficulty * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                for (var o = 0; o < analysis.distribution.length; o++)
                  Expanded(
                    flex: total == 0 ? 1 : (analysis.distribution[o] == 0 ? 0 : analysis.distribution[o]),
                    child: Container(color: o == q.correctOption ? scheme.primary : scheme.error),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 4, children: [
            Text('صعوبة p = ${analysis.difficulty.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
            Text('تمييز D = ${analysis.discrimination.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
            Text('توزيع: ${analysis.distribution.join(' / ')}', style: Theme.of(context).textTheme.bodySmall),
          ]),
          if (analysis.flags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '⚠ ${analysis.flags.map((f) => QuestionAnalysis.flagLabels[f] ?? f).join(' · ')}',
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => state.toggleCancelQuestion(analysis.index),
              child: const Text('إلغاء السؤال وإعادة الحساب'),
            ),
          ),
        ]),
      ),
    );
  }
}
