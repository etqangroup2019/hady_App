import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;

// نسخة أندرويد من الجسر: تنبيهات مجدولة بمنبّهات النظام الدقيقة (AlarmManager)
// فتصل في وقتها والتطبيق مغلق، وتبقى بعد إعادة تشغيل الهاتف.

class Bridge {
  static const bool isNative = true;

  static final FlutterLocalNotificationsPlugin _n = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static String _perm = 'default';
  static int _count = 0;
  static int _lastSync = 0;
  static int _seq = 100;

  static const _statusId = 7777;
  static const _icon = 'ic_stat_hady';

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static const _channels = <String, List<String>>{
    'pre': ['hady_pre', 'قبل الأذان', 'تنبيه قبل دخول وقت الصلاة'],
    'adhan': ['hady_adhan', 'الأذان', 'تنبيه دخول وقت الصلاة'],
    'iqama': ['hady_iqama', 'الإقامة', 'تنبيه إقامة الصلاة'],
    'task': ['hady_task', 'المهام', 'تنبيهات مهام اليوم'],
  };

  static Future<void> init() async {
    if (_ready) return;
    try {
      await _n.initialize(const InitializationSettings(android: AndroidInitializationSettings(_icon)));
      final a = _android;
      if (a != null) {
        for (final c in _channels.values) {
          await a.createNotificationChannel(AndroidNotificationChannel(
            c[0],
            c[1],
            description: c[2],
            importance: Importance.max,
            enableVibration: true,
          ));
        }
        await a.createNotificationChannel(const AndroidNotificationChannel(
          'hady_status',
          'الصلاة القادمة',
          description: 'إشعار دائم بالوقت المتبقي للصلاة والإقامة',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ));
        final on = await a.areNotificationsEnabled();
        _perm = on == true ? 'granted' : 'default';
      }
      _ready = true;
    } catch (_) {}
  }

  /// granted | denied | default | unsupported
  static String permission() => _perm;

  static Future<String> requestPermission() async {
    await init();
    try {
      final a = _android;
      final ok = await a?.requestNotificationsPermission();
      _perm = ok == true ? 'granted' : 'denied';
    } catch (_) {
      _perm = 'denied';
    }
    return _perm;
  }

  static NotificationDetails _details(String type, {int? untilMs, int? postAtMs}) {
    if (type == 'status') {
      final until = untilMs ?? 0;
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'hady_status',
          'الصلاة القادمة',
          channelDescription: 'إشعار دائم بالوقت المتبقي للصلاة والإقامة',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          icon: _icon,
          showWhen: until > 0,
          when: until > 0 ? until : null,
          usesChronometer: until > 0,
          chronometerCountDown: until > 0,
          timeoutAfter: until > 0 ? (until - (postAtMs ?? DateTime.now().millisecondsSinceEpoch)).clamp(1000, 86400000 * 2).toInt() : null,
        ),
      );
    }
    final c = _channels[type] ?? _channels['task']!;
    final loud = type == 'adhan' || type == 'iqama';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        c[0],
        c[1],
        channelDescription: c[2],
        importance: Importance.max,
        priority: Priority.max,
        category: loud ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        icon: _icon,
        vibrationPattern: Int64List.fromList(loud ? [0, 300, 150, 300, 150, 300] : [0, 200, 100, 200]),
      ),
    );
  }

  /// يعرض تنبيهاً فورياً (يُستعمل لزر التجربة).
  static void notify(String title, String body, String sound, String type, double volume, [String key = '']) {
    () async {
      await init();
      try {
        await _n.show(_seq++, title, body, _details(type));
      } catch (_) {}
    }();
  }

  static void play(String sound, String type, double volume) {}

  /// يعيد JSON نصياً {"lat":..,"lon":..} أو يرمي خطأ عند الرفض.
  static Future<String> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('location-off');
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw Exception('denied');
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
    );
    return jsonEncode({'lat': pos.latitude, 'lon': pos.longitude});
  }

  static Future<String> pickAudio(String type) async => '';

  static Future<bool> hasCustom(String type) async => false;

  // ── الجدولة ──

  /// JSON: {supported, configured, permission, subscribed, standalone, ios, count, lastSync}
  static Future<String> pushStatus() async {
    await init();
    try {
      final pend = await _n.pendingNotificationRequests();
      _count = pend.length;
    } catch (_) {}
    return jsonEncode({
      'supported': true,
      'configured': true,
      'permission': _perm,
      'subscribed': _perm == 'granted',
      'standalone': true,
      'ios': false,
      'count': _count,
      'lastSync': _lastSync,
    });
  }

  static Future<String> enablePush(String scheduleJson) async {
    await init();
    final perm = await requestPermission();
    if (perm != 'granted') throw Exception('permission-$perm');
    try {
      final a = _android;
      if (await a?.canScheduleExactNotifications() == false) {
        await a?.requestExactAlarmsPermission();
      }
    } catch (_) {}
    await syncSchedule(scheduleJson);
    return 'ok';
  }

  static Future<String> disablePush() async {
    await init();
    try {
      await _n.cancelAll();
    } catch (_) {}
    _count = 0;
    return 'ok';
  }

  /// يجدول كل عناصر القائمة بمنبّهات دقيقة؛ العنصر: {k,t,ti,b,ty,s,u}
  static Future<String> syncSchedule(String scheduleJson) async {
    await init();
    if (_perm != 'granted') return 'local';
    final items = (jsonDecode(scheduleJson) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    items.removeWhere((m) => (m['t'] as num).toInt() <= nowS);
    items.sort((a, b) => (a['t'] as num).compareTo(b['t'] as num));

    var mode = AndroidScheduleMode.exactAllowWhileIdle;
    try {
      if (await _android?.canScheduleExactNotifications() == false) mode = AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {}

    await _n.cancelAll();
    var id = 1000;
    var n = 0;
    for (final m in items.take(450)) {
      final t = (m['t'] as num).toInt();
      final ty = (m['ty'] ?? 'task').toString();
      final untilS = (m['u'] as num?)?.toInt() ?? 0;
      try {
        await _n.zonedSchedule(
          id++,
          (m['ti'] ?? '').toString(),
          (m['b'] ?? '').toString(),
          tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, t * 1000),
          _details(ty, untilMs: ty == 'status' && untilS > 0 ? untilS * 1000 : null, postAtMs: t * 1000),
          androidScheduleMode: mode,
        );
        n++;
      } catch (_) {
        // إن رُفض المنبّه الدقيق نكمل بغيره ولا نوقف الجدولة.
        try {
          await _n.zonedSchedule(
            id - 1,
            (m['ti'] ?? '').toString(),
            (m['b'] ?? '').toString(),
            tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, t * 1000),
            _details(ty),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          n++;
        } catch (_) {}
      }
    }
    _count = n;
    _lastSync = DateTime.now().millisecondsSinceEpoch;
    return 'synced';
  }

  // ── إشعار الحالة الدائم (عدّاد تنازلي حقيقي من نظام أندرويد) ──

  static Future<void> setStatus(String title, String live, String stat, [int untilMs = 0]) async {
    await init();
    if (_perm != 'granted') return;
    try {
      await _n.show(_statusId, title, stat, _details('status', untilMs: untilMs > 0 ? untilMs : null));
    } catch (_) {}
  }

  static Future<void> clearStatus() async {
    await init();
    try {
      await _n.cancel(_statusId);
      final act = await _n.getActiveNotifications();
      for (final a in act) {
        if (a.channelId == 'hady_status' && a.id != null) await _n.cancel(a.id!);
      }
      // الإشعارات الدائمة المجدولة مسبقاً تُلغى عند المزامنة التالية.
    } catch (_) {}
  }
}
