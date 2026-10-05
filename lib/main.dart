import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_state.dart';
import 'pages/settings.dart';
import 'pages/tasks.dart';
import 'pages/times.dart';
import 'pages/today.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(SunnahApp(state: state));
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  var cs = ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D6B), brightness: b);
  cs = cs.copyWith(surface: dark ? const Color(0xFF0F1815) : const Color(0xFFF7F5EE));
  final base = ThemeData(useMaterial3: true, colorScheme: cs, brightness: b);
  return base.copyWith(
    scaffoldBackgroundColor: cs.surface,
    textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(backgroundColor: cs.surface, elevation: 0, scrolledUnderElevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF141F1B) : Colors.white,
      indicatorColor: cs.primaryContainer,
      height: 68,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? const Color(0xFF141F1B) : Colors.white,
      indicatorColor: cs.primaryContainer,
    ),
  );
}

class SunnahApp extends StatelessWidget {
  final AppState state;
  const SunnahApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final mode = switch (state.s.theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return MaterialApp(
          title: 'هَدْي',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          home: Shell(st: state),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  final AppState st;
  const Shell({super.key, required this.st});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int idx = 0;

  static const _items = <(String, IconData, IconData)>[
    ('اليوم', Icons.today_outlined, Icons.today),
    ('المهام', Icons.checklist_outlined, Icons.checklist),
    ('المواقيت', Icons.access_time, Icons.access_time_filled),
    ('الإعدادات', Icons.settings_outlined, Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    final pages = [
      TodayPage(st: widget.st),
      TasksPage(st: widget.st),
      TimesPage(st: widget.st),
      SettingsPage(st: widget.st),
    ];

    final body = SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: IndexedStack(index: idx, children: pages),
        ),
      ),
    );

    return Scaffold(
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: idx,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => idx = i),
                  destinations: [
                    for (final it in _items)
                      NavigationRailDestination(
                        icon: Icon(it.$2),
                        selectedIcon: Icon(it.$3),
                        label: Text(it.$1),
                      ),
                  ],
                ),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: idx,
              onDestinationSelected: (i) => setState(() => idx = i),
              destinations: [
                for (final it in _items)
                  NavigationDestination(icon: Icon(it.$2), selectedIcon: Icon(it.$3), label: it.$1),
              ],
            ),
    );
  }
}
