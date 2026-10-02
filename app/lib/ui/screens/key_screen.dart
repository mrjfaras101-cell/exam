import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../state/app_state.dart';
import 'scanner_screen.dart';

/// إدخال مفتاح الإجابة: لمس الفقاعة الصحيحة، أو مسح «ورقة المفتاح» بالكاميرا.
class KeyScreen extends StatelessWidget {
  const KeyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final exam = state.active;
    if (exam == null) return const Scaffold(body: Center(child: Text('لا يوجد اختبار')));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('مفتاح الإجابة')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(
            'المس رمز الإجابة الصحيحة لكل سؤال — أو اطبع «ورقة المفتاح» ومسحها بالكاميرا (أسرع للاختبارات الطويلة).',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.7),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScannerScreen(keyMode: true))),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('مسح ورقة المفتاح'),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          for (var i = 0; i < exam.questions.length; i++) _KeyRow(exam: exam, index: i),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Text('${exam.answeredKeyCount} / ${exam.questions.length} مُجاب',
                  style: theme.textTheme.bodySmall),
            ),
            FilledButton.icon(
              onPressed: exam.keyComplete
                  ? () async {
                      await state.saveKey(exam);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ مفتاح الإجابة ✓')));
                        Navigator.of(context).pop();
                      }
                    }
                  : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ المفتاح'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.exam, required this.index});
  final Exam exam;
  final int index;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final q = exam.questions[index];
    final labels = q.type == QuestionType.yesNo
        ? const ['نعم', 'لا']
        : (exam.optionLabels == 'en' ? const ['A', 'B', 'C', 'D', 'E'] : const ['أ', 'ب', 'ج', 'د', 'هـ']);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          CircleAvatar(radius: 14, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                for (var o = 0; o < q.optionCount; o++)
                  ChoiceChip(
                    label: Text(labels[o]),
                    selected: q.correctOption == o,
                    onSelected: (_) {
                      q.correctOption = q.correctOption == o ? null : o;
                      state.saveKey(exam);
                    },
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
