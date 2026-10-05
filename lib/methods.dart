import 'models.dart';

/// طرق الحساب المتاحة (المعرّف → الاسم). المعرّفات متوافقة مع تصنيف Aladhan.
const methodNames = <int, String>{
  5: 'الهيئة المصرية العامة للمساحة',
  4: 'جامعة أم القرى - مكة المكرمة',
  3: 'رابطة العالم الإسلامي',
  2: 'الجمعية الإسلامية لأمريكا الشمالية (ISNA)',
  1: 'جامعة العلوم الإسلامية - كراتشي',
  8: 'منطقة الخليج',
  9: 'الكويت',
  10: 'قطر',
  16: 'دبي',
  23: 'وزارة الأوقاف - الأردن',
  18: 'تونس',
  19: 'الجزائر',
  21: 'المغرب',
  22: 'الجالية الإسلامية - لشبونة',
  12: 'اتحاد المنظمات الإسلامية - فرنسا',
  13: 'رئاسة الشؤون الدينية - تركيا',
  14: 'الإدارة الروحية لمسلمي روسيا',
  11: 'مجلس الشؤون الإسلامية - سنغافورة',
  17: 'جاكيم - ماليزيا',
  20: 'وزارة الشؤون الدينية - إندونيسيا',
  7: 'معهد الجيوفيزياء - جامعة طهران',
  0: 'الشيعة الإثنا عشرية - قم',
  99: 'مخصص (أحدد الزوايا بنفسي)',
};

/// الطريقة الفعلية المستخدمة في الحساب.
class MethodSpec {
  final int id;
  final String label;
  final String note;

  /// زاوية الفجر والعشاء بالدرجات.
  final double fajr, isha;

  /// إن كانت > 0 يكون العشاء بعد المغرب بهذه الدقائق (أم القرى والخليج وقطر ولشبونة).
  final int ishaMin;

  /// إن لم تكن null يكون المغرب عند هذه الزاوية تحت الأفق (طهران وقم).
  final double? maghribAngle;

  /// دقائق تُضاف للغروب ليكون المغرب (الأردن ولشبونة).
  final int maghribMin;

  /// احتياط تُضيفه الجهة تلقائياً لأي وقت (مثل المغرب +3).
  final Map<String, int> tune;

  const MethodSpec(
    this.id,
    this.label, {
    this.note = '',
    this.fajr = 18,
    this.isha = 17,
    this.ishaMin = 0,
    this.maghribAngle,
    this.maghribMin = 0,
    this.tune = const {},
  });

  /// بصمة تُستخدم لإبطال المواقيت المحفوظة مؤقتاً عند تغيّر الطريقة.
  String get key => '$id|$fajr|$isha|$ishaMin|$maghribAngle|$maghribMin';
}

/// المتغيرات الفلكية لكل طريقة (من جداول الجهات المنشورة).
MethodSpec _byId(int id) {
  final name = methodNames[id] ?? 'رابطة العالم الإسلامي';
  switch (id) {
    case 0:
      return MethodSpec(id, name, fajr: 16, isha: 14, maghribAngle: 4);
    case 1:
      return MethodSpec(id, name, fajr: 18, isha: 18);
    case 2:
      return MethodSpec(id, name, fajr: 15, isha: 15);
    case 4:
      return MethodSpec(id, name, fajr: 18.5, ishaMin: 90);
    case 5:
      return MethodSpec(id, name, fajr: 19.5, isha: 17.5);
    case 7:
      return MethodSpec(id, name, fajr: 17.7, isha: 14, maghribAngle: 4.5);
    case 8:
      return MethodSpec(id, name, fajr: 19.5, ishaMin: 90);
    case 9:
      return MethodSpec(id, name, fajr: 18, isha: 17.5);
    case 10:
      return MethodSpec(id, name, fajr: 18, ishaMin: 90);
    case 11:
      return MethodSpec(id, name, fajr: 20, isha: 18);
    case 12:
      return MethodSpec(id, name, fajr: 12, isha: 12);
    case 13:
      return MethodSpec(id, name, fajr: 18, isha: 17);
    case 14:
      return MethodSpec(id, name, fajr: 16, isha: 15);
    case 16:
      return MethodSpec(id, name, fajr: 18.2, isha: 18.2);
    case 17:
      return MethodSpec(id, name, fajr: 20, isha: 18);
    case 18:
      return MethodSpec(id, name, fajr: 18, isha: 18);
    case 19:
      return MethodSpec(id, name, fajr: 18, isha: 17);
    case 20:
      return MethodSpec(id, name, fajr: 20, isha: 18);
    case 21:
      return MethodSpec(id, name, fajr: 19, isha: 17);
    case 22:
      return MethodSpec(id, name, fajr: 18, ishaMin: 77, maghribMin: 3);
    case 23:
      return MethodSpec(id, name, fajr: 18, isha: 18, maghribMin: 5);
    case 3:
    default:
      return MethodSpec(3, 'رابطة العالم الإسلامي', fajr: 18, isha: 17);
  }
}

// ───────────────────────── الدول ─────────────────────────

const _countryNames = <String, List<String>>{
  'LY': ['libya', 'ليبيا'],
  'EG': ['egypt', 'مصر'],
  'SA': ['saudi arabia', 'السعودية', 'المملكة العربية السعودية'],
  'AE': ['united arab emirates', 'uae', 'الإمارات', 'الامارات', 'الإمارات العربية المتحدة'],
  'KW': ['kuwait', 'الكويت'],
  'QA': ['qatar', 'قطر'],
  'BH': ['bahrain', 'البحرين'],
  'OM': ['oman', 'عُمان', 'عمان', 'سلطنة عمان'],
  'JO': ['jordan', 'الأردن', 'الاردن'],
  'DZ': ['algeria', 'الجزائر'],
  'TN': ['tunisia', 'تونس'],
  'MA': ['morocco', 'المغرب'],
  'SD': ['sudan', 'السودان'],
  'TR': ['turkey', 'türkiye', 'turkiye', 'تركيا'],
  'FR': ['france', 'فرنسا'],
  'RU': ['russia', 'روسيا'],
  'SG': ['singapore', 'سنغافورة'],
  'MY': ['malaysia', 'ماليزيا'],
  'ID': ['indonesia', 'إندونيسيا', 'اندونيسيا'],
  'PK': ['pakistan', 'باكستان'],
  'BD': ['bangladesh', 'بنغلاديش'],
  'IN': ['india', 'الهند'],
  'AF': ['afghanistan', 'أفغانستان', 'افغانستان'],
  'IR': ['iran', 'إيران', 'ايران'],
  'US': ['united states', 'usa', 'الولايات المتحدة', 'أمريكا', 'امريكا'],
  'CA': ['canada', 'كندا'],
  'GB': ['united kingdom', 'uk', 'england', 'المملكة المتحدة', 'بريطانيا'],
  'PT': ['portugal', 'البرتغال'],
  'LB': ['lebanon', 'لبنان'],
  'SY': ['syria', 'سوريا'],
  'IQ': ['iraq', 'العراق'],
  'PS': ['palestine', 'فلسطين'],
};

/// معرّف الطريقة المعتمدة لكل دولة (وإلا رابطة العالم الإسلامي).
const _methodByCountry = <String, int>{
  'EG': 5, 'SD': 5,
  'SA': 4,
  'AE': 16,
  'KW': 9,
  'QA': 10,
  'BH': 8, 'OM': 8,
  'JO': 23,
  'DZ': 19,
  'TN': 18,
  'MA': 21,
  'TR': 13,
  'FR': 12,
  'RU': 14,
  'SG': 11,
  'MY': 17,
  'ID': 20,
  'PK': 1, 'BD': 1, 'IN': 1, 'AF': 1,
  'IR': 7,
  'US': 2, 'CA': 2,
  'PT': 22,
  'LB': 3, 'SY': 3, 'IQ': 3, 'PS': 3, 'GB': 3,
};

String countryFromName(String name) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return '';
  for (final e in _countryNames.entries) {
    for (final v in e.value) {
      if (n == v.toLowerCase()) return e.key;
    }
  }
  for (final e in _countryNames.entries) {
    for (final v in e.value) {
      if (n.contains(v.toLowerCase())) return e.key;
    }
  }
  return '';
}

String detectCountry(Settings s) {
  if (s.countryCode.isNotEmpty) return s.countryCode;
  if (s.auto) {
    final parts = s.place.split('،');
    return countryFromName(parts.isEmpty ? '' : parts.last);
  }
  return countryFromName(s.country);
}

MethodSpec presetFor(String code) {
  return _byId(_methodByCountry[code] ?? 3);
}

MethodSpec resolveMethod(Settings s) {
  if (!s.autoMethod) {
    if (s.method == 99) {
      return MethodSpec(
        99,
        'مخصص — الفجر ${s.cFajr.toStringAsFixed(1)}° · العشاء ${s.cIsha.toStringAsFixed(1)}°',
        fajr: s.cFajr,
        isha: s.cIsha,
      );
    }
    return _byId(s.method);
  }
  return presetFor(detectCountry(s));
}
