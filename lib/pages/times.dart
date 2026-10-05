import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets.dart';

class TimesPage extends StatelessWidget {
  final AppState st;
  const TimesPage({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final today = dayOnly(DateTime.now());
        final p = st.dayFor(today);
        final next = st.nextPrayer(DateTime.now());
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final place = st.s.auto
            ? (st.s.place.isNotEmpty ? st.s.place : (st.s.lat != null ? 'موقعك الحالي' : 'لم يُحدَّد الموقع'))
            : [st.s.city, st.s.country].where((e) => e.trim().isNotEmpty).join('، ');

        Widget row(String key, String label, DateTime t, {IconData icon = Icons.schedule, bool sub = false}) {
          final isNext = key == next.key && !sub;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              color: isNext ? cs.primaryContainer.withAlpha(cs.brightness == Brightness.dark ? 70 : 130) : null,
              borderColor: isNext ? cs.primary : null,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: sub ? 10 : 14),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: isNext ? cs.primary : Theme.of(context).hintColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: (sub ? tt.bodyMedium : tt.titleMedium)?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (isNext)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: Text('القادمة', style: tt.labelSmall?.copyWith(color: cs.primary)),
                    ),
                  Text(fmtTime(t, st.s.h24), style: (sub ? tt.titleSmall : tt.titleLarge)?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            PageTitle(
              'مواقيت الصلاة',
              subtitle: place.isEmpty ? 'حدّد المدينة من الإعدادات' : place,
              trailing: st.loadingTimes
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                  : IconButton.filledTonal(
                      tooltip: 'تحديث المواقيت',
                      onPressed: () => st.refreshTimes(force: true),
                      icon: const Icon(Icons.refresh),
                    ),
            ),
            if (st.timesError != null && !st.hasReal(today))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  color: cs.errorContainer.withAlpha(90),
                  borderColor: cs.error.withAlpha(80),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: cs.error),
                      const SizedBox(width: 10),
                      Expanded(child: Text(st.timesError!, style: tt.bodySmall)),
                      if (st.s.auto)
                        TextButton(onPressed: () => st.detectLocation(), child: const Text('تحديد موقعي')),
                    ],
                  ),
                ),
              ),
            row('fajr', 'الفجر', p.fajr, icon: Icons.wb_twilight),
            row('sunrise', 'الشروق', p.sunrise, icon: Icons.wb_sunny_outlined, sub: true),
            row('dhuhr', 'الظهر', p.dhuhr, icon: Icons.light_mode_outlined),
            row('asr', 'العصر', p.asr, icon: Icons.wb_sunny),
            row('maghrib', 'المغرب', p.maghrib, icon: Icons.nights_stay_outlined),
            row('isha', 'العشاء', p.isha, icon: Icons.bedtime_outlined),
            const SizedBox(height: 10),
            Text('أوقات نافلة', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            row('duha', 'بداية وقت الضحى', p.duha, icon: Icons.wb_sunny_outlined, sub: true),
            row('third', 'الثلث الأخير من الليل (القيام)', p.lastThird, icon: Icons.dark_mode_outlined, sub: true),
            const SizedBox(height: 8),
            Text(
              p.approx
                  ? 'هذه مواقيت تقريبية مؤقتة حتى يتم تحديد موقعك.'
                  : 'طريقة الحساب: ${st.spec.label}. تُحسب المواقيت فلكياً داخل جهازك (تعمل دون إنترنت) وبتوقيت جهازك الحالي.',
              style: tt.bodySmall?.copyWith(color: Theme.of(context).hintColor),
            ),
          ],
        );
      },
    );
  }
}
