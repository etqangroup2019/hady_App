import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets.dart';

class TasksPage extends StatelessWidget {
  final AppState st;
  const TasksPage({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final today = dayOnly(DateTime.now());
        final list = st.occurrences(today, all: true);
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
