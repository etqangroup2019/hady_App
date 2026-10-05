{{flutter_js}}
{{flutter_build_config}}

// نسجّل عامل الخدمة الخاص بنا (hady_sw.js) من index.html،
// فلا نمرّر serviceWorkerSettings حتى لا يسجّل Flutter عاملاً منافساً على النطاق نفسه.
_flutter.loader.load();
