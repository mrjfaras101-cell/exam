import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../state/app_state.dart';
import 'key_screen.dart';
import 'results_screen.dart';
import 'scanner_screen.dart';
import 'sheet_screen.dart';

/// تفاصيل الاختبار: الإجراءات الأربعة + قائمة الأسئلة.
class ExamScreen extends StatelessWidget {
  const ExamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final exam = state.active;
    if (exam == null) {
      return const Scaffold(body: Center(child: Text('لا يوجد اختبار محدد')));
    }
    final theme = Theme.of(context);
    final stats = state.classStatsValue;

    return Scaffold(
      appBar: AppBar(title: Text(exam.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text([exam.subject, exam.gradeLabel, exam.examDate].where((e) => e.isNotEmpty).join(' · '),
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                Row(children: [
                  _Stat(value: '${exam.questions.length}', label: 'سؤال'),
                  _Stat(value: '${exam.answeredKeyCount}', label: 'مفتاح مُدخل'),
                  _Stat(value: stats.count == 0 ? '—' : '${stats.mean.toStringAsFixed(0)}%', label: 'متوسط الصف'),
                  _Stat(value: 'رمز ${exam.serial}', label: 'الورقة'),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: [
              _Action(icon: Icons.key_outlined, label: 'مفتاح الإجابة', onTap: () => _push(context, const KeyScreen())),
              _Action(icon: Icons.print_outlined, label: 'الورقة والطباعة', onTap: () => _push(context, const SheetScreen())),
              _Action(icon: Icons.camera_alt, label: 'ابدأ التصحيح', primary: true, onTap: () => _push(context, const ScannerScreen())),
              _Action(icon: Icons.insights_outlined, label: 'النتائج والتحليل', onTap: () => _push(context, const ResultsScreen())),
            ],
          ),
          const SizedBox(height: 18),
          Text('الأسئلة', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var i = 0; i < exam.questions.length; i++) _QuestionRow(exam: exam, index: i),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ]),
      );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: primary ? scheme.primary : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 28, color: primary ? scheme.onPrimary : scheme.onSurface),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: primary ? scheme.onPrimary : scheme.onSurface,
              )),
        ]),
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.exam, required this.index});
  final Exam exam;
  final int index;

  @override
  Widget build(BuildContext context) {
    final q = exam.questions[index];
    final labels = q.type == QuestionType.yesNo
        ? const ['نعم', 'لا']
        : (exam.optionLabels == 'en' ? const ['A', 'B', 'C', 'D', 'E'] : const ['أ', 'ب', 'ج', 'د', 'هـ']);
    final answered = q.correctOption != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(radius: 14, child: Text('${index + 1}', style: const TextStyle(fontSize: 12))),
        title: Text(q.type == QuestionType.yesNo ? 'أجب بنعم أو لا' : 'ضع دائرة (${q.optionCount} خيارات)'),
        subtitle: q.cancelled ? const Text('ملغى — لا يُحسب') : null,
        trailing: Text(
          answered ? labels[q.correctOption!] : 'لم يُحدَّد',
          style: TextStyle(fontWeight: FontWeight.w700, color: answered ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

/// معالج إنشاء اختبار جديد (اسم، صف، عدد الأسئلة، الأنواع) — ثلاث خطوات قصيرة.
class ExamWizardScreen extends StatefulWidget {
  const ExamWizardScreen({super.key});
  @override
  State<ExamWizardScreen> createState() => _ExamWizardScreenState();
}

class _ExamWizardScreenState extends State<ExamWizardScreen> {
  final nameCtl = TextEditingController(text: 'اختبار قصير');
  final subjectCtl = TextEditingController();
  final gradeCtl = TextEditingController(text: 'الصف السابع / أ');
  final teacherCtl = TextEditingController();
  final dateCtl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
  int questionCount = 10;
  int optionCount = 4;
  bool yesNoOnly = false;
  bool mix = true;
  String labels = 'ar';

  @override
  void dispose() {
    nameCtl.dispose();
    subjectCtl.dispose();
    gradeCtl.dispose();
    teacherCtl.dispose();
    dateCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('اختبار جديد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'اسم الاختبار')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: subjectCtl, decoration: const InputDecoration(labelText: 'المادة'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: gradeCtl, decoration: const InputDecoration(labelText: 'الصف / الشعبة'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: teacherCtl, decoration: const InputDecoration(labelText: 'المعلم'))),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'التاريخ'),
                controller: dateCtl,
                readOnly: true,
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Text('عدد الأسئلة: $questionCount', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: questionCount.toDouble(),
            min: 1,
            max: 20,
            divisions: 19,
            label: '$questionCount',
            onChanged: (v) => setState(() => questionCount = v.round()),
          ),
          const SizedBox(height: 6),
          Text('نوع الأسئلة', style: Theme.of(context).textTheme.titleSmall),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'choice', label: Text('دائرة')),
              ButtonSegment<String>(value: 'mix', label: Text('مزيج')),
              ButtonSegment<String>(value: 'yesno', label: Text('نعم/لا')),
            ],
            selected: {yesNoOnly ? 'yesno' : (mix ? 'mix' : 'choice')},
            onSelectionChanged: (s) => setState(() {
              final v = s.first;
              yesNoOnly = v == 'yesno';
              mix = v == 'mix';
            }),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: optionCount,
                decoration: const InputDecoration(labelText: 'عدد خيارات «دائرة»'),
                items: const [2, 3, 4, 5].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                onChanged: (v) => setState(() => optionCount = v ?? 4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: labels,
                decoration: const InputDecoration(labelText: 'رموز الخيارات'),
                items: const [
                  DropdownMenuItem(value: 'ar', child: Text('أ ب ج د')),
                  DropdownMenuItem(value: 'en', child: Text('A B C D')),
                ],
                onChanged: (v) => setState(() => labels = v ?? 'ar'),
              ),
            ),
          ]),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () async {
              final questions = <Question>[];
              for (var i = 0; i < questionCount; i++) {
                final isYesNo = yesNoOnly || (mix && i % 3 == 2);
                questions.add(Question(
                  type: isYesNo ? QuestionType.yesNo : QuestionType.choice,
                  options: isYesNo ? 2 : optionCount,
                ));
              }
              final serial = (state.exams.length + 3) % 32;
              final exam = Exam(
                name: nameCtl.text.trim().isEmpty ? 'اختبار' : nameCtl.text.trim(),
                subject: subjectCtl.text.trim(),
                gradeLabel: gradeCtl.text.trim(),
                teacher: teacherCtl.text.trim(),
                examDate: dateCtl.text,
                serial: serial,
                optionLabels: labels,
                questions: questions,
              );
              await state.createExam(exam);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم إنشاء الاختبار — أدخل مفتاح الإجابة ثم اطبع الورقة')),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('إنشاء الاختبار'),
          ),
          const SizedBox(height: 10),
          const Text(
            'ملاحظة: يُطبع على الورقة «رمز الورقة» (من 0 إلى 31) ليتعرّف التطبيق على الاختبار آليًا عند المسح.',
            style: TextStyle(fontSize: 12, height: 1.7),
          ),
        ],
      ),
    );
  }
}
