import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets.dart';

/// يوحّد الحروف العربية لبحث متسامح: بلا تشكيل، وأ/إ/آ=ا، ة=ه، ى=ي.
String normAr(String s) {
  return s
      .replaceAll(RegExp('[\u064B-\u0652\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .toLowerCase()
      .trim();
}

class TasksPage extends StatefulWidget {
  final AppState st;
  const TasksPage({super.key, required this.st});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  AppState get st => widget.st;

  final TextEditingController _q = TextEditingController();
  final Set<Cat> _cats = {};
  String _status = 'all'; // all | on | off
  bool _remindOnly = false;

  bool get _filtered => _cats.isNotEmpty || _status != 'all' || _remindOnly;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _match(Occ o) {
    final t = o.task;
    if (_cats.isNotEmpty && !_cats.contains(t.cat)) return false;
    if (_status == 'on' && !t.enabled) return false;
    if (_status == 'off' && t.enabled) return false;
    if (_remindOnly && !t.remind) return false;
    final q = normAr(_q.text);
    if (q.isNotEmpty) {
      final hay = normAr('${t.title} ${t.note} ${catNames[t.cat]}');
      if (!hay.contains(q)) return false;
    }
    return true;
  }

  Future<void> _openFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void both(VoidCallback f) {
            setSheet(f);
            setState(() {});
          }

          final tt = Theme.of(ctx).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تصفية المهام', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Text('الحالة', style: tt.labelLarge),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('الكل')),
                      ButtonSegment(value: 'on', label: Text('مفعّلة')),
                      ButtonSegment(value: 'off', label: Text('موقوفة')),
                    ],
                    selected: {_status},
                    onSelectionChanged: (v) => both(() => _status = v.first),
                  ),
                  const SizedBox(height: 14),
                  Text('الفئة', style: tt.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in Cat.values)
                        FilterChip(
                          avatar: Icon(catIcon(c), size: 16, color: catColor(c)),
                          label: Text(catNames[c]!),
                          selected: _cats.contains(c),
                          onSelected: (v) => both(() => v ? _cats.add(c) : _cats.remove(c)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('التي لها تنبيه فقط'),
                    value: _remindOnly,
                    onChanged: (v) => both(() => _remindOnly = v),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    TextButton.icon(
                      onPressed: () => both(() {
                        _cats.clear();
                        _status = 'all';
                        _remindOnly = false;
                      }),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('مسح التصفية'),
                    ),
                    const Spacer(),
                    FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تم')),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final today = dayOnly(DateTime.now());
        final all = st.occurrences(today, all: true);
        final list = all.where(_match).toList();
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('مهمة جديدة'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              const PageTitle('مهامي', subtitle: 'عدّل الجدول كما يناسب يومك، أو أوقف ما لا تحتاجه.'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'ابحث في المهام…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _q.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_q.clear),
                            ),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _filtered,
                  smallSize: 10,
                  child: IconButton.filledTonal(
                    onPressed: _openFilter,
                    tooltip: 'تصفية',
                    icon: const Icon(Icons.filter_list),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              if (_filtered || _q.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${list.length} من ${all.length} مهمة', style: tt.bodySmall?.copyWith(color: Theme.of(context).hintColor)),
                ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('لا توجد مهام مطابقة', style: tt.bodyLarge?.copyWith(color: Theme.of(context).hintColor))),
                ),
              for (final o in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    onTap: () => _edit(context, o.task),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Opacity(
                      opacity: o.task.enabled ? 1 : 0.5,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: catColor(o.task.cat).withAlpha(36),
                            child: Icon(catIcon(o.task.cat), size: 20, color: catColor(o.task.cat)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.task.title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  _subtitle(o),
                                  style: tt.bodySmall?.copyWith(color: Theme.of(context).hintColor),
                                ),
                              ],
                            ),
                          ),
                          if (o.task.remind) Icon(Icons.notifications_active_outlined, size: 18, color: cs.primary),
                          Switch(
                            value: o.task.enabled,
                            onChanged: (v) => st.toggleTask(o.task.id, v),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _subtitle(Occ o) {
    final t = o.task;
    final parts = <String>[fmtTime(o.start, st.s.h24), durLabel(t.duration), catNames[t.cat]!];
    if (t.days.isNotEmpty) {
      final ds = t.days.toList()..sort();
      parts.add(ds.map((d) => weekdayNames[d - 1]).join(' و'));
    }
    return parts.join('  ·  ');
  }

  Future<void> _edit(BuildContext context, Task? task) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TaskEditor(task: task?.copy(), h24: st.s.h24),
    );
    if (result == null) return;
    if (result.delete && task != null) {
      await st.deleteTask(task.id);
    } else if (result.task != null) {
      await st.upsertTask(result.task!);
    }
  }
}

class _EditResult {
  final Task? task;
  final bool delete;
  _EditResult({this.task, this.delete = false});
}

class _TaskEditor extends StatefulWidget {
  final Task? task;
  final bool h24;
  const _TaskEditor({required this.task, required this.h24});

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late Task t;
  late TextEditingController title, note;
  late final bool isNew;

  @override
  void initState() {
    super.initState();
    isNew = widget.task == null;
    t = widget.task ??
        Task(
          id: 'new',
          title: '',
          cat: Cat.personal,
          anchor: Anchor.fixed,
          offset: 9 * 60,
          duration: 30,
          remind: true,
        );
    title = TextEditingController(text: t.title);
    note = TextEditingController(text: t.note);
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  String _offsetText() {
    final name = anchorShort[t.anchor] ?? '';
    if (t.offset == 0) return 'عند $name';
    if (t.offset > 0) return 'بعد ${durLabel(t.offset)} من $name';
    return 'قبل ${durLabel(-t.offset)} من $name';
  }

  Future<void> _pickTime() async {
    final r = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (t.offset ~/ 60) % 24, minute: t.offset % 60),
    );
    if (r != null) setState(() => t.offset = r.hour * 60 + r.minute);
  }

  void _setAnchor(Anchor a) {
    setState(() {
      if (a == Anchor.fixed && t.anchor != Anchor.fixed) {
        t.offset = 9 * 60;
      } else if (a != Anchor.fixed && t.anchor == Anchor.fixed) {
        t.offset = 15;
      }
      t.anchor = a;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isNew ? 'مهمة جديدة' : 'تعديل المهمة', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'اسم المهمة', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<Cat>(
                      isExpanded: true,
                      value: t.cat,
                      items: [
                        for (final c in Cat.values) DropdownMenuItem(value: c, child: Text(catNames[c]!)),
                      ],
                      onChanged: (v) => setState(() => t.cat = v ?? t.cat),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<Anchor>(
                      isExpanded: true,
                      value: t.anchor,
                      items: [
                        for (final a in Anchor.values) DropdownMenuItem(value: a, child: Text(anchorNames[a]!)),
                      ],
                      onChanged: (v) {
                        if (v != null) _setAnchor(v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (t.anchor == Anchor.fixed)
                OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    'الوقت: ${fmtTime(DateTime(2000, 1, 1, (t.offset ~/ 60) % 24, t.offset % 60), widget.h24)}',
                  ),
                )
              else
                StepperField(
                  label: _offsetText(),
                  value: t.offset,
                  min: -240,
                  max: 360,
                  step: 5,
                  format: (v) => v == 0 ? '0' : (v > 0 ? '+$v' : '$v'),
                  onChanged: (v) => setState(() => t.offset = v),
                ),
              const SizedBox(height: 8),
              StepperField(
                label: 'المدة',
                value: t.duration,
                min: 5,
                max: 600,
                step: 5,
                format: durLabel,
                onChanged: (v) => setState(() => t.duration = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تنبيه قبل المهمة'),
                value: t.remind,
                onChanged: (v) => setState(() => t.remind = v),
              ),
              Text('الأيام (بلا اختيار = كل الأيام)', style: tt.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(weekdayNames[d - 1]),
                      selected: t.days.contains(d),
                      onSelected: (v) => setState(() {
                        if (v) {
                          t.days.add(d);
                        } else {
                          t.days.remove(d);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (!isNew)
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, _EditResult(delete: true)),
                      icon: Icon(Icons.delete_outline, color: cs.error),
                      label: Text('حذف', style: TextStyle(color: cs.error)),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final name = title.text.trim();
                      if (name.isEmpty) return;
                      t.title = name;
                      t.note = note.text.trim();
                      final id = isNew ? 'u${DateTime.now().microsecondsSinceEpoch}' : t.id;
                      final saved = Task(
                        id: id,
                        title: t.title,
                        note: t.note,
                        cat: t.cat,
                        anchor: t.anchor,
                        offset: t.offset,
                        duration: t.duration,
                        remind: t.remind,
                        enabled: true,
                        days: t.days,
                        builtin: t.builtin,
                      );
                      saved.enabled = widget.task?.enabled ?? true;
                      Navigator.pop(context, _EditResult(task: saved));
                    },
                    child: const Text('حفظ'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
