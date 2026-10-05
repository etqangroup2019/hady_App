import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets.dart';

class TodayPage extends StatefulWidget {
  final AppState st;
  const TodayPage({super.key, required this.st});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late DateTime day;
  Timer? _regroup;

  @override
  void initState() {
    super.initState();
    day = dayOnly(DateTime.now());
    widget.st.ensureDay(day);
    // يعيد ترتيب القائمة مع مرور الوقت (مهمة بدأت/انتهت).
    _regroup = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _regroup?.cancel();
    super.dispose();
  }

  Widget _header(String text, IconData icon, int count) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(text, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
          const SizedBox(width: 8),
          Text('$count', style: tt.labelMedium?.copyWith(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }

  List<Widget> _groups(AppState st, List<Occ> occ, bool isToday) {
    Widget tile(Occ o) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TaskTile(st: st, o: o, day: day),
        );

    // أيام أخرى: ترتيب زمني بسيط.
    if (!isToday) return [for (final o in occ) tile(o)];

    final now = DateTime.now();
    final current = <Occ>[], upcoming = <Occ>[], finished = <Occ>[];
    for (final o in occ) {
      final answered = st.isDone(o.task.id, day);
      if (answered || !o.end.isAfter(now)) {
        finished.add(o);
      } else if (!o.start.isAfter(now)) {
        current.add(o);
      } else {
        upcoming.add(o);
      }
    }

    return [
      if (current.isNotEmpty) ...[
        _header('الآن', Icons.play_circle_outline, current.length),
        for (final o in current) tile(o),
      ],
      if (upcoming.isNotEmpty) ...[
        _header('القادمة', Icons.schedule, upcoming.length),
        for (final o in upcoming) tile(o),
      ],
      if (finished.isNotEmpty) ...[
        _header('أُنجزت أو انتهى وقتها', Icons.task_alt, finished.length),
        for (final o in finished) tile(o),
      ],
    ];
  }

  void _go(DateTime d) {
    setState(() => day = dayOnly(d));
    widget.st.ensureDay(day);
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final today = dayOnly(DateTime.now());
        final isToday = day == today;
        final p = st.dayFor(day);
        final occ = st.occurrences(day);
        final (done, total) = st.progress(day);
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'اليوم السابق',
                  onPressed: () => _go(addDays(day, -1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        isToday ? 'اليوم · ${weekdayNames[day.weekday - 1]}' : weekdayNames[day.weekday - 1],
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        p.hijri.isEmpty ? dateLabel(day) : '${dateLabel(day)}  ·  ${p.hijri} هـ',
                        style: tt.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'اليوم التالي',
                  onPressed: () => _go(addDays(day, 1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (!isToday)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: () => _go(today),
                  icon: const Icon(Icons.today_outlined, size: 18),
                  label: const Text('العودة إلى اليوم'),
                ),
              ),
            const SizedBox(height: 8),
            if (st.timesError != null && !st.hasReal(day))
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
                    ],
                  ),
                ),
              ),
            _SummaryCard(st: st, done: done, total: total, showNext: isToday),
            const SizedBox(height: 12),
            _WeekStrip(st: st, selected: day, onPick: _go),
            const SizedBox(height: 18),
            if (occ.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('لا توجد مهام لهذا اليوم. أضف مهامك من شاشة «المهام».', style: tt.bodyMedium),
                ),
              ),
            ..._groups(st, occ, isToday),
          ],
        );
      },
    );
  }
}

// ───────────────────────── بطاقة الملخص ─────────────────────────

class _SummaryCard extends StatefulWidget {
  final AppState st;
  final int done, total;
  final bool showNext;
  const _SummaryCard({required this.st, required this.done, required this.total, required this.showNext});

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.showNext) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _countdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final st = widget.st;
    final v = widget.total == 0 ? 0.0 : widget.done / widget.total;
    final now = DateTime.now();
    final next = st.nextPrayer(now);

    return Panel(
      color: cs.primaryContainer.withAlpha(cs.brightness == Brightness.dark ? 70 : 120),
      borderColor: cs.primary.withAlpha(50),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: v,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: cs.primary.withAlpha(35),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(v * 100).round()}%', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${widget.done}/${widget.total}', style: tt.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: widget.showNext
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الصلاة القادمة', style: tt.bodySmall),
                      Text('${next.name} · ${fmtTime(next.time, st.s.h24)}',
                          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          _countdown(next.time.difference(now)),
                          style: tt.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إنجاز اليوم', style: tt.bodySmall),
                      Text(
                        widget.total == 0
                            ? '—'
                            : widget.done == widget.total
                                ? 'أتممت كل المهام'
                                : 'أنجزت ${widget.done} من ${widget.total}',
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── شريط الأسبوع ─────────────────────────

class _WeekStrip extends StatelessWidget {
  final AppState st;
  final DateTime selected;
  final ValueChanged<DateTime> onPick;
  const _WeekStrip({required this.st, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final today = dayOnly(DateTime.now());
    final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];

    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: Builder(builder: (context) {
              final (done, total) = st.progress(d);
              final v = total == 0 ? 0.0 : done / total;
              final sel = d == selected;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onPick(d),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: sel ? cs.primaryContainer.withAlpha(150) : Colors.transparent,
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          weekdayShort[d.weekday - 1],
                          style: tt.labelSmall?.copyWith(fontWeight: sel ? FontWeight.w800 : null),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          value: v,
                          strokeWidth: 4,
                          backgroundColor: cs.primary.withAlpha(30),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${d.day}', style: tt.labelSmall?.copyWith(fontWeight: sel ? FontWeight.w800 : null)),
                    ],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

// ───────────────────────── صف المهمة ─────────────────────────

class _TaskTile extends StatelessWidget {
  final AppState st;
  final Occ o;
  final DateTime day;
  const _TaskTile({required this.st, required this.o, required this.day});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = o.task;
    final now = DateTime.now();
    final done = st.isDone(t.id, day);
    final current = dayOnly(now) == day && !now.isBefore(o.start) && now.isBefore(o.end);
    final missed = !done && o.end.isBefore(now);
    final color = catColor(t.cat);

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: current ? cs.primaryContainer.withAlpha(cs.brightness == Brightness.dark ? 60 : 110) : null,
      borderColor: current ? cs.primary : null,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              children: [
                Text(fmtTime(o.start, st.s.h24), style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(durLabel(t.duration), style: tt.labelSmall?.copyWith(color: Theme.of(context).hintColor)),
              ],
            ),
          ),
          Container(
            width: 3,
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withAlpha(36),
            child: Icon(catIcon(t.cat), size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? Theme.of(context).hintColor : null,
                  ),
                ),
                if (t.note.isNotEmpty)
                  Text(t.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
                const SizedBox(height: 8),
                FilterChip(
                  selected: done,
                  showCheckmark: true,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(done ? 'نعم' : (missed ? 'لا' : 'أنجزتها؟')),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: done ? cs.onPrimaryContainer : (missed ? cs.error : null),
                  ),
                  side: BorderSide(color: missed && !done ? cs.error.withAlpha(120) : cs.outlineVariant),
                  onSelected: (v) => st.setDone(t.id, day, v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
