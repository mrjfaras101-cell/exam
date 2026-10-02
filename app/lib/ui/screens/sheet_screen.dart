import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../sheet/pdf_export.dart';
import '../../sheet/sheet_painter.dart';
import '../../state/app_state.dart';

/// معاينة الورقة كما ستُطبع (بالمليمتر) + الطباعة/PDF/المشاركة.
class SheetScreen extends StatefulWidget {
  const SheetScreen({super.key});
  @override
  State<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends State<SheetScreen> {
  bool keySheet = false;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final exam = state.active;
    if (exam == null) return const Scaffold(body: Center(child: Text('لا يوجد اختبار')));
    final theme = Theme.of(context);
    final template = state.template(isKey: keySheet);

    return Scaffold(
      appBar: AppBar(title: const Text('الورقة والطباعة')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'قبل الطباعة: اختر مقياس 100% (لا «ملاءمة الصفحة»)، ورق أبيض، وطباعة ليزر إن أمكن. '
              'اطبع ورقة واحدة وامسحها للتأكد، ثم اطبع بقية النسخ.',
              style: TextStyle(fontSize: 12.5, height: 1.8, color: theme.colorScheme.onTertiaryContainer),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: false, label: Text('ورقة الطالب'), icon: Icon(Icons.person_outline)),
              ButtonSegment<bool>(value: true, label: Text('ورقة المفتاح'), icon: Icon(Icons.key_outlined)),
            ],
            selected: {keySheet},
            onSelectionChanged: (s) => setState(() => keySheet = s.first),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 18)],
              ),
              child: AspectRatio(
                aspectRatio: 210 / 297,
                child: LayoutBuilder(
                  builder: (context, constraints) => CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: SheetPainter(
                      template: template,
                      pxPerMm: constraints.maxWidth / 210,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await SheetPdf.print(template, title: '${exam.name}${keySheet ? ' — مفتاح' : ''}');
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print),
                label: const Text('طباعة / PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => SheetPdf.share(template, filename: '${exam.name}-sheet.pdf'),
                icon: const Icon(Icons.ios_share),
                label: const Text('مشاركة'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            'نصيحة: اطبع نسخ المفتاح بلون مختلف من الورق لتفادي خلطها بأوراق الطلاب.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
