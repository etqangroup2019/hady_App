// واجهة موحّدة للتنبيهات والموقع: على الويب عبر JavaScript، وعلى أندرويد عبر منبّهات النظام.
export 'bridge_native.dart' if (dart.library.js_interop) 'bridge_web.dart';
