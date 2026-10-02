/// نقطة تشغيل تطبيق «مُصحِّح».
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/repository.dart';
import 'state/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/results_screen.dart';
import 'ui/screens/scanner_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await Repository.init();
  final state = AppState(repo);
  await state.load();
  runApp(MusahhihApp(state: state));
}

/// شعار التطبيق (موجود في assets/branding) — يُستخدم في شاشة البداية والترويسة.
const String kLogoAsset = 'assets/branding/logo.png';

class MusahhihApp extends StatelessWidget {
  const MusahhihApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        title: 'مُصحِّح — Basem',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const AppShell(),
      ),
    );
  }
}

/// الهيكل الرئيسي: أربعة تبويبات (الرئيسية، التصحيح، النتائج، الإعدادات).
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  /// تبويبات بُنيت فعليًا — كي لا تُشغَّل الكاميرا قبل فتح شاشة التصحيح.
  final Set<int> visited = {0};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reviewCount = state.attempts.where((a) => a.needsReview).length;

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          const HomeScreen(),
          if (visited.contains(1)) const ScannerScreen() else const SizedBox.shrink(),
          if (visited.contains(2)) const ResultsScreen() else const SizedBox.shrink(),
          if (visited.contains(3)) const SettingsScreen() else const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() {
          index = i;
          visited.add(i);
        }),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: reviewCount > 0,
              label: Text('$reviewCount'),
              child: const Icon(Icons.camera_alt_outlined),
            ),
            selectedIcon: const Icon(Icons.camera_alt),
            label: 'التصحيح',
          ),
          const NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'النتائج'),
          const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}
