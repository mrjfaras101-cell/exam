import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/repository.dart';
import '../../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final exam = state.active;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('عتبات القراءة', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          _ThresholdSlider(
            label: 'عتبة «مظلّلة»',
            value: state.tHigh,
            min: 0.25,
            max: 0.7,
            hint: 'أعلى = أكثر تسامحًا مع التظليل الخفيف، لكن أكثر حساسية لتسرّب الحبر من الورق.',
            onChanged: (v) => state.updateReadSettings(tHigh: v),
          ),
          _ThresholdSlider(
            label: 'عتبة «خفيف/مشكوك»',
            value: state.tLight,
            min: 0.05,
            max: 0.4,
            hint: 'ما دونها يُعدّ فراغًا. ارفعها إذا كان الطلاب يظلّلون بقلم باهت.',
            onChanged: (v) => state.updateReadSettings(tLight: v),
          ),
          _ThresholdSlider(
            label: 'حساسية الحبر مقابل الورق',
            value: state.inkRatio,
            min: 0.55,
            max: 0.9,
            hint: 'لورق المدرسة الفوتوكوبي الداكن: اخفضها قليلًا. للطباعة الفاتحة: ارفعها.',
            onChanged: (v) => state.updateReadSettings(inkRatio: v),
          ),
          const SizedBox(height: 18),
          Text('الدرجات', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('خصم على الإجابة الخطأ'),
            subtitle: const Text('خصم 0.25 من وزن السؤال لكل إجابة خطأ (الفارغ لا يُخصم)'),
            value: exam?.negativeMarking ?? false,
            onChanged: exam == null ? null : (v) => state.setNegativeMarking(v),
          ),
          const SizedBox(height: 6),
          Row(children: [
            const Text('حد النجاح (من 100)'),
            const Spacer(),
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: '${state.passMark}',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onFieldSubmitted: (v) => state.setPassMark(int.tryParse(v) ?? 60),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Text('البيانات والخصوصية', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('لا يُرفع أي شيء إلى أي خادم. كل المعالجة على الجهاز، والصور لا تُحفظ افتراضيًا.',
                    style: TextStyle(fontSize: 12.5, height: 1.8)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final dir = await getTemporaryDirectory();
                        final file = File(p.join(dir.path, 'musahhih-backup.json'));
                        await file.writeAsString(await Backup.exportJson(state.repo), flush: true);
                        await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية — مُصحِّح');
                      },
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text('نسخة احتياطية'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تفريغ النتائج'),
                  content: const Text('حذف كل نتائج الاختبار الحالي؟ (الاختبار ومفتاحه يبقيان)'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
                  ],
                ),
              );
              if (ok == true) await state.clearAttempts();
            },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('تفريغ نتائج الاختبار الحالي'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('حذف الاختبار'),
                  content: const Text('حذف الاختبار وكل نتائجه نهائيًا؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
                  ],
                ),
              );
              if (ok == true) await state.deleteActiveExam();
            },
            style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف الاختبار الحالي'),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text('مُصحِّح — الإصدار 1.0 · محرّك القراءة نسخة القالب 1 · يعمل دون إنترنت',
                style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final double value, min, max;
  final String hint;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label),
        const Spacer(),
        Text(value.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
      Slider(value: value.clamp(min, max), min: min, max: max, divisions: ((max - min) * 100).round(), onChanged: onChanged),
      Text(hint, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
    ]);
  }
}
