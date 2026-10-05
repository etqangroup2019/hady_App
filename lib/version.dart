// رقم الإصدار: الجزء الأول يدوي، والبناء يُحسب تلقائياً من عدد الـcommits عند كل رفع إلى GitHub
// (انظر ملفات .github/workflows) فيتغيّر مع كل تعديل ويدلّك على أن التحديث وصل.
const String appVersion = '1.3';
const String appBuild = String.fromEnvironment('BUILD', defaultValue: '0');
const String appCommit = String.fromEnvironment('COMMIT', defaultValue: '');
const int appBuiltEpoch = int.fromEnvironment('BUILT', defaultValue: 0);

const String appDeveloper = 'خالد النويصري';

String get versionFull => appBuild == '0' ? '$appVersion (محلي)' : '$appVersion.$appBuild';

DateTime? get builtAt => appBuiltEpoch > 0 ? DateTime.fromMillisecondsSinceEpoch(appBuiltEpoch * 1000) : null;
