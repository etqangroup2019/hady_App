import 'dart:js_interop';

// الجسر بين Dart وملف web/notify.js (الإشعارات، الأصوات، تحديد الموقع).

@JS('SunnahBridge.permission')
external JSString _permission();

@JS('SunnahBridge.requestPermission')
external JSPromise<JSString> _requestPermission();

@JS('SunnahBridge.notify')
external void _notify(JSString title, JSString body, JSString sound, JSString type, JSNumber volume, JSString key);

@JS('SunnahBridge.play')
external void _play(JSString sound, JSString type, JSNumber volume);

@JS('SunnahBridge.locate')
external JSPromise<JSString> _locate();

@JS('SunnahBridge.pickAudio')
external JSPromise<JSString> _pickAudio(JSString type);

@JS('SunnahBridge.hasCustom')
external JSPromise<JSBoolean> _hasCustom(JSString type);

@JS('SunnahBridge.pushStatus')
external JSPromise<JSString> _pushStatus();

@JS('SunnahBridge.enablePush')
external JSPromise<JSString> _enablePush(JSString json);

@JS('SunnahBridge.disablePush')
external JSPromise<JSString> _disablePush();

@JS('SunnahBridge.syncSchedule')
external JSPromise<JSString> _syncSchedule(JSString json);

@JS('SunnahBridge.setStatus')
external JSPromise<JSString> _setStatus(JSString title, JSString live, JSString stat);

@JS('SunnahBridge.clearStatus')
external JSPromise<JSString> _clearStatus();

class Bridge {
  static const bool isNative = false;

  /// تهيئة أولية (لا شيء على الويب).
  static Future<void> init() async {}

  /// granted | denied | default | unsupported
  static String permission() {
    try {
      return _permission().toDart;
    } catch (_) {
      return 'unsupported';
    }
  }

  static Future<String> requestPermission() async {
    try {
      final r = await _requestPermission().toDart;
      return r.toDart;
    } catch (_) {
      return 'denied';
    }
  }

  static void notify(String title, String body, String sound, String type, double volume, [String key = '']) {
    try {
      _notify(title.toJS, body.toJS, sound.toJS, type.toJS, volume.toJS, key.toJS);
    } catch (_) {}
  }

  static void play(String sound, String type, double volume) {
    try {
      _play(sound.toJS, type.toJS, volume.toJS);
    } catch (_) {}
  }

  /// يعيد JSON نصياً {"lat":..,"lon":..} أو يرمي خطأ عند الرفض.
  static Future<String> locate() async {
    final r = await _locate().toDart;
    return r.toDart;
  }

  /// يفتح نافذة اختيار ملف صوتي؛ يعيد اسم الملف أو نصاً فارغاً عند الإلغاء.
  static Future<String> pickAudio(String type) async {
    try {
      final r = await _pickAudio(type.toJS).toDart;
      return r.toDart;
    } catch (_) {
      return '';
    }
  }

  static Future<bool> hasCustom(String type) async {
    try {
      final r = await _hasCustom(type.toJS).toDart;
      return r.toDart;
    } catch (_) {
      return false;
    }
  }

  // ── التنبيهات في الخلفية (Web Push) ──

  /// JSON: {supported, configured, permission, subscribed, standalone, ios, count, lastSync}
  static Future<String> pushStatus() async {
    try {
      return (await _pushStatus().toDart).toDart;
    } catch (_) {
      return '{"supported":false}';
    }
  }

  /// يعيد 'ok' أو يرمي خطأً نصه سبب الفشل.
  static Future<String> enablePush(String scheduleJson) async {
    final r = await _enablePush(scheduleJson.toJS).toDart;
    return r.toDart;
  }

  static Future<String> disablePush() async {
    try {
      return (await _disablePush().toDart).toDart;
    } catch (_) {
      return 'error';
    }
  }

  /// 'synced' | 'local' ، أو يرمي خطأً إن تعذّر الوصول للخادم.
  static Future<String> syncSchedule(String scheduleJson) async {
    final r = await _syncSchedule(scheduleJson.toJS).toDart;
    return r.toDart;
  }

  // ── إشعار الحالة الدائم ──

  static Future<void> setStatus(String title, String live, String stat, [int untilMs = 0]) async {
    try {
      await _setStatus(title.toJS, live.toJS, stat.toJS).toDart;
    } catch (_) {}
  }

  static Future<void> clearStatus() async {
    try {
      await _clearStatus().toDart;
    } catch (_) {}
  }
}
