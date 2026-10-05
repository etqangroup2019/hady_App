#!/usr/bin/env python3
"""يهيّئ مجلد android الذي ولّده `flutter create` ليدعم التنبيهات المجدولة.
يُشغَّل مرة واحدة بعد flutter create (يفعله سير عمل GitHub تلقائياً)."""
import pathlib, re, shutil, sys

root = pathlib.Path(__file__).resolve().parent.parent
android = root / 'android'
manifest = android / 'app/src/main/AndroidManifest.xml'
if not manifest.exists():
    sys.exit('android/ غير موجود. شغّل: flutter create --platforms=android .')

# 1) الأيقونات
res = android / 'app/src/main/res'
for d in (root / 'android_res').iterdir():
    if d.is_dir():
        (res / d.name).mkdir(parents=True, exist_ok=True)
        for f in d.iterdir():
            shutil.copy(f, res / d.name / f.name)
# أيقونات adaptive القديمة (إن وُجدت) تتفوق على mipmap الثابتة؛ نحذفها
for f in res.glob('mipmap-anydpi*/ic_launcher*.xml'):
    f.unlink()

# 2) AndroidManifest
m = manifest.read_text(encoding='utf-8')
perms = [
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.VIBRATE',
    'android.permission.WAKE_LOCK',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.SCHEDULE_EXACT_ALARM',
    'android.permission.USE_EXACT_ALARM',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_FINE_LOCATION',
]
add = ''.join(f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in m)
m = m.replace('<application', add + '    <application', 1)

receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
if 'ScheduledNotificationReceiver' not in m:
    m = m.replace('</application>', receivers + '    </application>', 1)
m = re.sub(r'android:label="[^"]*"', 'android:label="هَدْي"', m, count=1)
manifest.write_text(m, encoding='utf-8')

# 3) Gradle: desugaring مطلوب لمكتبة الإشعارات
for name in ('build.gradle.kts', 'build.gradle'):
    f = android / 'app' / name
    if not f.exists():
        continue
    g = f.read_text(encoding='utf-8')
    kts = name.endswith('.kts')
    if 'coreLibraryDesugaring' not in g:
        flag = 'isCoreLibraryDesugaringEnabled = true' if kts else 'coreLibraryDesugaringEnabled true'
        dep = ('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")' if kts
               else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
        g = re.sub(r'(compileOptions\s*\{)', r'\1\n        ' + flag, g, count=1)
        if re.search(r'^dependencies\s*\{', g, re.M):
            g = re.sub(r'(^dependencies\s*\{)', r'\1\n    ' + dep, g, count=1, flags=re.M)
        else:
            g += '\ndependencies {\n    ' + dep + '\n}\n'
        f.write_text(g, encoding='utf-8')
    break
print('تم تهيئة android/')
