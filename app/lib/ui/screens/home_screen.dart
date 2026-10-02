import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../../main.dart' show kLogoAsset;
import 'exam_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(kLogoAsset, width: 30, height: 30),
          ),
          const SizedBox(width: 10),
          const Text('مُصحِّح'),
        ]),
        actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(child: Text('${state.exams.length} اختبار', style: theme.textTheme.labelMedium)),
        ),
      ]),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _Hero(),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Chip(text: '${state.attempts.length} ورقة في الاختبار الحالي'),
                  const _Chip(text: 'يعمل دون إنترنت', ok: true),
                  const _Chip(text: 'لا يُرفع شيء للسحابة', ok: true),
                ]),
                const SizedBox(height: 18),
                Text('اختباراتي', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (state.exams.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Center(child: Text('لا توجد اختبارات — اضغط «اختبار جديد»')),
                    ),
                  ),
                for (final exam in state.exams) _ExamCard(exam: exam),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExamWizardScreen())),
        icon: const Icon(Icons.add),
        label: const Text('اختبار جديد'),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)]),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('صحّح بالكاميرا', style: TextStyle(color: scheme.onPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'أدخل الاختبار، اطبع الورقة، صوّر أوراق الطلاب — والدرجات جاهزة فورًا.',
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.95), fontSize: 12.5, height: 1.7),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          width: 74, height: 74,
          decoration: BoxDecoration(
            color: scheme.onPrimary.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(6),
          child: Image.asset(kLogoAsset, fit: BoxFit.contain),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.ok = false});
  final String text;
  final bool ok;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: ok ? scheme.onPrimaryContainer : scheme.onSurfaceVariant)),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam});
  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final isActive = state.active?.id == exam.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text('${exam.serial}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        title: Text(exam.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          if (exam.subject.isNotEmpty) exam.subject,
          if (exam.gradeLabel.isNotEmpty) exam.gradeLabel,
          '${exam.questions.length} سؤالًا',
          'مفتاح ${exam.answeredKeyCount}/${exam.questions.length}',
        ].join(' · ')),
        trailing: isActive ? const Icon(Icons.check_circle) : const Icon(Icons.chevron_left),
        onTap: () async {
          await state.selectExam(exam);
          if (context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExamScreen()));
          }
        },
      ),
    );
  }
}
