import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding, WidgetsBindingObserver, AppLifecycleState;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'bridge.dart';
import 'defaults.dart';
import 'methods.dart';
import 'models.dart';
import 'solar.dart';

class _Ev {
  final String key, type, title, body;
  final DateTime time;
  _Ev(this.key, this.type, this.title, this.body, this.time);
}

class _St {
  final String title, stat;
  final String Function(DateTime) live;
  final DateTime target; // الأذان القادم أو الإقامة: لحظة انتهاء هذه الحالة
  _St(this.title, this.stat, this.live, this.target);
}

class _Pt {
  final String key;
  final DateTime adhan, iqama;
  _Pt(this.key, this.adhan, this.iqama);
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  late SharedPreferences _p;

  Settings s = Settings();
  List<Task> tasks = [];
  final Map<String, Set<String>> logs = {};
  final Set<String> _fired = {};
  String _firedDay = '';
  Timer? _timer;
  DateTime _lastRetry = DateTime.fromMillisecondsSinceEpoch(0);

  bool loadingTimes = false;
  String? timesError;
  String permission = 'default';

  // ───────────────────────── التهيئة ─────────────────────────

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();

    final sj = _p.getString('settings');
    if (sj != null) {
      try {
        s = Settings.fromJson(jsonDecode(sj) as Map<String, dynamic>);
      } catch (_) {}
    }

    final tj = _p.getString('tasks');
    if (tj != null) {
      try {
        tasks = (jsonDecode(tj) as List).map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      } catch (_) {
        tasks = [];
      }
    }
    if (tasks.isEmpty) {
      tasks = defaultTasks();
      await _saveTasks();
    }

    final lj = _p.getString('logs');
    if (lj != null) {
      try {
        (jsonDecode(lj) as Map).forEach((k, v) {
          logs[k.toString()] = (v as List).map((e) => e.toString()).toSet();
        });
      } catch (_) {}
    }

    _loadHijri();
    await Bridge.init();
    permission = Bridge.permission();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshTimes().then((_) {
      refreshPushInfo();
      _refreshStatus(force: true);
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _syncDebounce?.cancel();
    super.dispose();
  }

  /// عند عودة التطبيق للواجهة: نلحق بما فاتنا (حتى 5 دقائق) ونجدّد الجدول.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      permission = Bridge.permission();
      _tick(windowSecs: 300);
      _scheduleSync();
      unawaited(refreshPushInfo());
    }
  }

  // أي تغيير في الإعدادات أو المهام أو الموقع يعيد مزامنة جدول الخلفية بعد لحظة.
  @override
  void notifyListeners() {
    super.notifyListeners();
    _scheduleSync();
  }

  // ───────────────────────── المواقيت (حساب داخل الجهاز) ─────────────────────────

  final Map<String, PrayerDay> _memo = {};
  String _memoSig = '';
  final Map<String, String> _hijriNet = {};

  /// الجهة المعتمدة فعلياً الآن (تلقائية حسب الدولة أو يدوية).
  MethodSpec get spec => resolveMethod(s);

  bool get hasLocation => s.lat != null && s.lon != null;

  /// احتياط الجهة + تعديلك اليدوي.
  Map<String, int> get _effectiveTune {
    final out = <String, int>{...spec.tune};
    s.tune.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    return out;
  }

  /// صحيح متى توفّر موقع (المواقيت تُحسب فلكياً من الإحداثيات).
  bool hasReal(DateTime d) => hasLocation;

  PrayerDay dayFor(DateTime d) {
    final day = dayOnly(d);
    if (!hasLocation) return PrayerDay.approximate(day);
    final sp = spec;
    final sig = '${s.lat!.toStringAsFixed(3)},${s.lon!.toStringAsFixed(3)}|${sp.key}|${s.school}';
    if (sig != _memoSig) {
      _memo.clear();
      _memoSig = sig;
    }
    final raw = _memo.putIfAbsent(
      dateKey(day),
      () => Solar.compute(day, s.lat!, s.lon!, sp, school: s.school),
    );
    return raw.shifted(_effectiveTune).withHijri(hijriFor(day));
  }

  // ── التاريخ الهجري: من الشبكة إن توفرت، وإلا حساب تقريبي ──

  String _hKey(DateTime day) => '${dateKey(day)}|${s.hijriAdjust}';

  String hijriFor(DateTime day) => _hijriNet[_hKey(day)] ?? hijriTabular(addDays(day, s.hijriAdjust));

  void _loadHijri() {
    final hj = _p.getString('hijri');
    if (hj == null) return;
    try {
      (jsonDecode(hj) as Map).forEach((k, v) => _hijriNet[k.toString()] = v.toString());
    } catch (_) {}
  }

  Future<void> _fetchHijri(DateTime day) async {
    final k = _hKey(day);
    if (_hijriNet.containsKey(k)) return;
    final g = addDays(day, s.hijriAdjust);
    try {
      final uri = Uri.https('api.aladhan.com', '/v1/gToH/${two(g.day)}-${two(g.month)}-${g.year}');
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return;
      final h = (jsonDecode(r.body) as Map<String, dynamic>)['data']['hijri'];
      _hijriNet[k] = '${h['day']} ${h['month']['ar']} ${h['year']}';
      final cutoff = dateKey(addDays(dayOnly(DateTime.now()), -1));
      _hijriNet.removeWhere((key, _) => key.split('|').first.compareTo(cutoff) < 0);
      await _p.setString('hijri', jsonEncode(_hijriNet));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> ensureDay(DateTime d) => _fetchHijri(dayOnly(d));

  /// يعيد تحديد الموقع إن لزم ويعيد الحساب. الحساب نفسه لحظي ولا يحتاج إنترنت.
  Future<void> refreshTimes({bool force = false}) async {
    if (loadingTimes) return;
    if (force) _memo.clear();
    loadingTimes = true;
    timesError = null;
    notifyListeners();

    if (!hasLocation) {
      if (s.auto) {
        await detectLocation(refresh: false);
      } else if (s.city.trim().isNotEmpty) {
        await geocodeManual(refresh: false);
      }
    }

    loadingTimes = false;
    if (!hasLocation) {
      timesError ??= 'حدّد موقعك أو مدينتك من الإعدادات لعرض مواقيت دقيقة. المعروض الآن تقريبي.';
    }
    notifyListeners();
    unawaited(ensureDay(dayOnly(DateTime.now())));
  }

  /// يحوّل اسم المدينة والدولة المكتوبين إلى إحداثيات (خدمة Open-Meteo).
  Future<bool> geocodeManual({bool refresh = true}) async {
    final city = s.city.trim();
    final country = s.country.trim();
    if (city.isEmpty) return false;
    try {
      final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': city,
        'count': '10',
        'language': 'ar',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) throw Exception('http ${r.statusCode}');
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final list = (j['results'] as List?) ?? const [];
      if (list.isEmpty) throw Exception('not found');

      final want = countryFromName(country);
      Map<String, dynamic>? pick;
      for (final e in list) {
        final m = Map<String, dynamic>.from(e as Map);
        final cc = (m['country_code'] ?? '').toString().toUpperCase();
        if (want.isEmpty || cc == want) {
          pick = m;
          break;
        }
      }
      pick ??= Map<String, dynamic>.from(list.first as Map);

      s.lat = (pick['latitude'] as num).toDouble();
      s.lon = (pick['longitude'] as num).toDouble();
      s.countryCode = (pick['country_code'] ?? '').toString().toUpperCase();
      s.place = [pick['name'], pick['admin1'], pick['country']]
          .where((e) => e != null && e.toString().isNotEmpty)
          .map((e) => e.toString())
          .toSet()
          .join('، ');
      s.auto = false;
      timesError = null;
      await _saveSettings();
      if (refresh) await refreshTimes(force: true);
      notifyListeners();
      return true;
    } catch (_) {
      timesError = 'تعذّر العثور على المدينة. جرّب كتابة الاسم بالعربية أو الإنجليزية مع اسم الدولة.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> detectLocation({bool refresh = true}) async {
    try {
      final j = jsonDecode(await Bridge.locate()) as Map<String, dynamic>;
      s.lat = (j['lat'] as num).toDouble();
      s.lon = (j['lon'] as num).toDouble();
      s.auto = true;
      await _reverseName();
      await _saveSettings();
      if (refresh) await refreshTimes(force: true);
      notifyListeners();
      return true;
    } catch (_) {
      timesError = 'تعذّر تحديد موقعك. اسمح للمتصفح بالوصول للموقع، أو أدخل مدينتك يدوياً.';
      notifyListeners();
      return false;
    }
  }

  Future<void> _reverseName() async {
    try {
      final uri = Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
        'latitude': '${s.lat}',
        'longitude': '${s.lon}',
        'localityLanguage': 'ar',
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final city = (j['city'] ?? j['locality'] ?? '').toString();
        final country = (j['countryName'] ?? '').toString();
        s.place = [city, country].where((e) => e.isNotEmpty).join('، ');
        s.countryCode = (j['countryCode'] ?? '').toString().toUpperCase();
      }
    } catch (_) {}
  }

  NextPrayer nextPrayer(DateTime now) {
    final today = dayOnly(now);
    final p = dayFor(today);
    for (final k in prayerKeys) {
      final t = p.byKey(k);
      if (t.isAfter(now)) return NextPrayer(k, t);
    }
    return NextPrayer('fajr', dayFor(addDays(today, 1)).fajr);
  }

  // ───────────────────────── المهام والتتبع ─────────────────────────

  List<Occ> occurrences(DateTime day, {bool all = false}) {
    final p = dayFor(day);
    final out = <Occ>[];
    for (final t in tasks) {
      if (!all && !(t.enabled && t.runsOn(day))) continue;
      final st = t.startOn(day, p);
      out.add(Occ(t, st, st.add(Duration(minutes: t.duration))));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  bool isDone(String id, DateTime day) => logs[dateKey(day)]?.contains(id) ?? false;

  Future<void> setDone(String id, DateTime day, bool v) async {
    final set = logs.putIfAbsent(dateKey(day), () => <String>{});
    if (v) {
      set.add(id);
    } else {
      set.remove(id);
    }
    notifyListeners();
    await _saveLogs();
  }

  /// (المنجز، الإجمالي) ليوم معيّن.
  (int, int) progress(DateTime day) {
    final list = occurrences(day);
    final done = list.where((o) => isDone(o.task.id, day)).length;
    return (done, list.length);
  }

  Future<void> upsertTask(Task t) async {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      tasks[i] = t;
    } else {
      tasks.add(t);
    }
    notifyListeners();
    await _saveTasks();
  }

  Future<void> deleteTask(String id) async {
    tasks.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> toggleTask(String id, bool enabled) async {
    final i = tasks.indexWhere((e) => e.id == id);
    if (i < 0) return;
    tasks[i].enabled = enabled;
    notifyListeners();
    await _saveTasks();
  }

  Future<void> resetTasks() async {
    tasks = defaultTasks();
    notifyListeners();
    await _saveTasks();
  }

  String newTaskId() => 'u${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _saveTasks() => _p.setString('tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));

  Future<void> _saveLogs() {
    final keys = logs.keys.toList()..sort();
    while (keys.length > 120) {
      logs.remove(keys.removeAt(0));
    }
    return _p.setString('logs', jsonEncode(logs.map((k, v) => MapEntry(k, v.toList()))));
  }

  // ───────────────────────── الإعدادات ─────────────────────────

  Future<void> _saveSettings() => _p.setString('settings', jsonEncode(s.toJson()));

  Future<void> saveSettings({bool timesChanged = false}) async {
    notifyListeners();
    await _saveSettings();
    if (timesChanged) await refreshTimes(force: true);
    unawaited(ensureDay(dayOnly(DateTime.now())));
  }

  Future<String> requestPermission() async {
    permission = await Bridge.requestPermission();
    notifyListeners();
    return permission;
  }

  void preview(String type) {
    final t = s.types[type];
    if (t == null) return;
    Bridge.play(t.sound, type, s.volume);
  }

  void testNotification() {
    final t = s.types['adhan']!;
    Bridge.notify('تجربة التنبيه', 'هكذا سيظهر التنبيه على جهازك.', t.sound, 'adhan', s.volume, 'test|now');
  }

  // ───────────────────────── إشعار الحالة الدائم ─────────────────────────

  String _statusSig = '';

  List<_Pt> _points(DateTime day) {
    final p = dayFor(day);
    return [
      for (final k in prayerKeys) _Pt(k, p.byKey(k), p.byKey(k).add(Duration(minutes: s.iqama[k] ?? 10))),
    ];
  }

  static String _dur(Duration d) {
    final m = (d.inSeconds / 60).ceil().clamp(0, 99999);
    final h = m ~/ 60, r = m % 60;
    if (h == 0) return '$m د';
    return r == 0 ? '$h س' : '$h س و$r د';
  }

  /// حالة الإشعار في لحظة معيّنة: بين الأذان والإقامة، أو انتظار الأذان القادم.
  _St? _statusAt(DateTime at) {
    if (!hasLocation) return null;
    final day = dayOnly(at);
    final pts = <_Pt>[
      ..._points(addDays(day, -1)),
      ..._points(day),
      ..._points(addDays(day, 1)),
    ];
    for (final pt in pts) {
      if (!pt.iqama.isAfter(at)) continue;
      final name = prayerNames[pt.key]!;
      final iq = fmtTime(pt.iqama, s.h24);
      if (!pt.adhan.isAfter(at)) {
        return _St('حان وقت صلاة $name', 'الإقامة $iq', (n) => 'متبقٍ على الإقامة ${_dur(pt.iqama.difference(n))}', pt.iqama);
      }
      return _St(
        'القادمة: $name ${fmtTime(pt.adhan, s.h24)}',
        'الإقامة $iq',
        (n) => 'متبقٍ ${_dur(pt.adhan.difference(n))} على الأذان · ${_dur(pt.iqama.difference(n))} على الإقامة',
        pt.adhan,
      );
    }
    return null;
  }

  /// يحدّث الإشعار الدائم (مرة كل دقيقة أو عند التغيّر).
  void _refreshStatus({bool force = false}) {
    if (!s.statusOn || permission != 'granted') return;
    final now = DateTime.now();
    final st = _statusAt(now);
    if (st == null) return;
    final sig = Bridge.isNative ? st.title : '${now.year}${now.month}${now.day}${now.hour}:${now.minute}|${st.title}';
    if (!force && sig == _statusSig) return;
    _statusSig = sig;
    unawaited(Bridge.setStatus(st.title, st.live(now), st.stat, st.target.millisecondsSinceEpoch));
  }

  Future<String> setStatusOn(bool on) async {
    if (on) {
      if (permission != 'granted') await requestPermission();
      if (permission != 'granted') {
        s.statusOn = false;
        await saveSettings();
        return 'denied';
      }
      s.statusOn = true;
      await saveSettings();
      _refreshStatus(force: true);
    } else {
      s.statusOn = false;
      _statusSig = '';
      await saveSettings();
      await Bridge.clearStatus();
    }
    return 'ok';
  }

  // ───────────────────────── التنبيهات في الخلفية ─────────────────────────

  Map<String, dynamic> pushInfo = const {};
  bool pushBusy = false;
  String? pushMsg;
  Timer? _syncDebounce;
  final List<Map<String, dynamic>> _extra = [];

  /// أيام الجدول المرسل للخادم (اليوم + 3).
  static const _horizonDays = 4;

  String _buildSchedule() {
    final now = DateTime.now();
    final today = dayOnly(now);
    final items = <Map<String, dynamic>>[];
    final cutoff = now.subtract(const Duration(minutes: 1));
    for (var i = 0; i < _horizonDays; i++) {
      for (final e in _eventsFor(addDays(today, i))) {
        if (e.time.isBefore(cutoff)) continue;
        items.add({
          'k': e.key,
          't': e.time.millisecondsSinceEpoch ~/ 1000,
          'ti': e.title,
          'b': e.body,
          'ty': e.type,
          's': s.types[e.type]?.sound ?? 'tone',
        });
      }
    }
    if (s.statusOn && hasLocation) {
      for (var i = 0; i < _horizonDays; i++) {
        for (final pt in _points(addDays(today, i))) {
          for (final at in [pt.adhan, pt.iqama]) {
            if (at.isBefore(cutoff)) continue;
            final st = _statusAt(at.add(const Duration(seconds: 1)));
            if (st == null) continue;
            items.add({
              'k': '${dateKey(addDays(today, i))}|status|${pt.key}|${at.millisecondsSinceEpoch ~/ 60000}',
              't': at.millisecondsSinceEpoch ~/ 1000,
              'ti': st.title,
              'b': st.stat,
              'ty': 'status',
              's': 'none',
              'u': st.target.millisecondsSinceEpoch ~/ 1000,
            });
          }
        }
      }
    }
    _extra.removeWhere((m) => (m['t'] as int) * 1000 < now.millisecondsSinceEpoch - 120000);
    items.addAll(_extra);
    items.sort((a, b) => (a['t'] as int).compareTo(b['t'] as int));
    return jsonEncode(items.length > 780 ? items.sublist(0, 780) : items);
  }

  void _scheduleSync() {
    if (!s.pushOn) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 3), () => unawaited(_syncNow()));
  }

  Future<void> _syncNow() async {
    if (!s.pushOn) return;
    try {
      await Bridge.syncSchedule(_buildSchedule());
      pushMsg = null;
    } catch (_) {
      pushMsg = 'تعذّر الوصول لخادم التنبيهات. سنعيد المحاولة تلقائياً عند فتح التطبيق.';
    }
    await refreshPushInfo();
  }

  Future<void> refreshPushInfo() async {
    try {
      pushInfo = Map<String, dynamic>.from(jsonDecode(await Bridge.pushStatus()) as Map);
    } catch (_) {
      pushInfo = const {};
    }
    permission = Bridge.permission();
    super.notifyListeners(); // بدون إعادة مزامنة
  }

  String _pushError(Object e) {
    final m = e.toString();
    if (m.contains('not-configured')) return 'خادم التنبيهات غير مُعدّ بعد. اتبع خطوات push-worker/README.md ثم ضع رابطه في web/config.js.';
    if (m.contains('permission-')) return 'لم يُسمح بالإشعارات. فعّلها من إعدادات المتصفح/الجهاز لهذا التطبيق ثم أعد المحاولة.';
    if (m.contains('server-')) return 'خادم التنبيهات ردّ بخطأ. تحقق من نشره وإعداداته.';
    return 'تعذّر تفعيل التنبيهات في الخلفية على هذا الجهاز.';
  }

  Future<void> enableBackground() async {
    pushBusy = true;
    pushMsg = null;
    super.notifyListeners();
    try {
      await Bridge.enablePush(_buildSchedule());
      s.pushOn = true;
      await _saveSettings();
    } catch (e) {
      pushMsg = _pushError(e);
    }
    pushBusy = false;
    await refreshPushInfo();
  }

  Future<void> disableBackground() async {
    pushBusy = true;
    super.notifyListeners();
    await Bridge.disablePush();
    s.pushOn = false;
    pushMsg = null;
    await _saveSettings();
    pushBusy = false;
    await refreshPushInfo();
  }

  /// يجدول تنبيهاً عند بداية الدقيقة التالية عبر الخادم؛ أغلق التطبيق وانتظر.
  Future<void> testBackground() async {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, now.hour, now.minute).add(const Duration(minutes: 1));
    if (at.difference(now).inSeconds < 20) at = at.add(const Duration(minutes: 1));
    final t = s.types['adhan']!;
    _extra
      ..clear()
      ..add({
        'k': 'test|${at.millisecondsSinceEpoch ~/ 1000}',
        't': at.millisecondsSinceEpoch ~/ 1000,
        'ti': 'تجربة التنبيه في الخلفية',
        'b': 'وصلك هذا التنبيه عبر الخادم والتطبيق مغلق. الحمد لله.',
        'ty': 'adhan',
        's': t.sound,
      });
    pushBusy = true;
    pushMsg = null;
    super.notifyListeners();
    try {
      if (!s.pushOn) {
        await Bridge.enablePush(_buildSchedule());
        s.pushOn = true;
        await _saveSettings();
      } else {
        await Bridge.syncSchedule(_buildSchedule());
      }
      pushMsg = 'جُدولت التجربة عند ${two(at.hour)}:${two(at.minute)}. أغلق التطبيق تماماً وانتظر؛ يجب أن يصلك التنبيه.';
    } catch (e) {
      pushMsg = _pushError(e);
    }
    pushBusy = false;
    await refreshPushInfo();
  }

  // ───────────────────────── التنبيهات ─────────────────────────

  List<_Ev> _eventsFor(DateTime today) {
    final out = <_Ev>[];
    final dk = dateKey(today);
    final real = hasReal(today);
    final p = dayFor(today);

    if (real) {
      for (final k in prayerKeys) {
        if (!s.prayersOn.contains(k)) continue;
        final t = p.byKey(k);
        final name = prayerNames[k]!;
        final pre = s.types['pre']!;
        if (pre.enabled && pre.minutes > 0) {
          out.add(_Ev('$dk|pre|$k', 'pre', 'اقترب أذان $name', 'بعد ${pre.minutes} دقيقة إن شاء الله',
              t.subtract(Duration(minutes: pre.minutes))));
        }
        if (s.types['adhan']!.enabled) {
          out.add(_Ev('$dk|adhan|$k', 'adhan', 'حان وقت صلاة $name', 'حيّ على الصلاة، حيّ على الفلاح', t));
        }
        if (s.types['iqama']!.enabled) {
          final m = s.iqama[k] ?? 10;
          out.add(_Ev('$dk|iqama|$k', 'iqama', 'إقامة صلاة $name', 'استعدّ لإقامة الصلاة', t.add(Duration(minutes: m))));
        }
      }
    }

    final tt = s.types['task']!;
    if (tt.enabled) {
      for (final o in occurrences(today)) {
        if (!o.task.remind || isDone(o.task.id, today)) continue;
        final lead = tt.minutes;
        out.add(_Ev(
          '$dk|task|${o.task.id}',
          'task',
          o.task.title,
          lead > 0 ? 'تبدأ بعد $lead دقيقة' : 'حان وقت هذه المهمة',
          o.start.subtract(Duration(minutes: lead)),
        ));
      }
    }
    return out;
  }

  void _tick({int windowSecs = 100}) {
    final now = DateTime.now();
    final today = dayOnly(now);
    final dk = dateKey(today);

    if (_firedDay != dk) {
      _fired.clear();
      _firedDay = dk;
    }

    if (!hasReal(today) && !loadingTimes && now.difference(_lastRetry).inMinutes >= 10) {
      _lastRetry = now;
      unawaited(refreshTimes());
    }

    _refreshStatus();

    if (Bridge.isNative) return; // على أندرويد تتولى منبّهات النظام التنبيه
    final window = now.subtract(Duration(seconds: windowSecs));
    for (final e in _eventsFor(today)) {
      if (e.time.isAfter(now) || e.time.isBefore(window)) continue;
      if (_fired.contains(e.key)) continue;
      _fired.add(e.key);
      final t = s.types[e.type]!;
      Bridge.notify(e.title, e.body, t.sound, e.type, s.volume, e.key);
    }
  }
}
