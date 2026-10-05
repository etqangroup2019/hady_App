import 'package:flutter/material.dart';

import '../app_state.dart';
import '../bridge.dart';
import '../methods.dart';
import '../models.dart';
import '../widgets.dart';

const _typeInfo = <List<String>>[
  ['pre', 'التنبيه قبل الأذان', 'ينبّهك قبل دخول الوقت بالدقائق التي تحددها'],
  ['adhan', 'وقت الأذان', 'عند دخول وقت كل صلاة'],
  ['iqama', 'الإقامة', 'بعد الأذان بالدقائق التي تحددها لكل صلاة'],
  ['task', 'تنبيه المهام', 'قبل بدء المهام المفعّل لها التنبيه'],
];

class SettingsPage extends StatefulWidget {
  final AppState st;
  const SettingsPage({super.key, required this.st});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController cityC;
  late final TextEditingController countryC;

  AppState get st => widget.st;
  Settings get s => st.s;

  @override
  void initState() {
    super.initState();
    cityC = TextEditingController(text: s.city);
    countryC = TextEditingController(text: s.country);
    st.refreshPushInfo();
  }

  @override
  void dispose() {
    cityC.dispose();
    countryC.dispose();
    super.dispose();
  }

  List<Widget> _pushKids(ColorScheme cs, TextTheme tt, TextStyle? hint) {
    final i = st.pushInfo;
    final supported = i['supported'] == true;
    final configured = i['configured'] == true;
    final standalone = i['standalone'] == true;
    final ios = i['ios'] == true;
    final subscribed = i['subscribed'] == true;
    final count = (i['count'] as num?)?.toInt() ?? 0;

    String status;
    if (Bridge.isNative) {
      status = s.pushOn && subscribed
          ? 'مفعّلة ✓ — $count تنبيه مجدول في منبّه أندرويد، تصلك في وقتها والتطبيق مغلق.'
          : 'اضغط «تفعيل» وامنح إذن الإشعارات والمنبّهات الدقيقة لتصلك التنبيهات والتطبيق مغلق.';
    } else if (!supported) {
      status = ios && !standalone
          ? 'على الآيفون: ثبّت التطبيق أولاً (مشاركة ← إضافة إلى الشاشة الرئيسية) ثم افتحه من الأيقونة.'
          : 'هذا المتصفح لا يدعم التنبيهات في الخلفية.';
    } else if (!configured) {
      status = 'خادم التنبيهات غير مُعدّ بعد (خطوة تُنفَّذ مرة واحدة من صاحب التطبيق، انظر push-worker/README.md).';
    } else if (s.pushOn && subscribed) {
      status = 'مفعّلة ✓ — $count تنبيه مجدول للأيام القادمة، وتصلك حتى والتطبيق مغلق.';
    } else {
      status = 'غير مفعّلة. فعّلها لتصلك التنبيهات في وقتها والتطبيق مغلق.';
    }

    return [
      Text(status, style: tt.bodyMedium),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (supported && configured && !(s.pushOn && subscribed))
          FilledButton.icon(
            onPressed: st.pushBusy ? null : st.enableBackground,
            icon: const Icon(Icons.power_settings_new),
            label: const Text('تفعيل'),
          ),
        if (supported && configured && s.pushOn && subscribed)
          OutlinedButton.icon(
            onPressed: st.pushBusy ? null : st.disableBackground,
            icon: const Icon(Icons.notifications_off_outlined),
            label: const Text('إيقاف'),
          ),
        if (supported && configured)
          OutlinedButton.icon(
            onPressed: st.pushBusy ? null : st.testBackground,
            icon: const Icon(Icons.science_outlined),
            label: const Text('تجربة في الخلفية'),
          ),
      ]),
      if (st.pushBusy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
      if (st.pushMsg != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(st.pushMsg!, style: tt.bodyMedium?.copyWith(color: cs.primary))),
      const SizedBox(height: 10),
      Text(
        Bridge.isNative
            ? 'على أندرويد يكون الصوت هو صوت الإشعارات الافتراضي لكل نوع (تغيّره من إعدادات إشعارات التطبيق في النظام). '
                'عند توقف التنبيهات: أوقف «توفير البطارية» لهذا التطبيق، وفعّل «التشغيل التلقائي» في هواتف شاومي وأوبو وغيرها، '
                'ولا تُغلقه بـ«إيقاف إجباري».'
            : 'في الخلفية يكون صوت التنبيه هو صوت الإشعارات الافتراضي في جهازك (قيد من المتصفحات)، '
        'أما الأصوات التي اخترتها فتُشغَّل عندما يكون التطبيق مفتوحاً. '
        'افتح التطبيق مرة كل بضعة أيام ليتجدد الجدول، وعلى أندرويد استثنِ التطبيق من توفير البطارية.',
        style: hint,
      ),
    ];
  }

  Widget _section(String title, IconData icon, List<Widget> kids) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 10),
              Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 12),
            ...kids,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        final hint = tt.bodySmall?.copyWith(color: Theme.of(context).hintColor);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            const PageTitle('الإعدادات'),

            // ── المظهر ──
            _section('المظهر', Icons.palette_outlined, [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'light', label: Text('نهاري'), icon: Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: 'dark', label: Text('ليلي'), icon: Icon(Icons.dark_mode_outlined)),
                  ButtonSegment(value: 'system', label: Text('تلقائي'), icon: Icon(Icons.brightness_auto_outlined)),
                ],
                selected: {s.theme},
                onSelectionChanged: (v) {
                  s.theme = v.first;
                  st.saveSettings();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('نظام 24 ساعة'),
                value: s.h24,
                onChanged: (v) {
                  s.h24 = v;
                  st.saveSettings();
                },
              ),
            ]),

            // ── الموقع والمواقيت ──
            _section('الموقع وحساب المواقيت', Icons.location_on_outlined, [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تحديد المدينة تلقائياً'),
                subtitle: Text('تُحدَّث المواقيت تلقائياً حسب موقعك', style: hint),
                value: s.auto,
                onChanged: (v) async {
                  s.auto = v;
                  await st.saveSettings();
                  if (v) await st.detectLocation();
                },
              ),
              if (s.auto) ...[
                Text(s.place.isNotEmpty ? s.place : (s.lat != null ? 'تم تحديد موقعك' : 'لم يُحدَّد الموقع بعد')),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final ok = await st.detectLocation();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'تم تحديث موقعك والمواقيت' : 'تعذّر تحديد الموقع')),
                      );
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('تحديث موقعي الآن'),
                  ),
                ),
              ] else ...[
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: cityC,
                      decoration: const InputDecoration(labelText: 'المدينة', hintText: 'مثال: البيضاء', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: countryC,
                      decoration: const InputDecoration(labelText: 'الدولة', hintText: 'مثال: ليبيا', border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('اكتب اسم المدينة والدولة (بالعربية أو الإنجليزية) ثم اضغط بحث. الدولة تساعد على اختيار المدينة الصحيحة.', style: hint),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      s.city = cityC.text.trim();
                      s.country = countryC.text.trim();
                      final ok = await st.geocodeManual();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'تم تحديد المدينة: ${s.place}' : 'تعذّر العثور على المدينة')),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('بحث وحفظ المدينة'),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('اختيار الجهة المعتمدة تلقائياً حسب الدولة'),
                subtitle: Text('الجهة الحالية: ${st.spec.label}', style: hint),
                value: s.autoMethod,
                onChanged: (v) {
                  s.autoMethod = v;
                  st.saveSettings(timesChanged: true);
                },
              ),
              if (s.autoMethod && st.spec.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(st.spec.note, style: hint),
                ),
              if (!s.autoMethod) ...[
                Text('طريقة الحساب', style: tt.labelLarge),
                DropdownButton<int>(
                  isExpanded: true,
                  value: methodNames.containsKey(s.method) ? s.method : 5,
                  items: [
                    for (final e in methodNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    s.method = v;
                    st.saveSettings();
                  },
                ),
                if (s.method == 99) ...[
                  AngleField(
                    label: 'زاوية الفجر',
                    value: s.cFajr,
                    onChanged: (v) {
                      s.cFajr = v;
                      st.saveSettings();
                    },
                  ),
                  AngleField(
                    label: 'زاوية العشاء',
                    value: s.cIsha,
                    onChanged: (v) {
                      s.cIsha = v;
                      st.saveSettings();
                    },
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Text('وقت العصر', style: tt.labelLarge),
              DropdownButton<int>(
                isExpanded: true,
                value: s.school,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('الجمهور (الشافعي والمالكي والحنبلي)')),
                  DropdownMenuItem(value: 1, child: Text('الحنفي')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  s.school = v;
                  st.saveSettings(timesChanged: true);
                },
              ),
              const SizedBox(height: 14),
              Text('تعديل دقيق بالدقائق', style: tt.labelLarge),
              const SizedBox(height: 2),
              Text(
                'لمطابقة المواقيت مع مسجدك أو تطبيق تثق به. يؤثر على الصلوات والتنبيهات والمهام المرتبطة بها.',
                style: hint,
              ),
              const SizedBox(height: 6),
              for (final k in const ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'])
                StepperField(
                  label: prayerNames[k]!,
                  value: s.tune[k] ?? 0,
                  min: -15,
                  max: 15,
                  step: 1,
                  format: (v) => v == 0 ? '0' : (v > 0 ? '+$v' : '$v'),
                  onChanged: (v) {
                    s.tune[k] = v;
                    st.saveSettings();
                  },
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    s.tune.clear();
                    st.saveSettings();
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('تصفير التعديلات'),
                ),
              ),
              const SizedBox(height: 8),
              StepperField(
                label: 'تصحيح التاريخ الهجري (بالأيام)',
                value: s.hijriAdjust,
                min: -2,
                max: 2,
                step: 1,
                format: (v) => v == 0 ? '0' : (v > 0 ? '+$v' : '$v'),
                onChanged: (v) {
                  s.hijriAdjust = v;
                  st.saveSettings();
                },
              ),
            ]),

            // ── التنبيهات ──
            _section('التنبيهات', Icons.notifications_active_outlined, [
              _permissionRow(cs, tt, hint),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.volume_up_outlined, size: 20),
                Expanded(
                  child: Slider(
                    value: s.volume,
                    min: 0.1,
                    max: 1,
                    divisions: 9,
                    label: '${(s.volume * 100).round()}%',
                    onChanged: (v) => setState(() => s.volume = v),
                    onChangeEnd: (_) => st.saveSettings(),
                  ),
                ),
                Text('${(s.volume * 100).round()}%'),
              ]),
              const SizedBox(height: 4),
              Text('الصلوات المفعّل لها التنبيه', style: tt.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final k in prayerKeys)
                    FilterChip(
                      label: Text(prayerNames[k]!),
                      selected: s.prayersOn.contains(k),
                      onSelected: (v) {
                        if (v) {
                          s.prayersOn.add(k);
                        } else {
                          s.prayersOn.remove(k);
                        }
                        st.saveSettings();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              for (final info in _typeInfo) _typeCard(info[0], info[1], info[2], hint),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إشعار دائم بالصلاة القادمة والإقامة'),
                subtitle: Text(
                  'يبقى في درج الإشعارات ويعرض وقت الصلاة القادمة ووقت الإقامة. الوقت المتبقي يتحدّث كل دقيقة '
                  'والتطبيق مفتوح؛ وفي الخلفية يعرض الأوقات ويتبدّل تلقائياً عند كل أذان وإقامة '
                  '(يتطلب تفعيل «التنبيهات في الخلفية» أدناه).',
                  style: hint,
                ),
                value: s.statusOn,
                onChanged: (v) async {
                  final r = await st.setStatusOn(v);
                  if (r == 'denied' && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('فعّل إذن الإشعارات أولاً من إعدادات المتصفح.')),
                    );
                  }
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: st.testNotification,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('تجربة تنبيه'),
                ),
              ),
            ]),

            // ── التنبيهات في الخلفية ──
            _section('التنبيهات في الخلفية', Icons.cloud_done_outlined, _pushKids(cs, tt, hint)),

            // ── البيانات ──
            _section('البيانات', Icons.storage_outlined, [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('استعادة الجدول الافتراضي؟'),
                        content: const Text('سيُستبدل جدولك الحالي بالجدول الافتراضي. سجلّ الإنجاز لا يتأثر.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
                          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('استعادة')),
                        ],
                      ),
                    );
                    if (ok == true) await st.resetTasks();
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('استعادة الجدول الافتراضي'),
                ),
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _permissionRow(ColorScheme cs, TextTheme tt, TextStyle? hint) {
    final p = st.permission;
    String label;
    switch (p) {
      case 'granted':
        label = 'إشعارات المتصفح مفعّلة ✓';
        break;
      case 'denied':
        label = 'الإشعارات محظورة. فعّلها من إعدادات الموقع في المتصفح.';
        break;
      case 'unsupported':
        label = 'هذا المتصفح لا يدعم الإشعارات.';
        break;
      default:
        label = 'لم تُفعّل إشعارات المتصفح بعد.';
    }
    return Row(children: [
      Expanded(child: Text(label)),
      if (p == 'default')
        FilledButton(onPressed: st.requestPermission, child: const Text('تفعيل')),
    ]);
  }

  Widget _typeCard(String key, String title, String sub, TextStyle? hint) {
    final t = s.types[key]!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.primaryContainer.withAlpha(cs.brightness == Brightness.dark ? 28 : 50),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sub, style: hint),
              value: t.enabled,
              onChanged: (v) {
                t.enabled = v;
                st.saveSettings();
              },
            ),
            if (t.enabled) ...[
              if (key == 'pre' || key == 'task')
                StepperField(
                  label: key == 'pre' ? 'قبل الأذان بـ' : 'قبل المهمة بـ',
                  value: t.minutes,
                  min: key == 'pre' ? 5 : 0,
                  max: 60,
                  step: 5,
                  onChanged: (v) {
                    t.minutes = v;
                    st.saveSettings();
                  },
                ),
              if (key == 'iqama')
                for (final k in prayerKeys)
                  StepperField(
                    label: 'إقامة ${prayerNames[k]} بعد الأذان بـ',
                    value: s.iqama[k] ?? 10,
                    min: 1,
                    max: 60,
                    step: 1,
                    onChanged: (v) {
                      s.iqama[k] = v;
                      st.saveSettings();
                    },
                  ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: soundOptions.any((o) => o.id == t.sound) ? t.sound : 'chime',
                    items: [
                      for (final o in soundOptions) DropdownMenuItem(value: o.id, child: Text(o.name)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      t.sound = v;
                      st.saveSettings();
                    },
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'تشغيل الصوت',
                  onPressed: () => st.preview(key),
                  icon: const Icon(Icons.play_arrow),
                ),
              ]),
              if (t.sound == 'custom')
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () async {
                      final name = await Bridge.pickAudio(key);
                      if (!mounted) return;
                      if (name.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الملف: $name')));
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('اختيار ملف صوتي من جهازك'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
